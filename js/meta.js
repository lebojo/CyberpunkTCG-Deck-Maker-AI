// Snapshot de la méta publique (ripperdeck.gg/meta, 11 nov. 2026, 835 decks légaux sur 30 jours).
// Donné au modèle comme référence de ce qui marche, jamais comme contrainte.
// Format des listes : quantité x nom (coût). Les % sont la part des decks de l'archétype qui jouent la carte.
export const META_DIGEST = `
CURRENT META SNAPSHOT (ripperdeck.gg, 11 Nov 2026, 835 public decks over 30 days)
Use it as INSPIRATION about what real players found strong: proven engines, curves, ratios and tech choices. You are NOT bound to it: if you see a stronger or more original build in the card pool, build that. Card names below must be matched to keys in the CARD POOL; a card is only usable if it is in the pool and legal for your trio's RAM limits.

GENERAL OBSERVATIONS
- Practically every competitive deck is exactly 40 cards, with 3 copies of its core cards (consistency over variety).
- Typical split: 13-20 Units, 2-17 Gears, 9-23 Programs depending on the plan. Gear decks and Program decks both exist: the mix follows the Legends' synergies.
- Cheap Gears (cost 1-2) like Mantis Blades, Satori - Sword of Saburo, Zetatech Faceplate, Mandibular Upgrade are played at ~100% in red-based decks: they are both the economy (sellable) and the Unit power.
- Most decks are built on 2 colors (RYY, RRY, GRR, GGR, BBG, BBR: a color doubled gives RAM 4 in it, the third color gives RAM 2 splash).

META ARCHETYPES (share of decks)
1. Dum Dum / River Ward / Royce, RYY, 10% : GEAR deck, Gears + Adrenaline (Adrenaline Converter makes Gears rewarding; Mantis Blades feeds Maelstrom Goons; Cyberpsychosis rewards Gears).
   Reference list (40): 3 Secondhand Bombus (2), 2 Sketchy Ripper (2), 2 Augmented Negotiators (3), 2 Maelstrom Goons (3), 2 Swordwise Huscle (3), 1 Viktor Vektor - Drop Your Illusions (5), 1 Alt Cunningham - Mother of Daemons (7); Gears: 2 Kiroshi Optics (1), 2 Mandibular Upgrade (1), 3 Mantis Blades (1), 1 Adrenaline Converter (2), 3 Satori - Sword of Saburo (2), 3 Zetatech Faceplate (2), 2 Gorilla Arms (4), 1 The Relic - Experimental Biochip (5); Programs: 2 Afterparty at Lizzie's (1), 2 Safety Override (2), 2 The Heist (2), 2 Cyberpsychosis (3), 2 Bootleg Black Sapphire Show (5).
2. Alt Cunningham / Hanako Arasaka / Jackie Welles: Pour One Out For Me, BBG, 9% : PROGRAM deck with min-Gig conditions (Lizzy Wizzy supports Programs costing 3 or less; Trust No One / Chrome Reverie want a minimum Gig).
   Reference list (40): Units: 3 Jacked-In Voodoo Boy (2), 3 Pepe Najarro - Working Doubles (4), 3 Lizzy Wizzy - Delicate Weapon (5), 2 Maman Brigitte - Spirit of Death (5), 3 MT0D12 Flathead (5), 1 Modded Kusanagi (6), 2 Placide - Voodoo Sentinel (8); Programs: 3 Floor It (1), 3 Synapse Burnout (1), 3 Trust No One (1), 3 Take Control (2), 3 Chrome Reverie (3), 2 Nocturne OP55 N1 (5), 3 Pyramid Song (3), 3 Les Élémens (5). Also widely played: Peace Offering, Three Mouths One Desire, Towerfall, Memory Relapse.
3. Goro Takemura: Hands Unclean / Saburo Arasaka / Yorinobu Arasaka, GGR, 7% : ARASAKA / face-up Legends deck that punishes SPENT rival Units (Corporate Surveillance, Satori; Arasaka Emergency Radioport counts face-up Legends).
   Reference list (40): Units: 3 Field Operator (3), 2 La Llorona - Ghost of the Past (3), 3 Swordwise Huscle (3), 3 Goro Takemura - Losing His Way (4), 2 MaxTac AV (5), 2 Minotaur (7), 3 Sandayu Oda - Hanako's Guardian (7); Gears: 3 Arasaka Emergency Radioport (2), 3 Satori - Sword of Saburo (2), 3 Sandevistan (3); Programs: 3 Detonate (1), 3 Industrial Assembly (1), 3 Peace Offering (1), 2 Corporate Surveillance (2), 2 Wild in the Streets (5). Common alternatives: Mantis Blades, Corpo Security, Emergency Atlus, Shattered Memories, Over the Edge.
4. Adam Smasher / River Ward / Viktor Vektor, RYY, 5% : Gear aggro with Johnny Silverhand and big Programs.
   Reference list (40): Units: 3 Sketchy Ripper (2), 3 6th Street Recruits (4), 2 Meredith Stout - Stone Cold Corpo (4), 3 MaxTac Suppression Team (5), 1 Rockn' Rockerboy (5), 3 Johnny Silverhand - Never Stop Fighting (6); Gears: 3 Mandibular Upgrade (1), 3 Mantis Blades (1), 3 Adrenaline Converter (2), 3 Satori - Sword of Saburo (2), 3 Zetatech Faceplate (2), 1 Gorilla Arms (4); Programs: 2 Detonate (1), 3 Live with the Aftermath (3), 1 Over the Edge (3), 3 Bootleg Black Sapphire Show (5).
5. Alt Cunningham / Judy Álvarez: Braindance Maestro / V: Streetkid, BBR, 4% : BRAINDANCE + min Gig, Program-heavy, 20 Units / only 2 Gears.
   Reference list (40): Units: 2 Evelyn Parker - Scheming Siren, 3 Jacked-In Voodoo Boy (2), 3 Hacked Corpo, 3 Meredith Stout - Stone Cold Corpo (4), 2 Rita Wheeler - No Stupid Questions, 2 Lizzy Wizzy - Delicate Weapon (5), 2 Maman Brigitte - Spirit of Death (5), 2 Screw - Lovelorn Fool, 1 Placide - Voodoo Sentinel (8); Gear: 2 Dying Night - V's Pistol; Programs: 3 Industrial Assembly (1), 3 Trust No One (1), 3 Three Mouths One Desire, 3 Chrome Reverie (3), 3 Pyramid Song (3), 3 Shattered Memories.
6. Adam Smasher / Dum Dum / V: Streetkid, RRY, 3% : high-end red: heavy top-end Units and big Programs on cheap Gears.
   Reference list (40): Units: 3 Augmented Negotiators (3), 3 6th Street Recruits (4), 3 Rockn' Rockerboy (5), 3 Animals Wrecker (6), 3 Yorinobu Arasaka - Steel Dragon (7); Gears: 3 Mantis Blades (1), 3 Satori - Sword of Saburo (2), 3 Zetatech Faceplate (2); Programs: 3 All is Lost (1), 1 Industrial Assembly (1), 3 Appetite for Destruction (3), 3 Bonnie and Clyde (3), 3 Over the Edge (3), 3 Carnage at the Colosseum (6).
7. Adam Smasher / Padre: Man of the Cross / V: Streetkid, GRR, 3% : red/green tempo with a Program-heavy top end.
   Reference list (40): Units: 3 6th Street Recruits (4), 3 Meredith Stout - Stone Cold Corpo (4), 3 Pepe Najarro - Working Doubles (4), 3 Animals Wrecker (6), 2 Valentino Street Racer (3), 2 Yorinobu Arasaka - Steel Dragon (7); Gears: 3 Mantis Blades (1), 3 Satori - Sword of Saburo (2); Programs: 3 Industrial Assembly (1), 3 Peace Offering (1), 3 Synapse Burnout (1), 3 Bonnie and Clyde (3), 3 Memory Relapse (4), 3 Carnage at the Colosseum (6).

HOW TO USE THIS
- Learn from the engines: which Legend text each deck exploits and which cards it plays around it (e.g. Gear + Adrenaline, cheap Programs + min Gig, spent-Unit punishment + face-up Legends).
- Anticipate this meta: your deck will face these gear-heavy and Program-heavy plans, so consider how it beats them (Blockers vs Gear steals, removal vs big Units, etc.).
- If the player explicitly asks for a meta deck, start from the closest reference list and adapt it to the pool; otherwise only borrow ideas and innovate.
`.trim();
