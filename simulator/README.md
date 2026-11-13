# DeckSim

Simulateur de parties Cyberpunk TCG en Swift (CLI). Il lit des decklists `.txt` (le format exporté par le site), joue des milliers de parties en parallèle (une tâche par cœur) et sort les win rates.

## Utilisation

```
swift build -c release

.build/release/DeckSim deckA.txt deckB.txt --games 20000
.build/release/DeckSim deck1.txt deck2.txt deck3.txt ... --games 20000
.build/release/DeckSim deckA.txt deckB.txt --trace --seed 7
```

- 2 decks : duel détaillé (win rate, marge d'erreur à 95 %, premier/second joueur, durée, mulligans, types de fin de partie).
- 3 decks ou plus : matrice de tous les duels et classement.
- `--trace` : déroulé d'une seule partie, pour vérifier que l'IA joue correctement.
- `--tournaments N [--bo 3]` : N tournois à élimination directe (ordre de départ aléatoire à chaque tournoi), classés par titres gagnés.
- `--ai search|greedy|versus` : IA qui explore ses coups (défaut), heuristique rapide, ou 1er deck en recherche contre le 2e en heuristique.
- `--samples N --depth N --shortlist N` : réglages de la recherche (3 mains adverses tirées par décision, 3 tours projetés, 4 coups approfondis).
- `--md fichier.md` : écrit aussi le tableau des résultats au format Markdown (tournoi, matrice ou duel).
- `--seed` pour reproduire un résultat, `--workers N` pour limiter le parallélisme.

Les cartes sont téléchargées une fois depuis NetDeck puis mises en cache dans `~/.cache/cyberpunk-deck-sim/cards.json` (`--cards` pour un autre chemin).

## Ce qui est modélisé

Règles : pioche, mulligan (décidé par l'IA : elle garde sa main sauf si son score est nettement sous celui d'une main tirée au hasard dans son deck), Légendes face cachée et Appel de Légende, vente de cartes (Eddies), dés de Gigs (d4 à d20), Lag, attaque, Blockers, combat, vol (1 Gig par tranche de 10 de puissance), Gears équipés aux Units et aux Légendes, Go Solo, Overtime, pioche vide.

Effets : les 72 cartes des decks testés ont leur effet codé à la main (`Cards/Behavior.swift`, `Engine/Effects.swift`, `Engine/Combat.swift`). Une carte inconnue est jouée sans effet, et la liste est affichée au lancement.

## L'IA

À chaque décision l'IA liste tous ses coups (vendre, appeler, jouer chaque carte avec chaque cible d'équipement, Go Solo, chaque attaque sur chaque cible, pouvoirs de Légendes), puis :

1. tire plusieurs mains adverses plausibles (le deck adverse est connu, les cartes révélées par des recherches ou la défausse sont conservées dans la main tirée, les Légendes face cachée sont mélangées) ;
2. joue chaque coup puis le reste du tour, et note le plateau (Gigs, menace des Units, main, Eddies, Légendes) ;
3. approfondit les meilleurs coups sur 3 tours (réponse adverse, son prochain tour, puis la réponse suivante), avec un poids décroissant ;
4. joue le coup au meilleur score moyen et recommence jusqu'à ce que « finir le tour » soit le meilleur.

Pendant un combat, les deux joueurs peuvent jouer leurs Quick à tour de rôle (Floor It, Synapse Burnout, Dum Dum, Safety Override) tant que cela change l'issue.

## Limites

Le simulateur reste une approximation : l'adversaire simulé joue de façon gloutonne dans la recherche, il n'y a pas de bluff, et un effet de carte mal codé fausse tous les résultats du deck. Les résultats servent à comparer des decks entre eux, pas à prédire un tournoi réel. Idéalement, il faut les confronter à de vrais résultats de parties.
