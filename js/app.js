import { fetchAllCards } from './cards.js';
import { ARCHETYPES } from './rules.js';
import {
    COLORS, rankLegendTrios, pickDiverseTrios, scoreCard, isLegalFor, validateDeck, repairDeck, deckStats, deckToText,
} from './engine.js';
import {
    buildSystemPrompt, toApiMessages, extractDeck, stripThinking, chat, listModels, listProducts, loadServerConfig,
    GENERATE_REQUEST, MISSING_DECK_REQUEST, repairRequest,
} from './ai.js';

const TRIOS_FOR_AI = 5;
const MAX_AUTO_RETRIES = 2;
const SETTINGS_KEY = 'cptcg-deckmaker-settings';

const $ = (sel) => document.querySelector(sel);
const state = {
    cards: [],
    byKey: new Map(),
    allTags: [],
    colors: new Set(),
    archetype: 'midrange',
    locked: [],
    deck: null,
    // Historique de la conversation avec l'agent : { role, content, auto? }
    history: [],
    busy: false,
};

const settings = loadSettings();

async function init() {
    renderColors();
    renderArchetypes();
    bindSettings();
    bindForm();
    bindChat();
    try {
        state.cards = await fetchAllCards();
        state.byKey = new Map(state.cards.map((c) => [c.key, c]));
        state.allTags = [...new Set(state.cards.flatMap((c) => c.tags))].sort((a, b) => b.length - a.length);
        const legends = state.cards.filter((c) => c.type === 'Legend').length;
        setDbStatus(`${state.cards.length} cartes chargées · ${legends} Légendes`, 'ok');
        renderLegendPicker();
        renderTrioPreview();
    } catch (err) {
        setDbStatus(`Impossible de charger les cartes : ${err.message}`, 'error');
    }
    await applyServerConfig();
    if (settings.productId || server.productId) refreshModels();
}

// Config du .env (via proxy.php) : si elle est complète, rien à saisir dans la page.
const server = { hasToken: false, productId: '', model: '' };

async function applyServerConfig() {
    Object.assign(server, await loadServerConfig(settings));
    if (server.hasToken) $('#token-field').hidden = true;
    if (server.productId) $('#product-field').hidden = true;
    if (server.hasToken && server.productId) {
        $('#api-env-note').hidden = false;
    } else if (!settings.token || !settings.productId) {
        $('#api-settings').open = true;
    }
}

// ---------- Paramètres ----------

function renderColors() {
    const wrap = $('#colors');
    wrap.innerHTML = COLORS.map((c) => `
        <button type="button" class="chip color-chip" data-color="${c}" aria-pressed="false">
            <span class="dot dot-${c.toLowerCase()}"></span>${colorLabel(c)}
        </button>`).join('');
    wrap.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-color]');
        if (!btn) return;
        const color = btn.dataset.color;
        state.colors.has(color) ? state.colors.delete(color) : state.colors.add(color);
        btn.setAttribute('aria-pressed', state.colors.has(color));
        state.locked = state.locked.filter((k) => !state.colors.size || state.colors.has(state.byKey.get(k).color));
        renderLegendPicker();
        renderTrioPreview();
    });
}

function renderArchetypes() {
    const wrap = $('#archetypes');
    wrap.innerHTML = Object.entries(ARCHETYPES).map(([id, a]) => `
        <label class="arch">
            <input type="radio" name="archetype" value="${id}" ${id === state.archetype ? 'checked' : ''}>
            <span class="arch-name">${a.label}</span>
            <span class="arch-hint">${a.hint}</span>
        </label>`).join('');
    wrap.addEventListener('change', (e) => {
        state.archetype = e.target.value;
        renderTrioPreview();
    });
}

function renderLegendPicker() {
    const legends = state.cards
        .filter((c) => c.type === 'Legend' && c.legal && c.ram && c.text)
        .filter((c) => !state.colors.size || state.colors.has(c.color))
        .sort((a, b) => a.color.localeCompare(b.color) || a.fullName.localeCompare(b.fullName));
    $('#legend-picker').innerHTML = legends.map((l) => `
        <button type="button" class="chip legend-chip" data-key="${l.key}" aria-pressed="${state.locked.includes(l.key)}" title="${escapeHtml(l.text)}">
            <span class="dot dot-${l.color.toLowerCase()}"></span>${escapeHtml(l.fullName)}
        </button>`).join('');
    $('#legend-count').textContent = `${state.locked.length}/3`;
}

$('#legend-picker').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-key]');
    if (!btn) return;
    const key = btn.dataset.key;
    if (state.locked.includes(key)) {
        state.locked = state.locked.filter((k) => k !== key);
    } else {
        const card = state.byKey.get(key);
        const sameName = state.locked.find((k) => state.byKey.get(k).baseName === card.baseName);
        if (sameName) state.locked = state.locked.filter((k) => k !== sameName);
        if (state.locked.length >= 3) state.locked.shift();
        state.locked.push(key);
    }
    renderLegendPicker();
    renderTrioPreview();
});

function currentTrios() {
    return rankLegendTrios(state.cards, {
        colors: [...state.colors],
        locked: state.locked,
        archetype: ARCHETYPES[state.archetype],
        allTags: state.allTags,
    });
}

function renderTrioPreview() {
    if (!state.cards.length) return;
    const trios = currentTrios();
    const box = $('#trio-preview');
    if (!trios.length) {
        box.innerHTML = '<p class="muted">Aucun trio possible avec ces contraintes. Ajoute une couleur ou retire une Légende verrouillée.</p>';
        $('#generate').disabled = true;
        return;
    }
    $('#generate').disabled = false;
    box.innerHTML = `<ol class="trios">${pickDiverseTrios(trios, TRIOS_FOR_AI).map((t) => `
        <li>
            <span class="trio-legends">${t.legends.map((l) => `<span class="trio-legend"><span class="dot dot-${l.color.toLowerCase()}"></span>${escapeHtml(l.fullName)}</span>`).join('<span class="sep">+</span>')}</span>
            <span class="trio-meta">${t.legalCount} cartes jouables · ${t.sellable} vendables · score ${t.score}</span>
        </li>`).join('')}</ol>`;
}

function bindForm() {
    const size = $('#deck-size');
    size.addEventListener('input', () => { $('#deck-size-value').textContent = size.value; });
    const temp = $('#temperature');
    temp.addEventListener('input', () => { $('#temperature-value').textContent = Number(temp.value).toFixed(1); });
    $('#generate-form').addEventListener('submit', (e) => {
        e.preventDefault();
        sendToAgent(GENERATE_REQUEST, { expectDeck: true });
    });
    $('#copy').addEventListener('click', copyDeck);
    $('#download').addEventListener('click', downloadDeck);
}

// ---------- Réglages API ----------

function loadSettings() {
    try {
        return { proxy: 'proxy.php', ...JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}') };
    } catch {
        return { proxy: 'proxy.php' };
    }
}

function saveSettings() {
    try { localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)); } catch { /* stockage indisponible */ }
}

function bindSettings() {
    for (const [id, field] of [['#token', 'token'], ['#product-id', 'productId'], ['#proxy', 'proxy']]) {
        const input = $(id);
        input.value = settings[field] || '';
        input.addEventListener('change', () => {
            settings[field] = input.value.trim();
            saveSettings();
            refreshModels();
        });
    }
    $('#model').addEventListener('change', (e) => {
        settings.model = e.target.value;
        saveSettings();
    });
    $('#refresh-models').addEventListener('click', refreshModels);
    $('#detect-product').addEventListener('click', detectProduct);
}

async function detectProduct() {
    setApiStatus('Recherche de ton produit AI Tools…');
    try {
        const products = await listProducts(settings);
        if (!products.length) throw new Error('aucun produit AI Tools trouvé pour ce token');
        settings.productId = products[0].id;
        $('#product-id').value = settings.productId;
        saveSettings();
        setApiStatus(`Produit ${products[0].name || ''} (${settings.productId}) sélectionné.`, 'ok');
        refreshModels();
    } catch (err) {
        setApiStatus(`Détection impossible : ${err.message}`, 'error');
    }
}

async function refreshModels() {
    if (!settings.productId && !server.productId) return setApiStatus('Renseigne le Product ID (ou clique sur Détecter).');
    setApiStatus('Chargement des modèles…');
    try {
        const models = await listModels(settings);
        if (!models.length) throw new Error('liste vide');
        const select = $('#model');
        select.innerHTML = models.map((m) => `<option value="${escapeHtml(m)}">${escapeHtml(m)}</option>`).join('');
        if (!models.includes(settings.model)) settings.model = models.includes(server.model) ? server.model : models[0];
        select.value = settings.model;
        saveSettings();
        setApiStatus(`${models.length} modèles disponibles.`, 'ok');
    } catch (err) {
        setApiStatus(`Modèles indisponibles : ${err.message}`, 'error');
    }
}

// ---------- Conversation avec l'agent ----------

// Contexte rafraîchi à chaque message : paramètres actuels + toutes les cartes jouables + deck validé.
function buildContext() {
    const archetype = ARCHETYPES[state.archetype];
    const ranked = currentTrios();
    const trios = pickDiverseTrios(ranked, TRIOS_FOR_AI);
    const maxLimits = Object.fromEntries(COLORS.map((c) => [c, Math.max(0, ...ranked.map((t) => t.limits[c]))]));
    const legends = [...new Map(ranked.flatMap((t) => t.legends).map((l) => [l.key, l])).values()]
        .sort((a, b) => a.color.localeCompare(b.color) || a.fullName.localeCompare(b.fullName));
    const refs = mergeRefs(trios);
    const pool = state.cards
        .filter((c) => isLegalFor(c, maxLimits))
        .map((card) => ({ card, ...scoreCard(card, archetype, refs) }))
        .sort((a, b) => b.score - a.score);
    const system = buildSystemPrompt({
        archetype,
        trios,
        legends,
        pool,
        options: {
            deckSize: Number($('#deck-size').value),
            notes: $('#notes').value.trim(),
            colors: [...state.colors],
            locked: state.locked.map((k) => state.byKey.get(k)),
        },
        currentDeck: state.deck ? describeCurrentDeck() : null,
    });
    return { archetype, trios, pool, system };
}

function describeCurrentDeck() {
    const deck = state.deck;
    return {
        name: deck.name,
        legends: deck.legends.map((k) => state.byKey.get(k)),
        main: deck.main.map((e) => ({ qty: e.qty, card: state.byKey.get(e.key) })),
        stats: deckStats(deck, state.byKey),
    };
}

function mergeRefs(trios) {
    const merged = { tags: new Set(), types: new Set(), colorTypes: new Set(), mechanics: new Set() };
    for (const t of trios) for (const k of Object.keys(merged)) t.refs[k].forEach((v) => merged[k].add(v));
    return merged;
}

async function sendToAgent(text, { expectDeck = false } = {}) {
    if (state.busy || !text.trim()) return;
    if (!settings.model) {
        $('#api-settings').open = true;
        return setApiStatus('Choisis un modèle avant de discuter.', 'error');
    }
    state.history.push({ role: 'user', content: text.trim() });
    renderChat();
    setBusy(true, 'L\'agent réfléchit…');
    try {
        let reply = await ask();
        let found = extractDeck(reply);
        if (!found.deck && expectDeck) {
            reply = await ask(MISSING_DECK_REQUEST);
            found = extractDeck(reply);
        }
        if (found.deck) await acceptDeck(found.deck);
    } catch (err) {
        state.history.push({ role: 'error', content: err.message });
        renderChat();
    } finally {
        setBusy(false);
    }
}

// Envoie l'historique (avec un éventuel message automatique) et ajoute la réponse.
async function ask(autoMessage) {
    if (autoMessage) {
        state.history.push({ role: 'user', content: autoMessage, auto: true });
        renderChat();
    }
    const { system } = buildContext();
    const messages = toApiMessages(system, state.history.filter((m) => m.role !== 'error'));
    const temperature = Number($('#temperature').value);
    const content = stripThinking(await chat(settings, messages, { temperature }));
    state.history.push({ role: 'assistant', content });
    state.lastSystem = system;
    renderChat();
    return content;
}

// Valide le deck proposé ; si besoin, l'agent corrige lui-même, puis le site répare ce qui reste.
async function acceptDeck(deck) {
    let { errors } = validateDeck(deck, state.byKey);
    for (let i = 0; errors.length && i < MAX_AUTO_RETRIES; i++) {
        setBusy(true, `Correction de ${errors.length} problème(s) de légalité…`);
        const total = deck.main.reduce((sum, e) => sum + e.qty, 0);
        const found = extractDeck(await ask(repairRequest(errors, { total, target: Number($('#deck-size').value) })));
        if (!found.deck) break;
        deck = found.deck;
        ({ errors } = validateDeck(deck, state.byKey));
    }
    let fixes = [];
    const roles = new Map(deck.main.map((e) => [e.key, e.role]));
    if (errors.length) {
        const { trios, pool } = buildContext();
        ({ deck, fixes } = repairDeck(deck, state.byKey, pool, trios[0]));
    }
    deck.main = deck.main.map((e) => ({ ...e, role: roles.get(e.key) || '' }));
    state.deck = { ...deck, archetype: ARCHETYPES[state.archetype].label, model: settings.model, fixes };
    renderDeck();
    $('#generate').textContent = 'Régénérer le deck';
}

function renderChat() {
    const log = $('#chat-log');
    $('#chat-welcome').hidden = state.history.length > 0;
    log.innerHTML = state.history.map((m) => {
        if (m.role === 'error') return `<div class="msg msg-error">Erreur : ${escapeHtml(m.content)}</div>`;
        if (m.auto) return `<details class="msg msg-auto"><summary><span class="msg-tag">Auto</span>Le site demande une correction à l'agent</summary>${richText(m.content)}</details>`;
        if (m.role === 'user') return `<div class="msg msg-user">${richText(m.content)}</div>`;
        const { text, deck } = safeExtract(m.content);
        const deckChip = deck ? `<button type="button" class="deck-chip" data-show-deck>Deck proposé : <b>${escapeHtml(deck.name)}</b> · ${deck.main.reduce((s, e) => s + e.qty, 0)} cartes</button>` : '';
        return `<div class="msg msg-agent">${text ? richText(text) : ''}${deckChip}</div>`;
    }).join('');
    scrollChat();
}

function scrollChat() {
    const box = $('.chat-scroll');
    box.scrollTop = box.scrollHeight;
}

function safeExtract(content) {
    try {
        return extractDeck(content);
    } catch {
        return { text: content, deck: null };
    }
}

function bindChat() {
    const input = $('#chat-input');
    $('#chat-form').addEventListener('submit', (e) => {
        e.preventDefault();
        const text = input.value;
        input.value = '';
        sendToAgent(text);
    });
    input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) {
            e.preventDefault();
            $('#chat-form').requestSubmit();
        }
    });
    $('#chat-log').addEventListener('click', (e) => {
        if (e.target.closest('[data-show-deck]')) $('#result').scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    $('#chat-reset').addEventListener('click', () => {
        if (state.busy) return;
        state.history = [];
        renderChat();
    });
    $('#chat-suggestions').addEventListener('click', (e) => {
        const btn = e.target.closest('[data-suggest]');
        if (btn) sendToAgent(btn.textContent);
    });
}

// ---------- Affichage ----------

function renderDeck() {
    const deck = state.deck;
    const stats = deckStats(deck, state.byKey);
    const legends = deck.legends.map((k) => state.byKey.get(k));
    $('#empty').hidden = true;
    $('#result').hidden = false;

    $('#deck-name').textContent = deck.name;
    $('#deck-sub').textContent = `${deck.archetype} · ${stats.total} cartes · ${deck.model}`;

    $('#legends').innerHTML = legends.map((l) => `
        <figure class="legend-card">
            <img src="${l.image}" alt="${escapeHtml(l.fullName)}" loading="lazy">
            <figcaption><span class="dot dot-${l.color.toLowerCase()}"></span>${escapeHtml(l.fullName)}</figcaption>
        </figure>`).join('');

    const maxCurve = Math.max(...stats.curve, 1);
    $('#stats').innerHTML = `
        <div class="stat"><b>${stats.total}</b><span>cartes</span></div>
        <div class="stat"><b>${stats.sellable}</b><span>vendables</span></div>
        <div class="stat"><b>${stats.avgCost.toFixed(1)}</b><span>coût moyen</span></div>
        <div class="stat"><b>${stats.types.Unit}/${stats.types.Gear}/${stats.types.Program}</b><span>Unit / Gear / Prog.</span></div>
        <div class="curve" aria-label="Courbe de coût">
            ${stats.curve.map((n, i) => `
                <div class="bar"><span class="bar-n">${n || ''}</span><span class="bar-fill" style="height:${(n / maxCurve) * 100}%"></span><span class="bar-x">${i === 6 ? '7+' : i + 1}</span></div>`).join('')}
        </div>`;

    const groups = ['Unit', 'Gear', 'Program'];
    $('#decklist').innerHTML = groups.map((type) => {
        const rows = deck.main
            .map((e) => ({ ...e, card: state.byKey.get(e.key) }))
            .filter((e) => e.card.type === type)
            .sort((a, b) => (a.card.cost ?? 0) - (b.card.cost ?? 0) || a.card.fullName.localeCompare(b.card.fullName));
        if (!rows.length) return '';
        const count = rows.reduce((s, e) => s + e.qty, 0);
        return `<section class="group">
            <h3>${typeLabel(type)} <span>${count}</span></h3>
            <ul>${rows.map(({ qty, role, card }) => `
                <li class="row" data-img="${card.image}">
                    <span class="qty">${qty}×</span>
                    <span class="cost">${card.cost ?? '–'}</span>
                    <span class="dot dot-${card.color.toLowerCase()}"></span>
                    <span class="name">${escapeHtml(card.fullName)}${card.sellable ? '<i class="sell" title="Vendable (Sell Tag)">€$</i>' : ''}</span>
                    <span class="role">${cardText(role)}</span>
                </li>`).join('')}</ul>
        </section>`;
    }).join('');

    const g = deck.gameplan || {};
    $('#analysis').innerHTML = `
        ${deck.strategy ? `<h3>Stratégie</h3><p>${cardText(deck.strategy)}</p>` : ''}
        ${deck.synergies.length ? `<h3>Synergies clés</h3><ul>${deck.synergies.map((s) => `<li>${cardText(String(s))}</li>`).join('')}</ul>` : ''}
        ${g.early || g.mid || g.late ? `<h3>Plan de jeu</h3><dl>
            ${g.early ? `<dt>Début</dt><dd>${cardText(g.early)}</dd>` : ''}
            ${g.mid ? `<dt>Milieu</dt><dd>${cardText(g.mid)}</dd>` : ''}
            ${g.late ? `<dt>Fin</dt><dd>${cardText(g.late)}</dd>` : ''}</dl>` : ''}
        ${deck.mulligan ? `<h3>Mulligan</h3><p>${cardText(deck.mulligan)}</p>` : ''}
        ${deck.weaknesses ? `<h3>Faiblesses</h3><p>${cardText(deck.weaknesses)}</p>` : ''}`;

    $('#fixes').hidden = !deck.fixes.length;
    $('#fixes').innerHTML = deck.fixes.length
        ? `<b>Corrections automatiques</b> (le modèle n'a pas respecté toutes les règles) :<ul>${deck.fixes.map((f) => `<li>${escapeHtml(f)}</li>`).join('')}</ul>`
        : '';
    $('#prompt').textContent = state.lastSystem || '';
}

// Aperçu de la carte au survol d'une ligne
const preview = $('#card-preview');
$('#decklist').addEventListener('mouseover', (e) => {
    const row = e.target.closest('[data-img]');
    if (!row) return;
    preview.src = row.dataset.img;
    preview.hidden = false;
});
$('#decklist').addEventListener('mousemove', (e) => {
    const x = Math.min(e.clientX + 24, innerWidth - 260);
    const y = Math.min(e.clientY - 40, innerHeight - 360);
    preview.style.transform = `translate(${x}px, ${Math.max(8, y)}px)`;
});
$('#decklist').addEventListener('mouseleave', () => { preview.hidden = true; });

async function copyDeck() {
    const text = deckToText(state.deck, state.byKey);
    try {
        await navigator.clipboard.writeText(text);
    } catch {
        const area = Object.assign(document.createElement('textarea'), { value: text });
        document.body.append(area);
        area.select();
        document.execCommand('copy');
        area.remove();
    }
    const btn = $('#copy');
    btn.textContent = 'Copié ✓';
    setTimeout(() => { btn.textContent = 'Copier en .txt'; }, 1600);
}

function downloadDeck() {
    const text = deckToText(state.deck, state.byKey);
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([text], { type: 'text/plain' }));
    a.download = `${state.deck.name.replace(/[^\w-]+/g, '_')}.txt`;
    a.click();
    URL.revokeObjectURL(a.href);
}

let busyTimer = null;
let busyStart = 0;

// Les modèles qui raisonnent (Kimi, Qwen) peuvent mettre plusieurs minutes : on affiche le temps écoulé.
function setBusy(busy, message = '') {
    state.busy = busy;
    $('#generate').disabled = busy;
    $('#chat-send').disabled = busy;
    $('#busy').hidden = !busy;
    clearInterval(busyTimer);
    if (!busy) {
        busyStart = 0;
        return;
    }
    if (!busyStart) busyStart = Date.now();
    const tick = () => {
        $('#busy-text').textContent = `${message} ${Math.round((Date.now() - busyStart) / 1000)} s`;
    };
    tick();
    scrollChat();
    busyTimer = setInterval(tick, 1000);
}

function setDbStatus(text, kind = '') {
    const el = $('#db-status');
    el.textContent = text;
    el.dataset.kind = kind;
}

function setApiStatus(text, kind = '') {
    const el = $('#api-status');
    el.textContent = text;
    el.dataset.kind = kind;
}

const colorLabel = (c) => ({ Red: 'Rouge', Green: 'Vert', Blue: 'Bleu', Yellow: 'Jaune' })[c];
const typeLabel = (t) => ({ Unit: 'Units', Gear: 'Gears', Program: 'Programs' })[t];

// Si le modèle cite quand même une clé (c12), on affiche le nom de la carte.
function cardText(s) {
    return escapeHtml(String(s ?? '')
        .replace(/\s*\(c\d+\)/g, '')
        .replace(/\bc(\d+)\b/g, (m) => state.byKey.get(m)?.fullName ?? m));
}

// Mini markdown pour les réponses de l'agent : paragraphes, listes, **gras**, `code`.
function richText(text) {
    const inline = (line) => cardText(line)
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
        .replace(/`([^`]+)`/g, '<code>$1</code>');
    return text.trim().split(/\n{2,}/).map((block) => {
        const lines = block.split('\n');
        if (lines.every((l) => /^\s*([-*•]|\d+[.)])\s+/.test(l))) {
            const ordered = /^\s*\d/.test(lines[0]);
            const items = lines.map((l) => `<li>${inline(l.replace(/^\s*([-*•]|\d+[.)])\s+/, ''))}</li>`).join('');
            return ordered ? `<ol>${items}</ol>` : `<ul>${items}</ul>`;
        }
        if (/^#{1,4}\s/.test(lines[0]) && lines.length === 1) return `<p><strong>${inline(lines[0].replace(/^#+\s*/, ''))}</strong></p>`;
        return `<p>${lines.map((l) => inline(l.replace(/^#+\s*/, ''))).join('<br>')}</p>`;
    }).join('');
}

function escapeHtml(s) {
    return String(s ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
}

init();
