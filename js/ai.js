import { RULES_DIGEST } from './rules.js';
import { META_DIGEST } from './meta.js';
import { MIN_MAIN, MAX_MAIN, MAX_COPIES } from './engine.js';

const DECK_SCHEMA = `{
  "name": "evocative deck name in English, 2-5 words",
  "legends": ["cXX", "cXX", "cXX"],
  "main": [{"key": "cXX", "qty": 3, "role": "short role in French"}],
  "strategy": "2-4 sentences in French: how the deck wins",
  "synergies": ["French bullet explaining one key synergy between named cards", "..."],
  "gameplan": {"early": "French", "mid": "French", "late": "French"},
  "mulligan": "French: what to keep in the opening 6",
  "weaknesses": "French: what the deck fears and how to play around it"
}`;

// Un seul agent pour toute la session : ce prompt système est reconstruit à chaque message
// avec les paramètres actuels et le deck tel que validé par le site. Aucune présélection : l'agent voit tout.
export function buildSystemPrompt({ archetype, legends, pool, options, currentDeck }) {
    const legendLines = legends.map((l) =>
        `${l.key} | ${l.fullName} | ${l.color} | RAM ${l.ram} | cost ${l.cost ?? '-'} | power ${l.power ?? '-'} | tags: ${l.tags.join(', ')} | ${oneLine(l.text)}`);

    const poolLines = pool.map((card) =>
        `${card.key} | ${card.fullName} | ${card.type} | ${card.color} RAM ${card.ram} | cost ${card.cost ?? '-'} | power ${card.power ?? '-'} | sell:${card.sellable ? 'yes' : 'no'} | tags: ${card.tags.join(', ') || '—'} | ${oneLine(card.text) || '(no text)'}`);

    return `You are a world-class Cyberpunk TCG deck builder and coach, talking with a player in French. Your goal: design the strongest deck imaginable. You discuss ideas, argue honestly (disagree when their idea is weak and explain why), build the deck when asked, and modify it on request.

${RULES_DIGEST}

${META_DIGEST}

HOW TO BUILD (think before answering; nothing is pre-computed for you)
1. Read EVERY Legend's text. Look for pairs/triples of Legends whose effects feed each other, and for a concrete WIN PLAN that works within about 7 turns.
2. Choose the trio of Legends for that synergy, NOT for how many playable cards its colors give. A trio with fewer legal cards but a tight engine beats a trio with a wide pool and no plan. Also weigh the RAM limits: they decide which cards you can even use.
3. Then pick the main deck card by card around that plan: enablers, payoffs, the early game (turns 1-3), economy (sellable cards), answers to the rival, and how the deck survives its own weak draws. Read the real text of each card; combos can come from any card in the pool.
4. Compare your plan with the meta snapshot: borrow what is proven, and make sure you have an answer to the dominant plans.
5. Before answering, check the RAM legality of each card, the copy counts and the total.

HOW TO TALK
- Answer in French, concise and concrete (a few short paragraphs or bullets). Always name cards by their card NAME, never by their key (cXX).
- When discussing, do NOT output a deck block.
- Output a deck block ONLY when the player asks you to build, generate, change or fix the deck (or clearly accepts a deck proposal). The block always contains the COMPLETE deck, never a partial diff.
- When you output a deck block, first write 1-3 sentences in French summarizing what you built or changed, then the block.

DECK BLOCK FORMAT (exactly this fence, valid JSON inside):
\`\`\`deck
${DECK_SCHEMA}
\`\`\`
Deck rules for the block:
- Use ONLY card keys from the lists below. 3 Legends with different names.
- List each card ONCE in "main" (one entry per card, qty 1 to ${MAX_COPIES}).
- Main deck: between ${MIN_MAIN} and ${MAX_MAIN} cards (sum of qty), target ${options.deckSize} unless the player asks otherwise. Max ${MAX_COPIES} copies per card.
- Every main-deck card must be legal for the RAM limits of YOUR 3 Legends (card RAM <= sum of your Legends' RAM in that card's color). Double-check before answering.
- The site validates every deck block; if it reports errors, fix them and send the full corrected block.

PLAYER SETTINGS (from the page; they can change between messages)
- Deck type: ${archetype.label}. ${archetype.brief}
- Colors allowed for Legends: ${options.colors.length ? options.colors.join(', ') : 'any'}${options.locked.length ? `\n- Legends imposed by the player: ${options.locked.map((l) => l.fullName).join(', ')}` : ''}
- Target main deck size: ${options.deckSize}
${options.notes ? `- Player's wishes: ${options.notes}\n` : ''}If the player wants Legends or colors that are not in the lists below, tell them to change the color / Legend selection in the left panel.

LEGENDS AVAILABLE (any trio of different names is allowed):
${legendLines.join('\n')}

CARD POOL: every non-Legend card that could be legal for some allowed trio (key | name | type | color RAM | cost | power | sell tag | tags | rules text). Check the RAM limits of your chosen trio.
${poolLines.join('\n')}

${currentDeck ? describeDeck(currentDeck) : 'CURRENT DECK: none yet.'}`;
}

function describeDeck({ name, legends, main, stats }) {
    return `CURRENT DECK (authoritative version, as validated by the site; modify THIS deck when asked):
Name: ${name}
Legends: ${legends.map((l) => `${l.key} ${l.fullName}`).join(', ')}
Main deck (${stats.total} cards, ${stats.sellable} sellable, avg cost ${stats.avgCost.toFixed(1)}, Units/Gears/Programs ${stats.types.Unit}/${stats.types.Gear}/${stats.types.Program}):
${main.map(({ card, qty }) => `${qty}x ${card.key} ${card.fullName} (${card.type}, ${card.color} RAM ${card.ram}, cost ${card.cost ?? '-'})`).join('\n')}`;
}

export const GENERATE_REQUEST = 'Génère le deck maintenant, en tenant compte de notre discussion et des paramètres actuels.';

export function repairRequest(errors, { total, target }) {
    return `Le site a détecté des problèmes de légalité dans ce deck :\n- ${errors.join('\n- ')}\nTotal actuel du main deck : ${total} cartes (objectif : ${target}). Corrige en gardant le deck aussi fort que possible : une seule ligne par carte, ${MAX_COPIES} copies maximum, puis recompte la somme des qty avant de renvoyer le bloc deck complet.`;
}

export const MISSING_DECK_REQUEST = 'Je n\'ai pas trouvé de bloc deck dans ta réponse. Renvoie le deck complet dans un bloc ```deck.';

// Les anciens blocs deck sont remplacés par un rappel : la section CURRENT DECK du prompt système fait foi.
export function toApiMessages(system, history) {
    const lastAssistant = history.map((m) => m.role).lastIndexOf('assistant');
    return [
        { role: 'system', content: system },
        ...history.map((m, i) => ({
            role: m.role,
            content: m.role === 'assistant' && i !== lastAssistant
                ? m.content.replace(DECK_BLOCK, '[deck block omitted — see CURRENT DECK]')
                : m.content,
        })),
    ];
}

const oneLine = (text) => text.replace(/\s*\n\s*/g, ' / ');

export async function chat(settings, messages, { temperature, onProgress }) {
    const res = await fetch(proxyUrl(settings, 'chat'), {
        method: 'POST',
        headers: headers(settings),
        // Large marge : les modèles qui raisonnent consomment des tokens avant d'écrire la réponse.
        body: JSON.stringify({ model: settings.model, messages, temperature, max_tokens: 32000, stream: true }),
    });
    if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(errorText(data) || `Infomaniak a répondu HTTP ${res.status}`);
    }

    // Flux SSE : on cumule le texte, on compte les tokens de réflexion pour montrer que ça avance.
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let content = '';
    let reasoningChars = 0;
    let finish = '';
    const handle = (line) => {
        if (!line.startsWith('data:')) return;
        const payload = line.slice(5).trim();
        if (!payload || payload === '[DONE]') return;
        let event;
        try { event = JSON.parse(payload); } catch { return; }
        if (event.error) throw new Error(errorText(event) || 'Erreur pendant la génération.');
        const choice = event.choices?.[0];
        const delta = choice?.delta || {};
        if (delta.content) content += delta.content;
        reasoningChars += (delta.reasoning || delta.reasoning_content || '').length;
        if (choice?.finish_reason) finish = choice.finish_reason;
        onProgress?.({ reasoningChars, contentChars: content.length });
    };
    for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop();
        lines.forEach(handle);
    }
    handle(buffer);

    if (!content && finish === 'length') throw new Error('Le modèle a épuisé ses tokens en réfléchissant, sans écrire de réponse. Réessaie ou change de modèle.');
    if (!content) throw new Error('Réponse vide du modèle.');
    return content;
}

export async function listModels(settings) {
    const res = await fetch(proxyUrl(settings, 'models'), { headers: headers(settings) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(errorText(data) || `HTTP ${res.status}`);
    const list = data.data || data.models || [];
    // L'API liste aussi les modèles d'embedding / audio / image, inutilisables pour le chat.
    return list
        .map((m) => m.id || m.name)
        .filter((id) => id && !/embed|bge_|mini_lm|whisper|flux|rerank/i.test(id))
        .sort((a, b) => a.localeCompare(b));
}

export async function listProducts(settings) {
    const res = await fetch(proxyUrl(settings, 'products'), { headers: headers(settings) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(errorText(data) || `HTTP ${res.status}`);
    return (data.data || []).map((p) => ({ id: String(p.product_id ?? p.id), name: p.name || p.customer_name || '' }));
}

export async function loadServerConfig(settings) {
    try {
        const res = await fetch(proxyUrl(settings, 'config'));
        return res.ok ? await res.json() : {};
    } catch {
        return {};
    }
}

function proxyUrl(settings, action) {
    const url = new URL(settings.proxy || 'proxy.php', location.href);
    url.searchParams.set('action', action);
    if (settings.productId) url.searchParams.set('product_id', settings.productId);
    return url;
}

function headers(settings) {
    const h = { 'Content-Type': 'application/json' };
    if (settings.token) h['X-Infomaniak-Token'] = settings.token;
    return h;
}

const errorText = (data) => data?.error?.description || data?.error?.message || (typeof data?.error === 'string' ? data.error : '');

const DECK_BLOCK = /```deck\s*([\s\S]*?)```/i;

export function stripThinking(content) {
    return content.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
}

// Sépare le texte de l'agent et l'éventuel bloc deck. Accepte aussi un bloc ```json contenant un deck.
export function extractDeck(content) {
    const cleaned = stripThinking(content);
    let match = cleaned.match(DECK_BLOCK);
    if (!match) {
        const json = cleaned.match(/```(?:json)?\s*(\{[\s\S]*?"legends"[\s\S]*?)```/i);
        if (json) match = json;
    }
    if (!match) return { text: cleaned, deck: null };
    const text = cleaned.replace(match[0], '').trim();
    const raw = match[1];
    const data = JSON.parse(raw.slice(raw.indexOf('{'), raw.lastIndexOf('}') + 1));
    return {
        text,
        deck: {
            name: String(data.name || 'Unnamed Deck').trim(),
            legends: (data.legends || []).map(String),
            main: (data.main || []).map((e) => ({ key: String(e.key), qty: Number(e.qty) || 1, role: e.role || '' })),
            strategy: data.strategy || '',
            synergies: Array.isArray(data.synergies) ? data.synergies : [],
            gameplan: data.gameplan || {},
            mulligan: data.mulligan || '',
            weaknesses: data.weaknesses || '',
        },
    };
}
