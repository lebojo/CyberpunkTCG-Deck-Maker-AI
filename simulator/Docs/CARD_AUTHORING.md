# Coder une carte dans DeckSim

Ce guide s'adresse aux personnes (et agents) qui ajoutent l'effet d'une carte. Il suffit de lire ce fichier et les quelques sources listées ci-dessous : le moteur ne doit **jamais** être modifié pour coder une carte. Si une carte semble impossible à écrire avec l'API, signalez-le plutôt que de toucher au moteur.

## 1. Fichiers à lire avant de commencer

| Fichier | Pourquoi |
|---|---|
| `Sources/SimCore/Cards/Model/GameCard.swift` | le protocole à implémenter et ses valeurs par défaut |
| `Sources/SimCore/Engine/Effects/GameEvent.swift` | les événements (`GameEvent`, `EventMask`), `CardLocation`, `EventRelation` |
| `Sources/SimCore/Engine/Effects/EffectContext.swift` | `EffectContext` (agir), `EffectQuery` (lire), `QuerySubject` |
| `Sources/SimCore/Engine/Effects/GameActions.swift` | toutes les actions qu'une carte peut faire |
| `Sources/SimCore/Engine/Effects/GameReading.swift` | toutes les lectures de l'état (Gigs, Street Cred, main, terrain…) |
| `Sources/SimCore/Engine/Effects/CardModifiers.swift` | effets continus (`ModifierScopes`, `CardModifiers`) |
| `Sources/SimCore/Engine/Effects/ActivatedAbility.swift` | capacités activées (`ActivatedAbility`, `AbilityTiming`, `AbilityOption`, `FightPreview`) |
| `Sources/SimCore/Cards/Model/Keyword.swift`, `RulesText.swift` | mots-clés lus automatiquement dans le texte |
| `Sources/SimCore/Cards/Model/AIHints.swift` | indices statiques pour l'IA |
| `Sources/SimCore/Cards/Database/CardRegistry.swift` | où enregistrer la carte |
| `Sources/SimCore/Resources/cards.json` | le texte exact, la `key`, le coût, la puissance (ne jamais modifier à la main) |

Lire aussi une ou deux cartes existantes proches de celle à coder dans `Sources/SimCore/Cards/Definitions/<Couleur>/`.

## 2. Les trois étapes

1. **Trouver la carte** : `python3 -I -c "import json; [print(c['key'], c['kind'], c['color'], c['rulesText']) for c in json.load(open('Sources/SimCore/Resources/cards.json'))['cards'] if 'Lizzy' in c['name']]"`. La `key` (slug) est l'identifiant de la carte.
2. **Écrire un `struct`** dans `Sources/SimCore/Cards/Definitions/<Couleur>/<NomEnCamelCase>.swift` (une carte = un fichier, couleur prise dans `cards.json`).
3. **L'enregistrer** dans `CardRegistry.swift`, dans la table de sa couleur : `entry("ma-cle", MaCarte.self),`. Puis `swift build -c release`, `swift test`, `.build/release/DeckSim --coverage`.

Une carte non enregistrée reçoit `VanillaCard` : ses mots-clés de ligne (`{Blocker}`, `{Adrenaline}`, `{Go Solo}`, « This Unit can't attack. »…) fonctionnent déjà, mais tout le reste du texte est ignoré et la carte apparaît « à coder » dans `--coverage`. Une carte dont le texte n'est **que** des mots-clés s'enregistre avec `KeywordCard.self` (exemple : `riding-nomad`).

## 3. Le squelette

```swift
struct MaCarte: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        context.draw(1)
    }
}
```

- `data` est rempli depuis `cards.json` par le registre : n'écrivez jamais le coût, la puissance ou le texte dans le code.
- `listens` est **obligatoire** : c'est la liste des événements que le moteur vous envoie. Un événement absent de `listens` n'arrive jamais à `action` (c'est ce qui garde la simulation rapide).
- Tout le reste a une valeur par défaut (protocol extension) : ne redéfinissez que ce qui rend la carte particulière.
- Règles de code : aucun commentaire `//` ni `///`, Swift 6 (`Sendable`), types valeur, petites fonctions privées aux noms explicites, textes visibles en français (les `note(...)` de trace sont en anglais comme le reste de la trace).

## 4. Les événements (`GameEvent`)

Chaque événement est envoyé à la carte concernée **et** aux autres cartes en jeu du même joueur (Légendes face visible puis Units, dans l'ordre du terrain), puis aux déclencheurs différés. `context.relation` dit comment la carte qui reçoit est liée au sujet de l'événement :

| `relation` | raccourci | sens |
|---|---|---|
| `.itself` | `context.isAboutItself` | la carte qui reçoit **est** le sujet (« ce Unit », « cette Légende ») |
| `.attachedTo` | `context.isAboutHost` | la carte qui reçoit est un Gear équipé sur le sujet (« ce Unit ou cette Légende » écrit sur un Gear) |
| `.ally` | `context.isAboutAlly` | un autre élément allié (« quand un Unit allié… ») |
| `.delayed` | `context.isDelayedTrigger` | l'événement arrive via un déclencheur différé que la carte a enregistré |

**Piège n°1** : pour tout effet « ce Unit / cette carte », commencez par `guard ..., context.isAboutItself`. Sans ce test, la carte réagit aussi quand un autre Unit allié est joué, attaque, est appelé… (ce bogue a été rencontré pendant la migration de Dum Dum).

| Événement | Quand | Reçu par (dans cet ordre) |
|---|---|---|
| `.played(cardId:location:)` | Unit entré en jeu (main, défausse, Go Solo, Relic), Gear équipé, Program joué | alliés puis la carte elle-même (Unit : `.itself` via le terrain ; Gear : en dernier, location `.gear`) ; Program : alliés seulement |
| `.programResolves` | résolution d'un Program joué en phase principale ou gratuitement | le Program seul (location `.resolving`) |
| `.calledAsLegend(slot:)` | une Légende vient d'être appelée (`{Call}`) | la Légende, puis les autres alliés |
| `.attackDeclared(attackerUid:target:)` | après avoir dépensé l'attaquant (`{Attack}`) | l'attaquant, ses Gears, puis les alliés |
| `.blocked(blockerUid:attackerUid:)` | un Unit utilise `{Blocker}` | le bloqueur, ses Gears, puis ses alliés |
| `.becameSpent(location, isEquipped:)` | un Unit ou une Légende est dépensé (attaque, blocage, paiement, effet) | alliés (dont le sujet en `.itself`), puis les Gears du sujet (`.attachedTo`) |
| `.wouldBeDefeated(uid:cause:)` | **remplacement**, avant de vaincre un Unit (`cause` : `.fight(opponentUid:)` ou `.effect`) | le Unit, ses Gears, ses alliés, ses différés ; s'arrête au premier `context.prevent()` |
| `.defeated(DefeatedUnit)` | après qu'un Unit a quitté le terrain (`{Defeated}`) | alliés, Gears (désormais en défausse), puis la carte vaincue (location `.trash`, ou `.removed` pour une Légende en Go Solo) |
| `.gigWouldBeStolen(Gig, attackerUid:)` | **remplacement**, avant chaque Gig volé | le joueur qui va perdre le Gig (ses alliés + différés) ; `context.prevent()` protège le Gig |
| `.stoleGigs(attackerUid:gigs:)` | un Unit vient de voler 1+ Gigs | l'attaquant, ses Gears, ses alliés |
| `.gigStolen(Gig, attackerUid:)` | pour chaque Gig volé (y compris un vol supplémentaire) | alliés du voleur, l'attaquant compris (`.itself`) |
| `.gigsAlteredByRival` | un adversaire a échangé ou fixé un de vos Gigs | vos alliés |
| `.wonFight(FightReport)` / `.lostFight(FightReport)` | issue d'un combat (« perdre » = ne pas gagner, égalité comprise) | le combattant, ses Gears, ses alliés, ses différés |
| `.turnStarted` | début de votre tour, après la pioche | vos Légendes face visible et Units |
| `.endOfTurn` | fin de votre tour | Gears des Units puis des Légendes (`.attachedTo`), puis les défaites programmées, puis Légendes et Units (**`.ally` pour tous** : testez `context.selfUid` / `context.selfLegendSlot`) |
| `.gigRolled(index:)` | un Gig vient d'être lancé depuis le fixer | vos alliés |
| `.quickActivated(cardId:)` | un Program `{Quick}` vient d'être payé | vos alliés |

`FightReport` contient `unitUid`, `opponentUid`, `power`, `opponentPower` (pour « gagne de 3+ »). `DefeatedUnit` contient `cardId`, `gears`, `wasLegend`, `wasEquipped`.

## 5. Lire l'état (`GameReading`, commun à `EffectContext` et `EffectQuery`)

Identité : `owner`, `rival`, `cardId`, `card` (ses `CardData`), `location`, `selfUid`, `selfUnit`, `selfLegendSlot`, `host`, `hostUnit`, `onceKey(n)`.
Tour : `turn`, `isMyTurn`, `programsPlayedThisTurn`, `hasCalledThisTurn`, `availableMana`, `wasUsedThisTurn(key)`.
Zones : `hand(of:)`, `trash(of:)`, `deckCount(of:)`, `field(of:)`, `legends(of:)`, `unit(p, uid)`, `data(id)`, `stats(id)` (`kind`, `color`, `costValue`, `power`, `isSellable`), `effectiveCost(id)`.
Combat : `power(of:owner:attacking:)`, `isBlocker`, `canAttack`, `canStealGigs`, `stealCount(forPower:)`, `fightOpponent`, `fightOwnUnit`.
Gigs : `gigs(of:)`, `streetCred(of:)` (nil sans Gig), `hasMoreStreetCred`, `hasLessStreetCred`, `valuePairs(of:)`, `minGigCount(of:)`, `maxGigCount(of:)`, `distinctGigValues(of:)`, `hasGig(atLeast:of:)`, `hasEvenAndOddGig(of:)`, `evenGigCount(of:)`, `oddGigCount(of:)`, `fixerIsEmpty(of:)`, `wantsMinGigs`.
Légendes : `faceUpLegendCount(of:)`, `allLegendsFaceUp(of:)`.
Choix de l'IA (une seule fonction de décision, à utiliser plutôt qu'un choix en dur) : `bestRivalUnit(where:)` (cible la plus menaçante), `worstRivalUnit(where:)` (la plus faible en puissance), `weakestUnit(of:)`, `bestAllyUnit(where:)`, `bestRivalGear(where:)`, `equipTarget(forGear:)`, `bestGigAdjustment(up:down:)`, `bestGigSwap(margin:)`, `bestMatchingGigSet()`, `keepValue(id)`, `playValue(id, from:)`, `unitThreat`, `gigScore`.
Sujet d'une requête : `subject` (`QuerySubject`), `subjectUnit`, `subjectCardId`, `subjectIsSelf`, `subjectGearCount`.

## 6. Agir (`GameActions`, seulement dans `EffectContext`)

Une carte ne touche jamais aux tableaux du `Game` : elle appelle ces actions (paramètre `p`/`of:` omis = vous).

- Cartes : `draw(n, for:)`, `discardWorst(p)` (l'IA du joueur `p` choisit), `discard(id, from:)`, `discard(atHandIndex:)`, `takeFromHand(id)`, `takeFromTrash(at:)`, `takeLastFromTrash(id)`, `putInTrash(ids)`, `trashTop(n)` (meule), `takeTop(n)` (retire du dessus sans placer), `putOnTop(ids)`, `bottomDeck(ids)` (ordre aléatoire), `addToHand(id, revealed:)` (révélée = connue de l'IA adverse), `searchTop(n, take:, revealed:, where:, preferring:)`, `takeFromDeck(where:)`, `shuffleDeck()`, `sell(id)`, `sellTopOfDeck()`.
- Jouer : `playFromHand(id, free:, equipTo:, newestCopy:)`, `playForFree(id, equipTo:, bottomDeckProgram:)` (carte déjà retirée de sa zone, par exemple de la défausse), `playProgram(id, bottomAfter:)`, `playQuickFromHand(id)` (paie et défausse un `{Quick}`), `putUnitIntoPlay(id)`, `callLegend(slot:free:)`, `firstFaceDownLegend(where:)`.
- Units et Gears : `defeat(p, uid:)`, `defeatAfterFight(p, uid:)` (dans `.lostFight`/`.wonFight`), `defeatGear(GearTarget)`, `moveGear(_:from:to:)`, `bottomDeckUnit(p, uid:)`, `returnUnitToHand(p, uid:)`, `spendUnit`, `readyUnit`, `spendLegend(slot:)`, `readyLegend(slot:)`, `spendSelf()` (Légende, Unit, ou hôte d'un Gear), `readyHost()`, `removeLegendFromGame(slot:)`.
- Puissance et statuts : `addPower(p, uid:, n, .thisTurn | .thisFight | .untilYourNextTurn)`, `grantKeyword(.blocker, to:uid:)` (jusqu'à la fin du tour), `forbidAttackUntilYourNextTurn`, `forbidReadyUntilYourNextTurn`, `forceAttackNextTurn` (l'Unit attaque à la fin du prochain tour de son propriétaire s'il le peut), `defeatAtEndOfTurn`, `markUnit(p, uid:, key:)` / `unitHasMark` (marques remises à zéro à chaque fin de tour : « la première fois chaque tour »).
- Eddies : `payEddies(n)` (Eddies prêts puis Légendes, comme le moteur), `readyEddies(n)`, `discountNext(.program, by:, minimum:)` (« votre prochain Program coûte… », `.legend` pour réduire un Go Solo).
- Gigs : `adjustGigBest(by:)`, `increaseGigBest(by:)`, `decreaseGigBest(by:)`, `setGigToMatchBest()`, `setGig(p, index:, to:)`, `swapGigs(mine:theirs:)`, `takeRivalGig(at:)`, `stealExtraGig(attackerUid:choosing:)`, `rerollGig(p, index:)`.
- Remplacements et réactions : `prevent()`, `reduceSteal(by:)`.
- Une fois par tour : `useOncePerTurn(context.onceKey())` renvoie `true` la première fois puis `false` jusqu'au prochain tour du joueur.
- Différés : `registerDelayed(.lostFight, expiry: .endOfTurn | .untilYourNextTurn, charges:, payload:)`, puis dans `action` : `context.isDelayedTrigger`, `context.delayedPayload`, `context.consumeDelayedTrigger()`.
- Choix de mode (« Choose one effect », « a Rival chooses ») : `context.chooseMode(nombre, chooser: p) { mode, branche in ... }` joue chaque mode sur une copie, garde celui que l'IA du `chooser` évalue le mieux, puis l'applique pour de vrai. Ne codez pas le choix en dur quand plusieurs options existent.
- Trace : `context.note("P\(context.owner) ...")` (anglais, comme le reste de la trace).

## 7. Effets continus (`modifiers`)

Déclarez la portée dans `modifierScopes` et renvoyez un `CardModifiers` (`.none` quand rien ne s'applique). Le moteur ne vous appelle que pour les portées déclarées.

| Portée | Le moteur demande | Sujet (`query.subject`) |
|---|---|---|
| `.itself` | votre propre puissance / mots-clés (Unit sur le terrain ou Légende pour le Go Solo) | `.unit` ou `.legend` (testez `query.subjectIsSelf`) |
| `.equippedUnit` | (Gear) l'Unit qui vous porte | `.unit` de l'hôte |
| `.alliedUnits` | chaque Unit allié, tout le temps | `.unit` |
| `.alliedAttackers` | chaque Unit allié **quand il attaque** (« while attacking ») | `.unit`, `query.attacking == true` |
| `.rivalUnits` | chaque Unit adverse | `.unit` |
| `.ownPlayCost` | votre coût quand vous êtes en main (`costOverride`, `costReduction`, `costMinimum`) | `.card(votre id)` |
| `.alliedPlayCost` | le coût des cartes que votre propriétaire joue (`costOncePerTurnKey` pour « la première … chaque tour ») | `.card(id joué)` |
| `.fight` | votre combat : `fightPower` (« +2 en combattant une Légende »), `winsFight` | `.fight(ownUid:otherUid:)`, voir `query.fightOpponent` |
| `.goSoloCost` | le coût de Go Solo de n'importe quelle Légende (`goSoloCostChange`) | `.legend(owner:slot:)` |

Champs de `CardModifiers` : `power`, `keywords` (`.blocker`, `.adrenaline`, `.cannotAttack`, `.cannotStealGigs`, `.unblockable`, `.canAttackReadyUnits`, `.canAttackReadyBlockers`, `.attacksUnitsWhenPlayed`, `.attacksGigsWhenPlayed`), `fightPower`, `winsFight`, `costOverride`, `costReduction`, `costMinimum`, `costOncePerTurnKey`, `goSoloCostChange`. Une fonction `modifiers` ne doit pas appeler `power(...)` (récursion) : elle lit l'état simple (Gigs, Street Cred, flags).

## 8. Capacités activées (`abilities`)

Pour `{Quick}`, `{Spend}`, « 1 €$, {Spend} », pouvoirs de Légende et réactions, déclarez des `ActivatedAbility(index:name:timing:eddieCost:spendsSource:)` et implémentez :

- `abilityOptions(_:in:)` : les façons de l'utiliser maintenant (`[]` = inutilisable). Chaque `AbilityOption` porte `target` (`.card`, `.unit`, `.gig`, `.mode`), `value` (pour `.mainAction`, comparée aux autres coups ; 5 = seuil minimum), `eddieCost`, `fight` (`FightPreview` pour les combats) ou `stealReduction`.
- `activate(_:in:)` : applique l'effet **et paie** (`payEddies`, `spendSelf`/`spendLegend`, `playQuickFromHand`) ; renvoie `true` si quelque chose s'est produit.

Le moteur ne vérifie que la disponibilité de la source (Légende face visible, et prête si `spendsSource`; Unit prêt ; Gear dont l'hôte est prêt ; carte en main).

| `timing` | Utilisée par l'IA |
|---|---|
| `.mainAction` | comme un coup de la phase principale, au mieux de `value` (River Ward, `{Spend}` d'un Unit ou d'une Légende) |
| `.beforeAttacks` | une fois, avant les attaques (Hanako) |
| `.endOfMainPhase` | une fois, à la fin de la phase principale (Alt Soulkiller : rejouer un Program) |
| `.beforePlayingCard` | juste avant de jouer une carte, sujet `.card(id)` (Alt Soulkiller : réduction) |
| `.beforeAttack` | juste avant qu'un allié attaque, sujet `.attack(owner:uid:)` (Dum Dum, Cyberpsychosis) |
| `.fight` | pendant un combat, chaque camp à tour de rôle tant que cela change l'issue ; donnez `fight: .power(own:other:)` ou `.retaliation` |
| `.rivalAttacksGigs` | en réaction à une attaque adverse sur vos Gigs, sujet `.attack` ; donnez `stealReduction` (Take Control) |

## 9. Valeurs pour l'IA

- `playValue(in:)` : intérêt de jouer la carte maintenant (`nil` = ne pas la jouer). Par défaut : Unit `20 + 1,2×puissance + 1,5×coût (+4 si tour ≤ 8 et coût ≤ 3)`, Gear `24 + 2×puissance` s'il existe une cible d'équipement, Program `8`. Pour ajuster : `standardPlayValue(in: query).map { $0 + 6 }`. Un Program qui ne doit être joué qu'en réaction (Quick pur) renvoie `nil`.
- `keepValue(in:)` : intérêt de garder la carte en main (vente, défausse). Par défaut : Unit `14 + 0,8×coût`, Gear `8 + puissance (−2 sans Unit)`, Program `min(playValue/2, 14)` ou `4`.
- `attackValueBonus(in:)` : bonus quand l'IA envisage d'attaquer les Gigs avec ce Unit.
- `hints` (`AIHints`) : `threatBonus`, `gearRemovalPriority`, `prefersNoGears`, `extraPowerPerGear`, `carriesGearsAsLegend`, `suitsFaceUpLegend`, `manaReluctance` (coût de dépenser cette Légende comme mana), `rewardsBeingSpent`, `goSoloBonus`, `ignoresExposure`, `attackWithoutStealValue`.

## 10. Exemples tirés des cartes migrées

### Unit avec `{Play}` : Minotaur (`Red/Minotaur.swift`)

```swift
struct Minotaur: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, context.hasMoreStreetCred else { return }
        let rival = context.rival
        if let target = context.bestRivalUnit(where: { context.power(of: $0, owner: rival) <= 5 }) {
            context.defeat(rival, uid: target.uid)
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        let hasTarget = query.hasMoreStreetCred && query.field(of: rival).contains { query.power(of: $0, owner: rival) <= 5 }
        return standardPlayValue(in: query).map { $0 + (hasTarget ? 12 : 0) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 4
    }
}
```

### Gear « quand ce Unit ou cette Légende est dépensé » : Zetatech Faceplate (`Yellow/ZetatechFaceplate.swift`)

```swift
struct ZetatechFaceplate: GameCard {
    let data: CardData
    let listens: EventMask = .becameSpent

    var hints: AIHints {
        .with {
            $0.rewardsBeingSpent = true
            $0.suitsFaceUpLegend = true
            $0.gearRemovalPriority = 4
        }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .becameSpent = event, context.isAboutHost else { return }
        context.adjustGigBest(by: 1)
        if context.distinctGigValues() >= 3 && context.gigs().count >= 3 { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }
}
```

### Program `{Quick}` : Floor It (`Blue/FloorIt.swift`)

Joué en phase principale via `.programResolves`, ou en combat via sa capacité `.fight`.

```swift
struct FloorIt: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Floor It", timing: .fight, spendsSource: false)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        if let target = context.bestRivalUnit() {
            context.addPower(context.rival, uid: target.uid, -1)
        }
        context.draw(1)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = query.effectiveCost(query.cardId)
        guard cost <= query.availableMana, let opponent = query.fightOpponent else { return [] }
        return [AbilityOption(ability: 0, target: .unit(owner: query.rival, uid: opponent.uid), eddieCost: cost, fight: .power(own: 0, other: -1))]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let opponentOwner, let uid) = option.target, context.unit(opponentOwner, uid) != nil else { return false }
        guard context.playQuickFromHand(context.cardId) else { return false }
        context.addPower(opponentOwner, uid: uid, -1)
        context.draw(1)
        return true
    }

    func playValue(in query: EffectQuery) -> Double? {
        query.field(of: query.rival).isEmpty ? nil : 10
    }

    func keepValue(in query: EffectQuery) -> Double { 10 }
}
```

### Légende avec `{Call}` et pouvoir `{Quick} 1 €$, {Spend}` : Dum Dum (`Yellow/DumDumMaelstromTriggerman.swift`)

```swift
struct DumDumMaelstromTriggerman: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    static let pumpBeforeAttack = 0
    static let pumpInFight = 1

    var abilities: [ActivatedAbility] {
        [
            ActivatedAbility(index: Self.pumpBeforeAttack, name: "Dum Dum : +1 par Gear avant l'attaque", timing: .beforeAttack, eddieCost: 1),
            ActivatedAbility(index: Self.pumpInFight, name: "Dum Dum : +1 par Gear en combat", timing: .fight, eddieCost: 1),
        ]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        context.draw(defeatLowGear(&context) ? 2 : 1)
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let unitOwner, let uid) = option.target, let target = context.unit(unitOwner, uid), let slot = context.selfLegendSlot else { return false }
        let bonus = target.gears.count
        guard context.payEddies(1) else { return false }
        if option.ability == Self.pumpBeforeAttack || !context.legends()[slot].spent {
            context.spendLegend(slot: slot)
        }
        context.addPower(unitOwner, uid: uid, bonus)
        return true
    }
}
```

(`defeatLowGear` et `abilityOptions` sont dans le fichier complet.) Pour un pouvoir `{Spend}` de phase principale, voir River Ward (`timing: .mainAction`, une option par Gear jouable avec `value`).

### Effet continu : Saburo Arasaka (`Green/SaburoArasakaStubbornPatriarch.swift`)

```swift
struct SaburoArasakaStubbornPatriarch: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .alliedAttackers }
    var hints: AIHints { .with { $0.manaReluctance = 3 } }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard let subject = query.subjectCardId, query.data(subject).has(.arasaka) else { return .none }
        return .with { $0.power = 1 }
    }
}
```

Autres exemples continus : Royce (`.itself`, puissance pendant votre tour), Adrenaline Converter (`.equippedUnit`, mot-clé conditionnel), Viktor Vektor — Drop Your Illusions (`.alliedPlayCost`), Nocturne (`.ownPlayCost`), Meredith Stout (`.fight`).

### Déclencheur différé « la prochaine fois que… » : Safety Override (`Yellow/SafetyOverride.swift`)

```swift
struct SafetyOverride: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Safety Override", timing: .fight, spendsSource: false)]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = query.effectiveCost(query.cardId)
        guard cost <= query.availableMana, !query.hasDelayedTrigger() else { return [] }
        return [AbilityOption(ability: 0, eddieCost: cost, fight: .retaliation)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard context.playQuickFromHand(context.cardId) else { return false }
        armRetaliation(&context)
        return true
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .programResolves:
            armRetaliation(&context)
        case .lostFight(let report) where context.isDelayedTrigger:
            context.defeatAfterFight(context.rival, uid: report.opponentUid)
            context.consumeDelayedTrigger()
        default:
            break
        }
    }

    private func armRetaliation(_ context: inout EffectContext) {
        context.registerDelayed(.lostFight, expiry: .untilYourNextTurn)
    }

    func playValue(in query: EffectQuery) -> Double? { nil }

    func keepValue(in query: EffectQuery) -> Double { 9 }
}
```

Un déclencheur différé reçoit l'événement même s'il n'est pas dans `listens` ; `.endOfTurn` expire à la fin du tour courant, `.untilYourNextTurn` au début de votre prochain tour.

### Remplacement et choix de mode (cartes de test, `Tests/SimCoreTests/EffectAPITests.swift`)

```swift
struct DeathWardTestCard: GameCard {
    let data: CardData
    let listens: EventMask = .wouldBeDefeated

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .wouldBeDefeated = event, context.isAboutItself, context.useOncePerTurn(context.onceKey()) else { return }
        context.prevent()
    }
}

struct ModeTestCard: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        _ = context.chooseMode(2) { mode, branch in
            if mode == 0 { branch.draw(2) } else { branch.readyEddies(1) }
        }
    }
}
```

## 11. Recettes rapides

| Texte | Recette |
|---|---|
| `{Play} …` | `listens: .played`, `guard case .played = event, context.isAboutItself` |
| `{Attack} …` | `listens: .attackDeclared`, `isAboutItself` ; sur un Gear : `isAboutHost` |
| `{Defeated} …` | `listens: .defeated`, `isAboutItself` (la carte est déjà en défausse) |
| « When this Unit uses {Blocker} » | `.blocked`, `isAboutItself` ; « when a friendly Unit uses {Blocker} » : `.blocked`, `isAboutAlly` |
| « The first time … each turn » | `context.useOncePerTurn(context.onceKey())` (par joueur) ou `markUnit`/`unitHasMark` (par Unit) |
| « At the end of your turn, if this Unit stole a Gig this turn » | marquer le Unit dans `.stoleGigs` (`markUnit`), tester la marque dans `.endOfTurn` |
| « If this Unit would be defeated, … instead » | `.wouldBeDefeated` + `context.prevent()` + l'effet de remplacement |
| « can't be defeated in a fight this turn » | `registerDelayed(.wouldBeDefeated, expiry: .endOfTurn, payload: uid)` puis `prevent()` si `cause` est `.fight` et l'uid correspond |
| « Rival Units can't steal Gigs with value … until your next turn » | `registerDelayed(.gigWouldBeStolen, expiry: .untilYourNextTurn)` puis `prevent()` |
| « Play this … for −1 €$ for each … » | `.ownPlayCost`, `costReduction`, `costMinimum = 1` |
| « Choose one effect » | `context.chooseMode(n) { mode, branch in … }` |
| « A Rival chooses » | `context.chooseMode(n, chooser: context.rival) { … }` |
| « A rival Unit must attack next turn if it can » | `context.forceAttackNextTurn(context.rival, uid:)` |
| « … can attack ready Units this turn » | `context.grantKeyword(.canAttackReadyUnits, to:uid:)` |
| `{Go Solo}`, `{Blocker}`, `{Adrenaline}` en début de ligne | rien à faire : lus dans le texte |

## 12. Vérifier

1. `swift build -c release` sans avertissement, `swift test` vert (ajoutez un test de l'effet principal dans `Tests/SimCoreTests/`, voir `CardEffectTests.swift` et les aides de `TestSupport.swift` : `Fixtures.game`, `place`, `give`, `setGigs`, `faceUp`).
2. `.build/release/DeckSim --coverage` : la carte passe de « à coder » à « dédiée ».
3. Non-régression : depuis `Regression/decks/`, `../../.build/release/DeckSim Meta1_*.txt Meta2_*.txt Meta3_*.txt Maelstrom_Gear_Rush_40.txt Maelstrom_Gear_Rush_Meredith_C.txt --ai greedy --seed 42 --games 2000` doit redonner `Regression/baseline-greedy-seed42.txt` à l'identique (hors durée) pour les duels entre decks qui ne contiennent pas la carte.
4. `--trace --seed N` sur un deck qui la joue pour relire une partie.
