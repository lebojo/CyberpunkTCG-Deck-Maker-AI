# DeckSim

Simulateur de parties Cyberpunk TCG en Swift (CLI). Il lit des decklists `.txt` (le format exporté par le site), joue des milliers de parties en parallèle (une tâche par cœur) et sort les win rates. Le contrat d'architecture est dans `ARCHITECTURE.md`, le guide pour coder une carte dans `Docs/CARD_AUTHORING.md`.

## Utilisation

```
swift build -c release

.build/release/DeckSim deckA.txt deckB.txt --games 20000
.build/release/DeckSim deck1.txt deck2.txt deck3.txt ... --games 20000
.build/release/DeckSim deckA.txt deckB.txt --trace --seed 7
.build/release/DeckSim --coverage
```

- 2 decks : duel détaillé (win rate, marge d'erreur à 95 %, premier/second joueur, durée, mulligans, types de fin de partie).
- 3 decks ou plus : matrice de tous les duels et classement.
- `--trace` : déroulé d'une seule partie, pour vérifier que l'IA joue correctement.
- `--tournaments N [--bo 3]` : N tournois à élimination directe (ordre de départ aléatoire à chaque tournoi), classés par titres gagnés.
- `--ai search|greedy` : politique des deux sièges, recherche (défaut) ou heuristique rapide. `--ai versus` (outil de dev) : 1er deck en recherche, 2e en heuristique.
- `--opponent-budget N` : budget de l'adversaire simulé dans la recherche (défaut 1, 0 = adversaire glouton comme avant).
- `--bluff on|off` : bluff de l'IA (défaut `off`, voir « L'IA »).
- Outils de dev : `--ai-old b|all` fait jouer l'ancienne IA (sans bluff, défense ni adversaire simulé) au 2e deck ou aux deux ; `--bluff-ab` active le bluff pour le 1er deck seulement.
- `--samples N --depth N --shortlist N` : réglages de la recherche (3 mains adverses tirées par décision, 3 tours projetés, 4 coups approfondis).
- `--md fichier.md` : écrit aussi le tableau des résultats au format Markdown (tournoi, matrice ou duel).
- `--seed` pour reproduire un résultat, `--workers N` pour limiter le parallélisme.
- `--coverage` : liste, par couleur et par type, les cartes qui ont une implémentation dédiée, celles couvertes par leurs seuls mots-clés ou dont le texte n'est que de l'ambiance, et celles qui restent à coder. Sans deck, n'affiche que cette liste.
- `--no-live` : désactive l'affichage en direct.

Au lancement, les cartes des decks qui n'ont pas encore d'effet codé sont listées (elles sont jouées comme des cartes sans texte, mots-clés compris).

## Base de cartes

La base est embarquée : `Sources/SimCore/Resources/cards.json` (schéma 1, trié par `canonicalName`), lue via `Bundle.module`. Le simulateur n'accède jamais au réseau. Le binaire doit rester à côté de son bundle de ressources (`.build/release/DeckSim_SimCore.bundle`).

Pour rafraîchir la base depuis NetDeck :

```
swift run -c release FetchCards             # réécrit Sources/SimCore/Resources/cards.json
swift run -c release FetchCards --dry-run   # affiche seulement les cartes ajoutées (+), modifiées (~) ou disparues (-)
```

`FetchCards` refuse d'écrire si le nombre de cartes diminue. Il produit exactement le même fichier tant que NetDeck ne change rien.

## Structure

```
Sources/SimCore/            bibliothèque (tout le métier)
  Resources/cards.json      base embarquée
  Cards/Model/              CardData, CardKind/CardColor, CardTag, Keyword, RulesText, GameCard, AIHints
  Cards/Database/           CardDatabase (JSON), CardCatalog (cartes du jeu par id), CardRegistry (clé -> implémentation), DeckList
  Cards/Definitions/<Couleur>/  un fichier par carte codée ; Generic/ : VanillaCard, KeywordCard
  Engine/State/             Game, Player, FieldUnit, Gig, TurnFlags, effets en attente, Rng, TraceLog
  Engine/Rules/             tour, mana, zones, jeu des cartes, capacités, puissance, combat, Gigs
  Engine/Effects/           GameEvent, EventDispatcher, EffectContext/EffectQuery, GameReading, GameActions, CardModifiers, ActivatedAbility
  AI/Heuristics/            IA gloutonne (Strategy), valeurs, mulligan, ciblage, blocage, réponses rapides, Gigs
  AI/Search/                recherche par déterminisation
  AI/Policy/                réglages de la politique (SearchConfig, Policy), bluff et garde des Blockers
  Simulation/               duels et tournois parallèles
  Reporting/                rapports texte et Markdown, couverture
Sources/DeckSim/            exécutable CLI (main.swift, CLI/Options.swift)
Sources/FetchCards/         exécutable NetDeck -> cards.json
Tests/SimCoreTests/         tests XCTest (swift test)
Regression/                 decks et résultat de référence
Docs/CARD_AUTHORING.md      guide pour coder une carte
```

Chaque carte est un `struct` conforme à `GameCard` : ses données viennent de `cards.json`, son comportement de `action` (événements du jeu), `modifiers` (effets continus), `abilities` (capacités activées) et `playValue`/`keepValue` (ce que l'IA en pense). Le moteur ne connaît aucune carte par son nom.

## Ajouter une carte en 3 étapes

1. Lire son texte et sa `key` dans `cards.json`.
2. Créer `Sources/SimCore/Cards/Definitions/<Couleur>/<NomDeLaCarte>.swift` avec un `struct` conforme à `GameCard` (voir les exemples de `Docs/CARD_AUTHORING.md`).
3. L'enregistrer dans `Sources/SimCore/Cards/Database/CardRegistry.swift` (`entry("sa-key", NomDeLaCarte.self)`), puis `swift build -c release`, `swift test` et `.build/release/DeckSim --coverage`.

## Tests et non-régression

- `swift test` : chargement de la base, parsing de deck, règles (vol par tranche de 10, Blocker, Lag, mulligan, victoire à 7 Gigs, vente, Appel), et un test par type de capacité (Play, Attack, Defeated, Spent, Quick, fin de tour, continu, coût, différé, remplacement, choix de mode).
- Référence figée (IA gloutonne) : depuis `Regression/decks/`, `../../.build/release/DeckSim Meta1_*.txt Meta2_*.txt Meta3_*.txt Maelstrom_Gear_Rush_40.txt Maelstrom_Gear_Rush_Meredith_C.txt --ai greedy --ai-old all --seed 42 --games 2000` doit redonner `Regression/baseline-greedy-seed42.txt` (hors durée), à l'identique. Sans `--ai-old all`, l'heuristique gloutonne tient compte de la défense et des Quick possibles, et les chiffres changent.
- En mode recherche, les résultats sont reproductibles avec `--workers 1 --seed N` (l'ordre des coups « vendre » ne dépend plus de l'ordre d'itération d'un ensemble).

## Ce qui est modélisé

Règles : pioche, mulligan (décidé par l'IA : elle garde sa main sauf si son score est nettement sous celui d'une main tirée au hasard dans son deck), Légendes face cachée et Appel de Légende, vente de cartes (Eddies), dés de Gigs (d4 à d20), Lag, attaque, Blockers, combat, vol (1 Gig par tranche de 10 de puissance), Gears équipés aux Units et aux Légendes, Go Solo, Overtime, pioche vide.

Effets : les 74 cartes déjà codées avant le refactor (dont toutes celles des decks de référence) sont migrées : 72 implémentations dédiées et 2 cartes à mots-clés seuls (`KeywordCard`), plus 2 autres cartes à mots-clés seuls. `--coverage` donne la liste à jour des cartes restantes.

Divergences connues, conservées volontairement pour que la non-régression reste exacte (à corriger plus tard, chaque correction pouvant changer les résultats des decks concernés) :

- The Heist et River Ward perdent une carte quand deux exemplaires identiques sont regardés en même temps ; V — Streetkid retire de la défausse tous les exemplaires du Program qu'il récupère, et ne le cherche que parmi les 3 cartes meulées.
- L'échange de Gigs de Hanako ne déclenche pas Meredith Stout, et une seule Meredith récupère une carte même s'il y en a plusieurs.
- Take Control ne fait pas piocher contre un AI/Drone/Vehicle ; Cyberpsychosis fait toujours vaincre le Unit en fin de tour ; Detonate n'est joué qu'en phase principale.
- Nouvelles différences (sans effet sur les decks de référence) : l'aura de Saul Bright se cumule s'il y en a plusieurs, ses Units sont réveillés après les défaites programmées de fin de tour, et un Unit ramené par The Relic déclenche les effets « quand vous jouez un Unit » (Jackie Welles).

## L'IA

À chaque décision l'IA liste tous ses coups (vendre, appeler, jouer chaque carte avec chaque cible d'équipement, Go Solo, chaque attaque sur chaque cible, capacités activées des cartes), puis :

1. tire plusieurs mains adverses plausibles (le deck adverse est connu, les cartes révélées par des recherches ou la défausse sont conservées dans la main tirée, les Légendes face cachée sont mélangées) ;
2. joue chaque coup puis le reste du tour, et note le plateau (Gigs, menace des Units, main, Eddies, Légendes) ;
3. approfondit les meilleurs coups sur 3 tours (réponse adverse, son prochain tour, puis la réponse suivante), avec un poids décroissant ;
4. joue le coup au meilleur score moyen et recommence jusqu'à ce que « finir le tour » soit le meilleur.

Les deux sièges utilisent la même politique. Dans l'approfondissement, le premier tour adverse simulé est joué par cette même politique à budget réduit (1 main tirée, pas d'approfondissement, choix entre plans de tour complets : finir, tour glouton, garder ses Blockers, bluffer ; `--opponent-budget N` ajoute N-1 décisions coup par coup avant ce choix), puis glouton au-delà. Coût mesuré (500 parties, 10 cœurs) : Meta1/Meta2 2,6 s → 6,0 s, Meta3/Maelstrom 40 5,0 s → 8,4 s (≈ 1,7 à 2,3×).

**Quick possibles.** Sans jamais lire la main cachée, l'IA estime la probabilité que l'adversaire ait un Quick payable : loi hypergéométrique sur les cartes non vues (main non révélée + pioche, le deck étant connu), en ne comptant que les Quick dont le coût tient dans le mana ouvert. Une attaque marginale (écart de puissance ≤ 3 face à la cible ou à un Blocker prêt) est pénalisée en proportion.

**Bluff** (`--bluff on`). Coup « bluffer » : développer en gardant ouvert le coût du Quick le moins cher de son deck, sans attaquer, pour représenter un Quick ou un Blocker. Il est évalué comme les autres coups ; l'adversaire simulé est dissuadé (à tort ou à raison) par l'estimation ci-dessus. Test A/B (bluff pour le 1er siège seulement, miroirs, 1000 parties, graine 21) : Maelstrom 40 50,2 %, Maelstrom Meredith 49,6 %, Meta1 49,0 %, Meta2 52,3 %, Meta3 50,4 % ; moyenne 50,3 % ±1,4 %. L'intervalle descend sous 50 % : le gain n'est pas établi, le défaut est donc `off`.

**Défense.** « Garder ses Blockers à la maison » est un coup candidat (tour glouton où les Blockers n'attaquent pas). La valeur défensive d'un Blocker prêt se calcule face aux attaquants adverses du tour suivant (Units en jeu qui pourront attaquer, plus le meilleur Unit avec Adrenaline ou qui attaque en arrivant, pondéré par sa probabilité d'être en main) et à la valeur des Gigs sauvés ; elle entre, avec un petit poids, dans l'évaluation et dans le coût d'une attaque du Blocker. Scénarios testés (`Tests/SimCoreTests/AITests.swift`) : l'IA garde un Blocker plutôt que de tuer un Unit sans risque quand l'adversaire menace ses Gigs, et attaque quand rien ne menace.

Force mesurée (nouvelle politique sur le 1er siège, ancienne sur le 2e, miroirs, 1000 parties, graine 31) : Meta1 47,9 %, Meta2 48,1 %, Meta3 51,4 % (±3,1 %) : pas de gain significatif ; des poids de défense plus forts faisaient perdre 3 à 5 points.

Pendant un combat, les deux joueurs peuvent utiliser leurs capacités `.fight` à tour de rôle (Floor It, Synapse Burnout, Dum Dum, Safety Override) tant que cela change l'issue.

## Limites

Le simulateur reste une approximation : l'adversaire simulé n'a qu'un petit budget, le bluff et la défense restent heuristiques, et un effet de carte mal codé fausse tous les résultats du deck. Les résultats servent à comparer des decks entre eux, pas à prédire un tournoi réel.
