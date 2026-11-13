# DeckSim – contrat d'architecture

Ce document est le contrat que suivent tous les contributeurs (humains et agents). Si une décision n'y figure pas, choisir le plus simple et le noter dans le README.

## 1. Objectifs

1. Chaque carte du jeu (152 cartes, base `Sources/SimCore/Resources/cards.json`) a ses effets codés. Plus aucune carte « jouée sans texte » sauf celles dont le texte n'est que du flavor.
2. Une carte est un objet : des données (type, couleur, puissance, coût, vendable, RAM, tags…) plus une fonction `action` qui réagit aux événements du jeu. Le moteur ne contient plus aucun `switch` sur un nom de carte.
3. Le simulateur ne télécharge jamais rien à l'exécution : il lit sa base embarquée (`cards.json`). Un exécutable séparé `FetchCards` rafraîchit cette base depuis NetDeck.
4. Les deux joueurs jouent exactement avec la même IA (même politique, mêmes réglages). L'IA peut bluffer, et sait qu'il vaut parfois mieux ne pas attaquer et garder ses Blockers en défense.
5. Le terminal affiche une progression en direct (pourcentage global, tableau par deck, nombre de matchs, win rate).
6. Dossiers bien rangés, un fichier = une responsabilité.

## 2. Arborescence cible

```
simulator/
  Package.swift
  README.md
  ARCHITECTURE.md
  Sources/
    SimCore/                    bibliothèque (tout le métier)
      Resources/cards.json      base de cartes embarquée (Bundle.module)
      Cards/
        Model/                  GameCard, CardKind, CardColor, CardTag, Keyword, CardData
        Database/               CardDatabase (lecture du JSON), CardRegistry (clé -> implémentation), DeckList (parse .txt)
        Definitions/
          Blue/  Green/  Red/  Yellow/    un fichier par carte (ou par petit groupe de cartes jumelles)
          Generic/                         VanillaCard, cartes à mot-clé seul
      Engine/
        State/                  Game, Player, FieldUnit, LegendSlot, Gig, TurnFlags, Outcome, TraceLog
        Rules/                  Turn, Combat, Power, Gigs (vol, ajustement), Mana, Setup/Mulligan
        Effects/                GameActions (API publique utilisée par les cartes), GameEvent, EventDispatcher
      AI/
        Search/                 recherche, déterminisation, évaluation
        Heuristics/             Strategy gloutonne, Valuation, Mulligan, Bluff, Defense
      Simulation/               Simulator, Tournament, ProgressTracker
      Reporting/                Report (texte), MarkdownReport, LiveDashboard
    DeckSim/                    exécutable CLI (produit nommé DeckSim)
      main.swift
      CLI/                      Options, parsing, usage
    FetchCards/                 exécutable : NetDeck -> Sources/SimCore/Resources/cards.json
  Tests/SimCoreTests/           tests XCTest (si `swift test` fonctionne) : règles, cartes, parsing
```

Le produit exécutable doit rester `.build/release/DeckSim` avec toutes les options CLI actuelles (voir §9).

## 3. Modèle de carte

```swift
enum CardKind: String, Sendable, Codable { case legend = "Legend", unit = "Unit", gear = "Gear", program = "Program" }
enum CardColor: String, Sendable, Codable { case blue = "Blue", green = "Green", yellow = "Yellow", red = "Red" }

protocol GameCard: Sendable {
    var data: CardData { get }
    func action(_ event: GameEvent, in context: inout EffectContext)
    func modifiers(in context: EffectQuery) -> CardModifiers
    func playValue(in context: EffectQuery) -> Double?
    func keepValue(in context: EffectQuery) -> Double
}
```

Contraintes (le contrat compte, pas les noms exacts : l'architecte peut renommer s'il a une raison, mais doit garder ces capacités) :

- `CardData` : `key`, `name`, `canonicalName`, `kind`, `color`, `cost`, `power`, `ram`, `isSellable`, `tags` (CARD classifications en minuscules), `rulesText`. Chargée depuis `cards.json`, jamais écrite à la main dans le code d'une carte.
- Chaque carte à effet est un `struct` dédié conforme à `GameCard`, enregistré dans `CardRegistry` par sa `key`. Une carte sans implémentation reçoit `VanillaCard` (données seules, mots-clés lus dans le texte : Blocker, Adrenaline, Go Solo…).
- Les valeurs par défaut (protocol extension) font tout ce qui est générique : mots-clés, valeur de jeu d'un Unit selon puissance/coût, valeur de garde selon type/coût. Une carte ne redéfinit que ce qui la rend particulière.
- `action` reçoit un `GameEvent` (au minimum : `played`, `playedFromHandAsGearEquipped`, `attackDeclared`, `becameSpent`, `defeated`, `calledAsLegend`, `endOfTurn`, `stoleGig`, `wonFight`, `lostFight`, `legendSpentAbility`, `quickActivated`, `programResolves`) et agit via `EffectContext` (voir §5). Les événements concernant les autres cartes (« quand un Unit allié vole… ») sont envoyés à toutes les cartes en jeu concernées.
- `modifiers` regroupe les effets statiques ou continus : puissance, Blocker/Adrenaline/Lag, « ne peut pas attaquer », réduction de coût, bonus de puissance « pendant ton tour », cibles d'attaque autorisées, effets de remplacement (« si ce Unit allait être vaincu… »), restrictions adverses.
- Les capacités activées (Quick, `{Spend}`, `Go Solo`, pouvoir de Légende) sont exposées comme une liste de `ActivatedAbility` (nom, coût en €$, coût en dépense de la carte, condition, effet) pour que l'IA puisse les énumérer comme n'importe quel coup.
- `playValue` / `keepValue` donnent à l'IA l'importance de la carte dans la situation courante (nil = injouable maintenant). Ils remplacent `Valuation.swift` et les tables par comportement.

## 4. Base de cartes

- `Sources/SimCore/Resources/cards.json` (schéma versionné, `schemaVersion: 1`) est la seule source. `CardDatabase.load()` la lit via `Bundle.module`.
- `FetchCards` (exécutable) télécharge `https://api.netdeck.gg/api/cards/cyberpunk?limit=100&offset=…`, normalise exactement comme le fichier actuel (mêmes clés, tri par `canonicalName`) et réécrit `cards.json`. Il vérifie que le nombre de cartes ne diminue pas et affiche les cartes ajoutées/modifiées.
- Le simulateur n'a plus aucun accès réseau, plus d'option `--cards`, plus de cache `~/.cache`.
- Un deck `.txt` du site est résolu par nom (comme aujourd'hui, avec la même normalisation tiret/apostrophe).
- Option `--coverage` du CLI : liste, par couleur et type, les cartes qui ont une implémentation dédiée et celles qui sont `VanillaCard` avec du vrai texte de règles (objectif : 0).

## 5. API pour écrire des effets (`EffectContext` / `GameActions`)

Aucune carte ne touche directement aux tableaux du `Game`. Elle appelle des actions nommées, testables et réutilisables, au minimum :

piocher, défausser (choix de l'IA, du joueur actif ou de l'adversaire), vendre, mettre en défausse, remettre sous le deck (Unit, Gear, cartes), chercher dans le dessus du deck (N cartes, filtre, révélées ou non), ajouter à la main depuis la défausse ou le deck, jouer gratuitement une carte (main, défausse), appeler une Légende (gratuit ou non), vaincre un Unit ou un Gear (avec choix de cible par l'IA : `bestTarget`), dépenser/prêter (ready/spend) un Unit, une Légende ou des Eddies, donner/retirer de la puissance (ce tour, jusqu'au prochain tour), accorder un mot-clé (Blocker, Adrenaline) pour le tour, interdire d'attaquer ou de se prêter jusqu'au prochain tour, ajuster/augmenter/diminuer/fixer/échanger/voler un Gig, forcer une attaque, remplacer une défaite, effets « la prochaine fois que… » (déclencheurs différés à durée limitée), gains d'Eddies, Street Cred (☆), Gigs pairs/impairs/paires/min/max.

Les choix de cible et de mode (« choisir un effet ») sont faits par une fonction de décision unique que l'IA peut spécialiser (par défaut : meilleur gain évalué), jamais en dur dans la carte quand plusieurs options existent.

## 6. Moteur et ordre de jeu

- Les règles (tour, mana, combat, vol de Gigs, Overtime, mulligan, mise en place) restent fidèles à l'implémentation actuelle, qui a été validée sur des replays réels. Toute divergence volontaire doit être décrite dans le README.
- Le moteur reste un `struct Game: Sendable` (valeur copiable : la recherche IA copie l'état en permanence). Aucune allocation de classe par carte et par copie : les cartes sont référencées par identifiant dans le `Game` et résolues via un tableau partagé immuable.
- Performances : les parties doivent rester au moins aussi rapides qu'avant le refactor (mesurer avant/après, tolérance +20 %).

## 7. IA (voir `AI/`)

- Une seule politique `Policy` utilisée par les deux sièges. L'option `--ai greedy|search` change la politique des deux côtés. `--ai versus` n'existe que pour comparer deux politiques entre elles (outil de développement).
- Dans la recherche, le tour adverse simulé est joué avec la même politique à budget réduit (échantillons et profondeur plus petits), pas avec une heuristique différente.
- **Bluff** : action explicite de la politique. Finir son tour en gardant volontairement du mana et des Units prêtes pour représenter un Quick ou un Blocker. L'adversaire (même politique) estime la probabilité d'un Quick à partir des Quick encore possibles dans le deck de l'autre (decks connus) et du mana ouvert, et dissuade ses attaques marginales en conséquence. Le bluff est évalué comme n'importe quel coup par la recherche. Option `--bluff on|off` (défaut : on seulement si un test A/B sur ≥ 5 decks montre qu'il ne dégrade pas le win rate).
- **Défense** : l'évaluation et les coups candidats traitent « ne pas attaquer pour garder un Blocker prêt » comme un vrai choix (valeur défensive d'un Blocker prêt face aux attaquants adverses de la prochaine phase), pas comme un effet de bord.

## 8. Affichage en direct

- `ProgressTracker` : compteurs concurrents (verrou) alimentés par les workers (parties et matchs terminés, victoires par deck, tournois terminés).
- `LiveDashboard` : sur un TTY, réécrit l'écran toutes les 500 ms avec : barre de progression globale (%), temps écoulé, ETA, parties/s, puis un tableau par deck : nom, matchs joués, matchs gagnés, win rate, tournois gagnés (mode tournoi). Hors TTY (redirection vers fichier), une seule ligne d'état toutes les 30 s, sans séquences ANSI. Le rapport final reste identique à l'actuel (texte + `--md`).

## 9. CLI (rétrocompatible)

`DeckSim <deck1.txt> <deck2.txt> [...]` avec `--games`, `--seed`, `--workers`, `--tournaments N`, `--bo N`, `--ai`, `--samples`, `--depth`, `--shortlist`, `--trace`, `--md fichier.md`, plus `--coverage`, `--bluff on|off`, `--opponent-budget N`, `--no-live` (désactive l'affichage en direct). `--cards` est supprimé.

## 10. Règles de code

- Swift 6, `Sendable` partout, types valeur d'abord (enum, struct), aucune classe sauf nécessité.
- Aucun commentaire `//` ni `///` dans le code Swift : les noms et la structure doivent suffire.
- Petites fonctions, noms explicites, un fichier par responsabilité.
- Textes visibles par l'utilisateur en français.
- `swift build -c release` sans avertissement nouveau. Si `swift test` fonctionne, chaque carte codée a au moins un test de son effet principal (scénario construit à la main sur un `Game` minimal).

## 11. Non-régression

Les 5 decks de référence sont dans `Regression/decks/`. Le résultat de l'ancien simulateur est figé dans `Regression/baseline-greedy-seed42.txt` (commande : `DeckSim Regression/decks/*.txt --ai greedy --seed 42 --games 2000`). Après le refactor, la même commande doit redonner les mêmes pourcentages à ±1 point près (idéalement à l'identique si l'ordre d'utilisation du générateur aléatoire est conservé). Les nouvelles cartes codées plus tard peuvent changer les résultats des decks qui les contiennent (c'est le but) mais pas ceux des autres decks.

## 12. Écarts

Écarts au contrat décidés lors du refactor SimCore (tout le reste est conforme) :

- **Protocole `GameCard`** : en plus de `data`, `action`, `modifiers`, `playValue` et `keepValue`, il demande `init(data:)` (le registre construit la carte), `listens: EventMask` (obligatoire : seuls ces événements sont envoyés, pour garder la boucle chaude rapide), et propose avec valeurs par défaut `keywords`, `modifierScopes` (portées interrogées par le moteur), `abilities` / `abilityOptions` / `activate` (capacités activées), `hints: AIHints` (indices statiques pour l'IA) et `attackValueBonus`.
- **Événements** : `playedFromHandAsGearEquipped` est `.played` avec une location `.gear(host:)` ; `stoleGig` est séparé en `.stoleGigs` (l'attaque) et `.gigStolen` (chaque Gig) ; `legendSpentAbility` n'est pas un événement mais une `ActivatedAbility` ; ajouts : `.blocked`, `.wouldBeDefeated` et `.gigWouldBeStolen` (remplacements), `.turnStarted`, `.gigRolled`, `.gigsAlteredByRival`. La relation de la carte qui reçoit (`itself`, `attachedTo`, `ally`, `delayed`) est dans `EffectContext.relation`.
- **`EffectContext`** contient le `Game` (échangé avec un `Game` vide le temps de l'appel, sans copie des tableaux) et `EffectQuery` une copie en lecture ; `GameReading` regroupe les lectures communes, `GameActions` les actions.
- **IA** : la politique est `Policy` (recherche ou glouton + `SearchConfig`). L'adversaire simulé ne joue que le premier tour adverse de chaque approfondissement, en choisissant entre plans de tour complets (budget réglable par `--opponent-budget`), pour tenir le coût sous 2,5×. `--bluff` vaut `off` par défaut (A/B non concluant). `--ai greedy` utilise l'heuristique modernisée ; la référence §11 se reproduit avec `--ai greedy --ai-old all`. Outils de dev ajoutés : `--ai-old b|all`, `--bluff-ab`.
- **Performances** : chaque tâche de simulation travaille sur sa propre copie du catalogue (`CardCatalog.isolatedCopy()`), pour éviter que les compteurs de références partagés entre cœurs ne ralentissent le calcul. Les profils statiques des cartes (mots-clés, événements écoutés, portées, capacités) sont calculés une fois par catalogue.
- **`KeywordCard`** (dossier `Generic/`) marque les cartes dont le texte n'est que des mots-clés ; `VanillaCard` reste la valeur par défaut des cartes non enregistrées.
- **Mulligan, Defense** sont dans `AI/Heuristics/` (`Mulligan.swift`, `Defense.swift`, `QuickResponses.swift`) ; `Bluff`, `ProgressTracker`, `LiveDashboard` ne sont pas encore écrits (`--bluff` et `--no-live` sont acceptés et sans effet).
- **Recherche** : les capacités activées sont proposées après les cartes jouables (celles de type `.mainAction`) ou après les attaques ; les identifiants de carte suivent l'ordre de `cards.json`. Les résultats restent statistiquement identiques à l'ancien moteur (qui était déjà non déterministe en mode recherche) et la recherche est environ deux fois plus rapide.
- **Divergences de règles conservées** pour une non-régression exacte : voir la section « Divergences connues » du README.

