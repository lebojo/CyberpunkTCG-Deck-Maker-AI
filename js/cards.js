const API = 'https://api.netdeck.gg/api/cards/cyberpunk';
const PAGE = 100;

export async function fetchAllCards() {
    const items = [];
    let total = Infinity;
    while (items.length < total) {
        const res = await fetch(`${API}?limit=${PAGE}&offset=${items.length}`);
        if (!res.ok) throw new Error(`NetDeck a répondu HTTP ${res.status}`);
        const page = await res.json();
        total = page.total;
        if (!page.items.length) break;
        items.push(...page.items);
    }
    return items.map(normalize);
}

function normalize(raw, index) {
    return {
        key: `c${index + 1}`,
        name: raw.name,
        baseName: raw.canonical_base_name || raw.name,
        fullName: raw.canonical_name || raw.display_name,
        number: raw.print_number || '',
        type: raw.card_type,
        color: raw.color,
        cost: raw.cost,
        power: raw.power,
        ram: raw.ram,
        sellable: Boolean(raw.is_eddiable),
        tags: raw.classifications || [],
        text: (raw.rules_text || '').trim(),
        rarity: raw.rarity,
        set: raw.set?.name || '',
        image: raw.image_url || raw.source_image_url,
        legal: (raw.legality || 'legal') === 'legal',
    };
}
