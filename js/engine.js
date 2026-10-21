// Moteur local : légalité, score heuristique des cartes et des trios de Légendes,
// validation et réparation du deck renvoyé par l'IA.

export const COLORS = ['Red', 'Green', 'Blue', 'Yellow'];
export const MIN_MAIN = 40;
export const MAX_MAIN = 50;
export const MAX_COPIES = 3;

const FEATURES = {
    draw: /\bdraw (\d|up to)|add [^.]{0,60}to your hand/,
    removal: /defeat (a|an|up to \d+|\d+|that|target)? ?rival|rival unit[^.]{0,30}-\d+ power|give a rival unit -|spend a rival unit|bottom-deck a rival|discards? \d/,
    blocker: /\{blocker\}/,
    haste: /\{adrenaline\}|\{go solo\}|can attack the turn/,
    steal: /steal/,
    pump: /\+\d+ power/,
    gig: /(increase|decrease|adjust|set|swap)[^.]{0,30}gig|value-pair|min gig|max gig|street cred|☆|8\+ value/,
    quick: /\{quick\}/,
};

const MECHANICS = {
    blocker: /\{blocker\}/,
    bigGigs: /8\+ value|max gig/,
    pairs: /value-pair/,
    minGigs: /min gig/,
    streetCred: /street cred|☆/,
    trash: /from your trash|trash \d/,
};

export function featuresOf(card) {
    const text = card.text.toLowerCase();
    const result = {};
    for (const [name, re] of Object.entries(FEATURES)) result[name] = re.test(text) ? 1 : 0;
    return result;
}

function efficiency(card) {
    if (card.power == null || card.cost == null) return 0;
    if (card.type === 'Gear') return clamp((card.power - card.cost) / 2, -1, 1.5);
    if (card.type !== 'Unit') return 0;
    const expected = 1.3 * card.cost + 0.5;
    const bonus = card.power >= 10 ? 0.5 : 0;
    return clamp((card.power - expected) / 2 + bonus, -2, 2);
}

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

// Ce que les Légendes "demandent" : tags, types et mécaniques cités dans leur texte.
export function legendReferences(legends, allTags) {
    const refs = { tags: new Set(), types: new Set(), colorTypes: new Set(), mechanics: new Set() };
    for (const legend of legends) {
        const text = legend.text;
        const lower = text.toLowerCase();
        for (const tag of allTags) {
            const re = new RegExp(`(^|[^A-Z])${escapeRegex(tag.toUpperCase())}([^A-Z]|$)`);
            if (re.test(text)) refs.tags.add(tag);
        }
        // "BRAINDANCE Program" vise un tag, pas tous les Programs : on ignore les types précédés d'un tag.
        if (/(^|[^A-Z] )(gears?|equipped)\b/i.test(text.replace(/[A-Z]{2,} (Gears?|Programs?)/g, ''))) refs.types.add('Gear');
        if (/\bprograms?\b/i.test(text.replace(/[A-Z]{2,} Programs?/g, ''))) refs.types.add('Program');
        for (const m of lower.matchAll(/\b(red|green|blue|yellow) (unit|gear|program)/g)) {
            refs.colorTypes.add(`${cap(m[1])} ${cap(m[2])}`);
        }
        for (const [name, re] of Object.entries(MECHANICS)) if (re.test(lower)) refs.mechanics.add(name);
    }
    return refs;
}

const cap = (s) => s[0].toUpperCase() + s.slice(1);
const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export function synergyWith(card, refs) {
    let score = 0;
    const reasons = [];
    for (const tag of card.tags) {
        if (refs.tags.has(tag)) { score += 2.5; reasons.push(tag.toUpperCase()); }
    }
    if (refs.types.has(card.type)) { score += 1.5; reasons.push(card.type); }
    if (refs.colorTypes.has(`${card.color} ${card.type}`)) { score += 1.5; reasons.push(`${card.color} ${card.type}`); }
    const lower = card.text.toLowerCase();
    for (const name of refs.mechanics) {
        if (MECHANICS[name].test(lower)) { score += 1; reasons.push(name); }
    }
    return { score, reasons };
}

export function scoreCard(card, archetype, refs) {
    const w = archetype.weights;
    const f = featuresOf(card);
    let score = 2 + efficiency(card) * w.efficiency;
    for (const key of ['draw', 'removal', 'blocker', 'haste', 'steal', 'pump', 'gig']) score += f[key] * (w[key] ?? 0);
    score += f.quick * 0.5;
    if (card.cost != null && card.cost <= 3) score += 0.5 * w.cheap;
    if (card.cost != null && card.cost >= 6) score += 0.5 * w.expensive * (card.cost >= 8 ? 2 : 1);
    if (card.type === 'Unit') score += w.unit ?? 0;
    if (card.sellable) score += 1;
    const syn = synergyWith(card, refs);
    score += syn.score * (w.legendSynergy ?? 1.2);
    return { score: Math.round(score * 10) / 10, synergy: syn.reasons };
}

// Garde des trios variés : chacun partage au plus 1 Légende avec ceux déjà retenus.
export function pickDiverseTrios(ranked, count) {
    const picked = [];
    for (const trio of ranked) {
        if (picked.length >= count) break;
        const overlaps = picked.some((p) => p.legends.filter((l) => trio.legends.includes(l)).length > 1);
        if (!overlaps) picked.push(trio);
    }
    for (const trio of ranked) {
        if (picked.length >= count) break;
        if (!picked.includes(trio)) picked.push(trio);
    }
    return picked;
}

export function ramLimits(legends) {
    const limits = Object.fromEntries(COLORS.map((c) => [c, 0]));
    for (const legend of legends) if (legend.color in limits) limits[legend.color] += legend.ram || 0;
    return limits;
}

export function isLegalFor(card, limits) {
    if (card.type === 'Legend' || !card.legal) return false;
    if (card.ram == null || !card.color) return false;
    return card.ram <= (limits[card.color] ?? 0);
}

// Énumère tous les trios valides selon les couleurs/légendes demandées et les classe.
export function rankLegendTrios(cards, { colors, locked, archetype, allTags }) {
    const legends = cards.filter((c) => c.type === 'Legend' && c.legal && c.ram && c.text);
    const allowed = legends.filter((l) => !colors.length || colors.includes(l.color));
    const lockedCards = locked.map((k) => legends.find((l) => l.key === k)).filter(Boolean);
    const mustCover = colors.length && colors.length <= 3 ? colors : [];
    const mainCards = cards.filter((c) => c.type !== 'Legend' && c.legal);

    const trios = [];
    for (let i = 0; i < allowed.length; i++) {
        for (let j = i + 1; j < allowed.length; j++) {
            for (let k = j + 1; k < allowed.length; k++) {
                const trio = [allowed[i], allowed[j], allowed[k]];
                if (new Set(trio.map((l) => l.baseName)).size < 3) continue;
                if (!lockedCards.every((l) => trio.includes(l))) continue;
                if (!mustCover.every((c) => trio.some((l) => l.color === c))) continue;
                trios.push(evaluateTrio(trio, mainCards, archetype, allTags));
            }
        }
    }
    return trios.sort((a, b) => b.score - a.score);
}

function evaluateTrio(legends, mainCards, archetype, allTags) {
    const limits = ramLimits(legends);
    const refs = legendReferences(legends, allTags);
    const legal = mainCards.filter((c) => isLegalFor(c, limits));
    const scored = legal.map((c) => scoreCard(c, archetype, refs).score).sort((a, b) => b - a);
    const top = scored.slice(0, 16).reduce((s, v) => s + v, 0);
    const sellable = legal.filter((c) => c.sellable).length;
    const units = legal.filter((c) => c.type === 'Unit').length;
    let score = top;
    for (const legend of legends) score += scoreCard(legend, archetype, refs).score * 0.8;
    if (sellable < 7) score -= (7 - sellable) * 4;
    if (units < 8) score -= (8 - units) * 4;
    return { legends, limits, refs, legalCount: legal.length, sellable, units, score: Math.round(score) };
}

export function validateDeck(deck, cardsByKey) {
    const errors = [];
    const legends = deck.legends.map((k) => cardsByKey.get(k));
    if (legends.length !== 3 || legends.some((l) => !l || l.type !== 'Legend')) {
        errors.push('Il faut exactement 3 Légendes valides.');
        return { errors, limits: null };
    }
    if (new Set(legends.map((l) => l.baseName)).size < 3) errors.push('Deux Légendes ont le même nom.');
    const limits = ramLimits(legends);

    const copies = new Map();
    let total = 0;
    for (const { key, qty } of deck.main) {
        const card = cardsByKey.get(key);
        if (!card) { errors.push(`Carte inconnue : ${key}`); continue; }
        if (!isLegalFor(card, limits)) errors.push(`${card.fullName} (${card.color} RAM ${card.ram}) hors des limites de RAM.`);
        copies.set(card.fullName, (copies.get(card.fullName) || 0) + qty);
        total += qty;
    }
    for (const [name, n] of copies) if (n > MAX_COPIES) errors.push(`${name} : ${n} copies (max ${MAX_COPIES}).`);
    if (total < MIN_MAIN || total > MAX_MAIN) errors.push(`Le main deck fait ${total} cartes (attendu ${MIN_MAIN}–${MAX_MAIN}).`);
    return { errors, limits };
}

// Dernier filet de sécurité : rend le deck légal en gardant au maximum les choix de l'IA.
export function repairDeck(deck, cardsByKey, rankedPool, fallbackTrio) {
    const fixes = [];
    let legends = deck.legends.map((k) => cardsByKey.get(k));
    if (legends.length !== 3 || legends.some((l) => !l || l.type !== 'Legend') || new Set(legends.map((l) => l.baseName)).size < 3) {
        legends = fallbackTrio.legends;
        fixes.push('Trio de Légendes remplacé par le meilleur trio calculé.');
    }
    const limits = ramLimits(legends);
    const counts = new Map();
    for (const { key, qty } of deck.main) {
        const card = cardsByKey.get(key);
        if (!card || !isLegalFor(card, limits)) {
            if (card) fixes.push(`Retiré : ${card.fullName} (illégal).`);
            continue;
        }
        const current = counts.get(card.fullName) || { card, qty: 0 };
        const next = Math.min(MAX_COPIES, current.qty + Math.max(1, Math.round(qty) || 1));
        if (next < current.qty + qty) fixes.push(`${card.fullName} limité à ${MAX_COPIES} copies.`);
        counts.set(card.fullName, { card, qty: next });
    }
    let total = [...counts.values()].reduce((s, e) => s + e.qty, 0);
    const legalPool = rankedPool.filter((e) => isLegalFor(e.card, limits));
    const units = () => [...counts.values()].filter((e) => e.card.type === 'Unit').reduce((s, e) => s + e.qty, 0);
    const fillOrder = [...legalPool].sort((a, b) => {
        const wantUnits = units() < MIN_MAIN / 2;
        return ((b.card.type === 'Unit') === wantUnits) - ((a.card.type === 'Unit') === wantUnits) || b.score - a.score;
    });
    for (const { card } of fillOrder) {
        if (total >= MIN_MAIN) break;
        const current = counts.get(card.fullName) || { card, qty: 0 };
        const add = Math.min(MAX_COPIES - current.qty, MIN_MAIN - total);
        if (add <= 0) continue;
        counts.set(card.fullName, { card, qty: current.qty + add });
        total += add;
        fixes.push(`Ajouté : ${add}x ${card.fullName} (deck incomplet).`);
    }
    if (total > MAX_MAIN) {
        const scoreOf = new Map(rankedPool.map((e) => [e.card.key, e.score]));
        const sorted = [...counts.values()].sort((a, b) => (scoreOf.get(a.card.key) ?? 0) - (scoreOf.get(b.card.key) ?? 0));
        for (const entry of sorted) {
            while (total > MAX_MAIN && entry.qty > 0) { entry.qty--; total--; }
        }
        fixes.push(`Deck réduit à ${MAX_MAIN} cartes.`);
    }
    const main = [...counts.values()].filter((e) => e.qty > 0).map((e) => ({ key: e.card.key, qty: e.qty }));
    return { deck: { ...deck, legends: legends.map((l) => l.key), main }, fixes };
}

export function deckStats(deck, cardsByKey) {
    const entries = deck.main.map((e) => ({ ...e, card: cardsByKey.get(e.key) })).filter((e) => e.card);
    const total = entries.reduce((s, e) => s + e.qty, 0);
    const curve = [0, 0, 0, 0, 0, 0, 0];
    const types = { Unit: 0, Gear: 0, Program: 0 };
    const colors = Object.fromEntries(COLORS.map((c) => [c, 0]));
    let sellable = 0;
    let costSum = 0;
    for (const { card, qty } of entries) {
        curve[Math.min(6, Math.max(0, (card.cost ?? 0) - 1))] += qty;
        types[card.type] = (types[card.type] || 0) + qty;
        if (card.color in colors) colors[card.color] += qty;
        if (card.sellable) sellable += qty;
        costSum += (card.cost ?? 0) * qty;
    }
    return { total, curve, types, colors, sellable, avgCost: total ? costSum / total : 0 };
}

export function deckToText(deck, cardsByKey) {
    const line = (qty, card) => `${qty}x ${card.number} ${card.fullName}`;
    const legends = deck.legends.map((k) => cardsByKey.get(k));
    const main = deck.main
        .map((e) => ({ qty: e.qty, card: cardsByKey.get(e.key) }))
        .sort((a, b) => a.card.fullName.localeCompare(b.card.fullName, 'en'));
    return [
        `# Name: ${deck.name}`,
        '',
        '# Legends',
        ...legends.map((l) => line(1, l)),
        '',
        '# Main Deck',
        ...main.map((e) => line(e.qty, e.card)),
    ].join('\n');
}
