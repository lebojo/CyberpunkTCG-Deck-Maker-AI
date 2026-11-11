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

STRATEGIC FACTS (no prescribed template: you decide the deck's shape)
- The game lasts about 7 turns each before Overtime, so the deck's plan must come together inside that window: count how many turns your engine/combo needs, and what it does on turns 1-3 while it assembles.
- Turn N you have about (N-1 Eddies + 3 Legends) €$ if you sold a card every turn. Every card sold is a card not played: sellable cards are both fuel and effects.
- A Legend is both a resource (€$), a late Unit ({Go Solo}) and a source of static/{Spend} effects. The 3 Legends should reinforce each other AND the main deck's cards: judge them by the plan they enable, not by how many playable cards their colors offer.
- Max copies is 3; a 40-card deck maximizes consistency, going up to 50 needs a reason. Copy counts should reflect each card's role in the plan.
`.trim();

// Simples orientations transmises à l'agent : aucune pondération, aucun score.
export const ARCHETYPES = {
    free: {
        label: 'Libre',
        hint: 'Le meilleur deck possible',
        brief: 'FREE: no imposed style. Find the strongest, most coherent strategy available in the allowed colors, whatever it is.',
    },
    aggro: {
        label: 'Aggro',
        hint: 'Vole des Gigs vite',
        brief: 'AGGRO: win by stealing Gigs fast, before the rival stabilizes.',
    },
    midrange: {
        label: 'Midrange',
        hint: 'Tempo + valeur',
        brief: 'MIDRANGE: trade efficiently, then take over with value and well-timed steals.',
    },
    control: {
        label: 'Contrôle',
        hint: 'Bloque, retire, gagne tard',
        brief: 'CONTROL: deny the rival\'s steals, grind them out, win late.',
    },
    gigs: {
        label: 'Manipulation de Gigs',
        hint: 'Adjust, swap, Street Cred',
        brief: 'GIG MANIPULATION: the plan revolves around adjusting, setting, swapping and increasing Gigs.',
    },
    synergy: {
        label: 'Synergie de tags',
        hint: 'Tribal / Gear / Program',
        brief: 'SYNERGY: go all-in on one shared theme (a tag, a card type or a mechanic) and its enablers/payoffs.',
    },
};
