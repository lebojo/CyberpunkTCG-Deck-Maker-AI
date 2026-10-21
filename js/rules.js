// Synthèse des Comprehensive Rules (MAJ 1er sept. 2026), centrée sur la construction de deck.
// Envoyée telle quelle au modèle, en anglais pour coller au vocabulaire des cartes.
export const RULES_DIGEST = `
CYBERPUNK TCG — DECKBUILDING DIGEST (from the Comprehensive Rules, Sep 2026)

DECK CONSTRUCTION (hard rules)
- Exactly 3 Legends + a main deck of 40–50 non-Legend cards.
- The 3 Legends must have different names (subtitle ignored: "V — Streetkid" and "V — Corporate Exile" are both "V").
- Max 3 copies of a card with the same name + subtitle.
- RAM limits: each Legend adds its RAM value to its color. A main-deck card is legal only if its RAM <= the deck's RAM limit in that card's color.
  Every Legend currently has 2 RAM, so: 1 Legend of a color => cards of that color with RAM <= 2; 2 Legends => RAM <= 4; 3 Legends => RAM <= 6. Colors with no Legend => no cards.

HOW YOU WIN
- Start your turn with 7+ Gig dice in your friendly Gig area => you win. In Overtime (after ~7 turns each, when both fixer areas are empty) 7 Gigs at ANY moment wins.
- Each turn you roll in 1 die from your fixer area (d4, d6, d8, d10, d12, then d20 last). You only own 6 dice, so you MUST steal at least one rival Gig and protect your own.
- Losing: drawing from an empty deck (rarely relevant at 40 cards).

RESOURCES (critical for deck building)
- Costs are paid in €$ by spending Eddies (1 each) and/or Legends in the Legends area (1 each, face-down or face-up; a face-up Legend needs a Sell Tag, which nearly all have).
- Eddies only come from SELLING: once per turn (Main phase action) you sell 1 card from hand that has a Sell Tag (in this game: Gears, Programs and almost no Units). It becomes a permanent Eddie.
  => A deck needs enough sellable cards (Gears/Programs) to sell one EVERY early turn, or it falls behind on mana. Rule of thumb: ~16–22 sellable cards in 40, more for expensive/control decks.
- The 3 Legends are 3 extra €$ from turn 1 (the player going first starts with 2 of them spent).
- Call a Legend: pay 1 €$ once per turn (main phase, or as a reaction to an attack) to flip a face-down Legend face-up and trigger its {Call} effect. Face-up Legends' static/{Spend} effects then work.
- Opening hand 6 cards, one mulligan. Draw 1 per turn. Card draw and card selection are valuable because you also sell cards.

UNITS, COMBAT, STEALING
- Units enter with Lag: can't attack nor use {Spend} the turn they are played (except {Adrenaline}).
- Attack = spend a ready Unit and target either a SPENT rival Unit (fight) or the rival Gig area (steal). Ready Units cannot be attacked, so attacking leaves your Unit spent and exposed on the rival turn.
- Fight: higher power wins, ties = both lose; the loser is defeated (trash). A 0-power Unit never defeats anything.
- Steal: a Unit with power P steals floor(P/10)+1 Gigs (1–9 power = 1 Gig, 10–19 = 2 Gigs...). The attacker chooses which Gigs, so high-value Gigs are prime targets (Street Cred = sum of your Gig values; many cards check it or check "8+ value" Gigs).
- Gears equip to a Unit or face-up Legend: add their power and their bottom-textbox effects. Gears go with the Unit when it leaves.
- Programs are one-shot effects, then trash.

KEYWORDS
- {Play}: when played. {Attack}: when this Unit attacks. {Defeated}: when defeated. {Call}: when the Legend is flipped via Call a Legend.
- {Spend}: spend this card as an activation cost (Units can't do it while lagging).
- {Adrenaline}: can attack the turn it's played.
- {Blocker}: when a rival Unit attacks, you may spend this Unit to become the new attack target (protects your Gigs).
- {Go Solo} (Legends): pay the Legend's cost to put it on the field as a ready Unit that can attack this turn; if it leaves the field it is removed from the game.
- {Quick}: can also be used/played as a reaction during the rival's attack.

GOOD DECK PRINCIPLES FOR THIS GAME
- Mana curve: most cards at cost 1–4; only a few 5+ finishers unless the deck ramps. Turn N you usually have about (N-1 Eddies + 3 Legends) €$.
- Balance Units (pressure, stealing, blocking) vs sellable Gears/Programs (economy + effects). Typical: 18–24 Units, 16–22 Gears/Programs.
- Maximize synergies: Legends that reference TAGS (ARASAKA, BRAINDANCE, ROCKER, CORPO, GANGER...), card types (Gear, Program, Blue Unit...) or mechanics (Gigs 8+, value-pairs, min/max Gigs, Blocker) should be backed by many cards that feed them.
- Prefer 3 copies of key cards for consistency; 40 cards maximizes consistency (only go above 40 with a reason).
- Have answers: removal (defeat / -power / spend a rival Unit), Blockers or Gig protection, and card advantage.
`.trim();

export const ARCHETYPES = {
    aggro: {
        label: 'Aggro',
        hint: 'Vole des Gigs vite',
        brief: 'AGGRO: steal Gigs as early and as often as possible. Low curve (mostly cost 1–4), efficient power-per-cost Units, {Adrenaline}/{Go Solo}, +power effects and steal-boosting effects. Few expensive cards. Win before turn 7 or right at Overtime.',
        weights: { efficiency: 3, haste: 3, steal: 2.5, pump: 2, removal: 1, draw: 0.8, blocker: 0.3, gig: 1, unit: 1.5, cheap: 2.5, expensive: -2.5 },
    },
    midrange: {
        label: 'Midrange',
        hint: 'Tempo + valeur',
        brief: 'MIDRANGE: efficient Units at every point of the curve, flexible removal and card advantage. Trade well in fights, then take over with bigger threats and steal at the right moment.',
        weights: { efficiency: 2.5, haste: 1, steal: 1.5, pump: 1, removal: 2, draw: 1.5, blocker: 1, gig: 1, unit: 0.8, cheap: 1, expensive: 0 },
    },
    control: {
        label: 'Contrôle',
        hint: 'Bloque, retire, gagne tard',
        brief: 'CONTROL: deny the rival\'s steals with Blockers, removal and Gig protection, accumulate card advantage, then win late (Overtime or big finishers / swaps). More sellable cards for a stronger economy.',
        weights: { efficiency: 1, haste: 0, steal: 0.5, pump: 0.3, removal: 3, draw: 2.5, blocker: 2.5, gig: 1.5, unit: 0, cheap: 0, expensive: 0.8 },
    },
    gigs: {
        label: 'Manipulation de Gigs',
        hint: 'Adjust, swap, Street Cred',
        brief: 'GIG MANIPULATION: build around adjusting, setting, swapping and increasing Gigs (value-pairs, min/max Gigs, 8+ value Gigs, Street Cred thresholds). Pick the Legends and cards whose conditions feed each other.',
        weights: { efficiency: 1, haste: 0.3, steal: 1.5, pump: 0.5, removal: 1, draw: 1.5, blocker: 1, gig: 3.5, unit: 0.3, cheap: 0.5, expensive: 0 },
    },
    synergy: {
        label: 'Synergie de tags',
        hint: 'Tribal / Gear / Program',
        brief: 'SYNERGY: go all-in on the strongest shared theme of the Legends (a tag like ARASAKA/BRAINDANCE/ROCKER, or Gears/Programs). Include as many enablers and payoffs of that theme as possible.',
        weights: { efficiency: 1.5, haste: 0.5, steal: 1, pump: 1, removal: 1, draw: 1.5, blocker: 0.5, gig: 1, unit: 0.5, cheap: 0.5, expensive: 0, legendSynergy: 2.5 },
    },
};
