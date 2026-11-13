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
- `--ai search|greedy|versus` : IA qui explore ses coups (défaut), heuristique rapide, ou 1er deck en recherche contre le 2e en heuristique.
- `--samples N --depth N --shortlist N` : réglages de la recherche (3 mains adverses tirées par décision, 3 tours projetés, 4 coups approfondis).
- `--md fichier.md` : écrit aussi le tableau des résultats au format Markdown (tournoi, matrice ou duel).
- `--seed` pour reproduire un résultat, `--workers N` pour limiter le parallélisme.
- `--coverage` : liste, par couleur et par type, les cartes qui ont une implémentation dédiée, celles couvertes par leurs seuls mots-clés ou dont le texte n'est que de l'ambiance, et celles qui restent à coder. Sans deck, n'affiche que cette liste.
- `--no-live` et `--bluff on|off` : acceptées, sans effet pour l'instant (affichage en direct et bluff à venir).

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
- Référence figée (IA gloutonne) : depuis `Regression/decks/`, `../../.build/release/DeckSim Meta1_*.txt Meta2_*.txt Meta3_*.txt Maelstrom_Gear_Rush_40.txt Maelstrom_Gear_Rush_Meredith_C.txt --ai greedy --seed 42 --games 2000` doit redonner `Regression/baseline-greedy-seed42.txt` (hors durée). Le refactor SimCore la reproduit à l'identique.
- En mode recherche, les résultats varient légèrement d'un lancement à l'autre (ordre d'itération des ensembles), comme avant le refactor.

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

Pendant un combat, les deux joueurs peuvent utiliser leurs capacités `.fight` à tour de rôle (Floor It, Synapse Burnout, Dum Dum, Safety Override) tant que cela change l'issue.

## Limites

Le simulateur reste une approximation : l'adversaire simulé joue de façon gloutonne dans la recherche, il n'y a pas encore de bluff, et un effet de carte mal codé fausse tous les résultats du deck. Les résultats servent à comparer des decks entre eux, pas à prédire un tournoi réel.
