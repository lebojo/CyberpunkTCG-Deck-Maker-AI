enum SearchAction: Sendable, Hashable {
    case sell(Int)
    case call
    case play(Int, EquipTarget?)
    case ability(AbilityUse)
    case goSolo(Int)
    case attack(Int, AttackTarget)
    case endTurn
}

public struct SearchConfig: Sendable {
    public var samples = 3
    public var depth = 3
    public var shortlist = 4

    public init(samples: Int = 3, depth: Int = 3, shortlist: Int = 4) {
        self.samples = samples
        self.depth = depth
        self.shortlist = shortlist
    }
}

extension Game {
    func gigValue(_ count: Int) -> Double {
        let table: [Double] = [0, 35, 75, 120, 170, 230, 320, 2000]
        return table[min(count, 7)]
    }

    func evaluate(_ me: Int) -> Double {
        switch outcome {
        case .win(let player, _): return player == me ? 1_000_000 : -1_000_000
        case .draw: return 0
        case .ongoing: break
        }
        let rival = 1 - me
        var score = gigValue(players[me].gigs.count) - gigValue(players[rival].gigs.count)
        if players[me].gigs.count >= 7 { score += 100_000 }
        if players[rival].gigs.count >= 7 { score -= 100_000 }
        let myBoard = players[me].field.reduce(0.0) { $0 + unitThreat(me, $1) }
        let rivalBoard = players[rival].field.reduce(0.0) { $0 + unitThreat(rival, $1) }
        score += myBoard - rivalBoard
        score += Double(players[me].hand.count - players[rival].hand.count) * 5
        let myEddies = players[me].eddiesReady + players[me].eddiesSpent
        let rivalEddies = players[rival].eddiesReady + players[rival].eddiesSpent
        score += Double(myEddies - rivalEddies) * 7
        let myFaceUp = players[me].legends.filter { $0.faceUp }.count + players[me].field.filter { $0.isLegend }.count
        let rivalFaceUp = players[rival].legends.filter { $0.faceUp }.count + players[rival].field.filter { $0.isLegend }.count
        score += Double(myFaceUp - rivalFaceUp) * 4
        return score
    }

    mutating func determinizedWorld(for me: Int) -> Game {
        var world = self
        world.rng = SplitMix64(seed: rng.next())
        world.searchPlayers = SidePair(false, false)
        world.tracing = false
        world.players[me].deck.shuffle(using: &world.rng)
        let rival = 1 - me
        let known = knownHandCards(of: rival)
        var pool = world.players[rival].hand + world.players[rival].deck
        for id in known { if let position = pool.firstIndex(of: id) { pool.remove(at: position) } }
        pool.shuffle(using: &world.rng)
        let handCount = world.players[rival].hand.count
        world.players[rival].hand = known + Array(pool.prefix(handCount - known.count))
        world.players[rival].deck = Array(pool.dropFirst(handCount - known.count))
        for side in 0..<2 {
            let hidden = world.players[side].legends.indices.filter { !world.players[side].legends[$0].faceUp }
            var identities = hidden.map { world.players[side].legends[$0].cardId }
            identities.shuffle(using: &world.rng)
            for (offset, slot) in hidden.enumerated() {
                world.players[side].legends[slot] = LegendSlot(cardId: identities[offset], faceUp: false, spent: world.players[side].legends[slot].spent, gears: world.players[side].legends[slot].gears)
            }
        }
        return world
    }

    func candidateActions(_ p: Int) -> [SearchAction] {
        var actions: [SearchAction] = [.endTurn]
        let player = players[p]
        let mana = availableMana(p)
        let totalEddies = player.eddiesReady + player.eddiesSpent

        if !player.flags.sold, player.hand.count >= 2, totalEddies < 8 {
            let sellable = Set(player.hand.filter { stats($0).isSellable && stats($0).kind != .legend })
            for id in sellable.sorted(by: { keepValue(p, $0) < keepValue(p, $1) }).prefix(3) { actions.append(.sell(id)) }
        }
        if !player.flags.called, mana >= 1, player.legends.contains(where: { !$0.faceUp }) { actions.append(.call) }

        for id in Set(player.hand).sorted() {
            guard effectiveCost(p, id) <= mana else { continue }
            switch stats(id).kind {
            case .unit:
                actions.append(.play(id, nil))
            case .gear:
                for option in equipTargets(p, gear: id).prefix(3) { actions.append(.play(id, option.target)) }
            case .program:
                if playValue(p, id) != nil { actions.append(.play(id, nil)) }
            case .legend:
                break
            }
        }
        actions.append(contentsOf: distinctAbilityActions(p, timing: .mainAction))
        for slot in player.legends.indices where goSoloValue(p, slot: slot) != nil { actions.append(.goSolo(slot)) }
        for attacker in attackersAvailable(p) {
            let attackerPower = power(p, attacker, attacking: true)
            if canStealGigs(p, attacker) { actions.append(.attack(attacker.uid, .gigs)) }
            for target in validUnitTargets(p, attacker) where attackerPower >= power(1 - p, target, attacking: false) && attackerPower > 0 {
                actions.append(.attack(attacker.uid, .unit(target.uid)))
            }
        }
        actions.append(contentsOf: distinctAbilityActions(p, timing: .beforeAttacks))
        actions.append(contentsOf: distinctAbilityActions(p, timing: .endOfMainPhase))
        return actions
    }

    func distinctAbilityActions(_ p: Int, timing: AbilityTiming) -> [SearchAction] {
        var kept: [AbilityUse] = []
        for use in abilityUses(p, timing: timing).sorted(by: { targetOrder($0.option.target) < targetOrder($1.option.target) })
        where !kept.contains(where: { $0.source == use.source && $0.option.ability == use.option.ability && $0.option.target == use.option.target }) {
            kept.append(use)
        }
        return kept.map(SearchAction.ability)
    }

    func targetOrder(_ target: AbilityTarget) -> Int {
        if case .card(let id) = target { return id }
        return -1
    }

    mutating func apply(_ action: SearchAction, _ p: Int) -> Bool {
        switch action {
        case .endTurn:
            return true
        case .sell(let id):
            guard !players[p].flags.sold, let index = players[p].hand.firstIndex(of: id) else { return false }
            sellFromHand(p, handIndex: index)
            return true
        case .call:
            guard !players[p].flags.called, availableMana(p) >= 1,
                  let slot = players[p].legends.firstIndex(where: { !$0.faceUp }) else { return false }
            callLegend(p, slot, free: false)
            return players[p].flags.called
        case .play(let id, let equip):
            guard players[p].hand.contains(id) else { return false }
            prepareToPlay(p, id)
            guard let index = players[p].hand.firstIndex(of: id) else { return false }
            return playFromHand(p, handIndex: index, equipTo: equip)
        case .ability(let use):
            return activate(p, use)
        case .goSolo(let slot):
            let before = players[p].field.count
            goSolo(p, slot: slot)
            return players[p].field.count > before
        case .attack(let uid, let target):
            guard let index = unitIndex(p, uid), canAttackAtAll(p, players[p].field[index]) else { return false }
            if case .unit(let targetUid) = target {
                guard validUnitTargets(p, players[p].field[index]).contains(where: { $0.uid == targetUid }) else { return false }
            }
            prepareAttack(p, uid: uid)
            performAttack(p, attackerUid: uid, target: target)
            return true
        }
    }

    func variants(of action: SearchAction, in world: Game, for p: Int) -> [Game] {
        var branch = world
        guard branch.apply(action, p), !branch.isOver || action != .endTurn else { return [] }
        var stopped = branch
        stopped.finishTurn(p)
        var results = [stopped]
        if action != .endTurn {
            var continued = branch
            continued.greedyMainPhase(p)
            continued.finishTurn(p)
            results.append(continued)
        }
        return results
    }

    func deepValue(_ game: Game, for p: Int, depth: Int) -> Double {
        var future = game
        var weightedSum = 0.0
        var weightTotal = 0.0
        var weight = 1.0
        for _ in 0..<depth {
            if !future.isOver { future.playTurn() }
            weightedSum += future.evaluate(p) * weight
            weightTotal += weight
            if future.isOver { break }
            weight *= 0.7
        }
        return weightedSum / weightTotal
    }

    mutating func searchMainPhase(_ p: Int) {
        let config = searchConfig
        var steps = 0
        while steps < 18, !isOver {
            steps += 1
            let actions = candidateActions(p)
            guard actions.count > 1 else { return }
            var worlds: [Game] = []
            for _ in 0..<config.samples { worlds.append(determinizedWorld(for: p)) }
            var quick = [Double](repeating: 0, count: actions.count)
            var valid = [Int](repeating: 0, count: actions.count)
            for world in worlds {
                for (index, action) in actions.enumerated() {
                    guard let top = variants(of: action, in: world, for: p).map({ $0.evaluate(p) }).max() else { continue }
                    quick[index] += top
                    valid[index] += 1
                }
            }
            let ranked = actions.indices.filter { valid[$0] > 0 }
                .sorted { quick[$0] / Double(valid[$0]) > quick[$1] / Double(valid[$1]) }
            var shortlist = Array(ranked.prefix(config.shortlist))
            if let endIndex = actions.firstIndex(of: .endTurn), valid[endIndex] > 0, !shortlist.contains(endIndex) {
                shortlist.append(endIndex)
            }
            var best: (index: Int, value: Double)?
            for index in shortlist {
                var total = 0.0
                for world in worlds {
                    let values = variants(of: actions[index], in: world, for: p).map { deepValue($0, for: p, depth: config.depth) }
                    total += values.max() ?? -1_000_000
                }
                let value = total / Double(worlds.count) + quick[index] / Double(valid[index]) * 0.001
                if value > (best?.value ?? -Double.infinity) { best = (index, value) }
            }
            guard let choice = best, actions[choice.index] != .endTurn else { return }
            if !apply(actions[choice.index], p) { return }
        }
    }

    mutating func finishTurn(_ p: Int) {
        if !isOver { endTurn(p) }
    }
}
