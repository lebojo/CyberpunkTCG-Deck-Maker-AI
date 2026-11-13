public enum AbilitySource: Sendable, Hashable {
    case legend(slot: Int)
    case field(uid: Int)
    case hand(cardId: Int)
    case gear(host: EquipTarget, cardId: Int)

    var location: CardLocation {
        switch self {
        case .legend(let slot): return .legend(slot: slot)
        case .field(let uid): return .field(uid: uid)
        case .hand: return .hand
        case .gear(let host, _): return .gear(host: host)
        }
    }
}

public struct AbilityUse: Sendable, Hashable {
    public let source: AbilitySource
    public let cardId: Int
    public let option: AbilityOption
}

enum AbilityZone {
    case legends
    case field
    case gears
    case hand
}

extension Game {
    static let quickZones: [AbilityZone] = [.hand, .legends, .field, .gears]
    static let attackZones: [AbilityZone] = [.legends, .hand, .field, .gears]
    static let defaultZones: [AbilityZone] = [.legends, .field, .gears, .hand]

    func zones(for timing: AbilityTiming) -> [AbilityZone] {
        switch timing {
        case .fight, .rivalAttacksGigs: return Game.quickZones
        case .beforeAttack: return Game.attackZones
        default: return Game.defaultZones
        }
    }

    func abilityHolders(_ p: Int, timing: AbilityTiming) -> [(source: AbilitySource, cardId: Int, ability: ActivatedAbility)] {
        var holders: [(source: AbilitySource, cardId: Int, ability: ActivatedAbility)] = []
        guard abilityTimingsInPlay.contains(timing) else { return holders }
        for zone in zones(for: timing) {
            switch zone {
            case .legends:
                for (slot, legend) in players[p].legends.enumerated() where legend.faceUp {
                    for ability in catalog.abilities[legend.cardId] where profile(legend.cardId).abilityTimings.contains(timing) && ability.timing == timing && (!ability.spendsSource || !legend.spent) {
                        holders.append((.legend(slot: slot), legend.cardId, ability))
                    }
                }
            case .field:
                for unit in players[p].field {
                    for ability in catalog.abilities[unit.cardId] where profile(unit.cardId).abilityTimings.contains(timing) && ability.timing == timing && (!ability.spendsSource || !unit.spent) {
                        holders.append((.field(uid: unit.uid), unit.cardId, ability))
                    }
                }
            case .gears:
                for unit in players[p].field {
                    for gear in unit.gears where profile(gear).abilityTimings.contains(timing) {
                        for ability in catalog.abilities[gear] where ability.timing == timing && (!ability.spendsSource || !unit.spent) {
                            holders.append((.gear(host: .unit(unit.uid), cardId: gear), gear, ability))
                        }
                    }
                }
                for (slot, legend) in players[p].legends.enumerated() where legend.faceUp {
                    for gear in legend.gears where profile(gear).abilityTimings.contains(timing) {
                        for ability in catalog.abilities[gear] where ability.timing == timing && (!ability.spendsSource || !legend.spent) {
                            holders.append((.gear(host: .legend(slot), cardId: gear), gear, ability))
                        }
                    }
                }
            case .hand:
                var seen: [Int] = []
                for id in players[p].hand where profile(id).abilityTimings.contains(timing) && !seen.contains(id) {
                    seen.append(id)
                    for ability in catalog.abilities[id] where ability.timing == timing {
                        holders.append((.hand(cardId: id), id, ability))
                    }
                }
            }
        }
        return holders
    }

    func abilityUses(_ p: Int, timing: AbilityTiming, subject: QuerySubject = .none) -> [AbilityUse] {
        var uses: [AbilityUse] = []
        for holder in abilityHolders(p, timing: timing) {
            let options = implementation(holder.cardId).abilityOptions(holder.ability, in: query(holder.cardId, owner: p, at: holder.source.location, subject: subject))
            uses.append(contentsOf: options.map { AbilityUse(source: holder.source, cardId: holder.cardId, option: $0) })
        }
        return uses
    }

    func firstAbilityUse(_ p: Int, timing: AbilityTiming, subject: QuerySubject = .none) -> AbilityUse? {
        for holder in abilityHolders(p, timing: timing) {
            let options = implementation(holder.cardId).abilityOptions(holder.ability, in: query(holder.cardId, owner: p, at: holder.source.location, subject: subject))
            if let first = options.first { return AbilityUse(source: holder.source, cardId: holder.cardId, option: first) }
        }
        return nil
    }

    func sourceIsAvailable(_ p: Int, _ use: AbilityUse) -> Bool {
        switch use.source {
        case .legend(let slot):
            guard players[p].legends.indices.contains(slot) else { return false }
            let legend = players[p].legends[slot]
            return legend.cardId == use.cardId && legend.faceUp
        case .field(let uid):
            return unit(p, uid)?.cardId == use.cardId
        case .hand(let id):
            return players[p].hand.contains(id)
        case .gear(let host, let id):
            return gears(p, on: host).contains(id)
        }
    }

    @discardableResult
    mutating func activate(_ p: Int, _ use: AbilityUse, subject: QuerySubject = .none) -> Bool {
        guard sourceIsAvailable(p, use) else { return false }
        let card = implementation(use.cardId)
        return withContext(use.cardId, owner: p, at: use.source.location, subject: subject) { context in
            card.activate(use.option, in: &context)
        }
    }

    mutating func useAbilities(_ p: Int, timing: AbilityTiming, subject: QuerySubject = .none) {
        for holder in abilityHolders(p, timing: timing) {
            guard !isOver else { return }
            let options = implementation(holder.cardId).abilityOptions(holder.ability, in: query(holder.cardId, owner: p, at: holder.source.location, subject: subject))
            guard let first = options.first else { continue }
            activate(p, AbilityUse(source: holder.source, cardId: holder.cardId, option: first), subject: subject)
        }
    }
}
