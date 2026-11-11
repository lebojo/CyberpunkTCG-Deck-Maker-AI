// Moteur local : légalité, validation et réparation du deck renvoyé par l'IA.
// Aucune heuristique de qualité : le choix des Légendes et des cartes appartient entièrement à l'agent.

export const COLORS = ['Red', 'Green', 'Blue', 'Yellow'];
export const MIN_MAIN = 40;
export const MAX_MAIN = 50;
export const MAX_COPIES = 3;

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
export function repairDeck(deck, cardsByKey, legalPool, fallbackLegends, target = MIN_MAIN) {
    const fixes = [];
    let legends = deck.legends.map((k) => cardsByKey.get(k));
    if (legends.length !== 3 || legends.some((l) => !l || l.type !== 'Legend') || new Set(legends.map((l) => l.baseName)).size < 3) {
        legends = fallbackLegends;
        fixes.push('Trio de Légendes invalide, remplacé par un trio légal.');
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
    const fillOrder = legalPool
        .filter((c) => isLegalFor(c, limits))
        .sort((a, b) => (b.sellable - a.sellable) || ((a.cost ?? 9) - (b.cost ?? 9)));
    for (const card of fillOrder) {
        if (total >= target) break;
        const current = counts.get(card.fullName) || { card, qty: 0 };
        const add = Math.min(MAX_COPIES - current.qty, target - total);
        if (add <= 0) continue;
        counts.set(card.fullName, { card, qty: current.qty + add });
        total += add;
        fixes.push(`Ajouté : ${add}x ${card.fullName} (deck incomplet).`);
    }
    if (total > MAX_MAIN) {
        const entries = [...counts.values()].reverse();
        for (const entry of entries) {
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
