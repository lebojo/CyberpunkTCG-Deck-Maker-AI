public protocol GameCard: Sendable {
    init(data: CardData)
    var data: CardData { get }
    var listens: EventMask { get }
    var keywords: Keyword { get }
    var modifierScopes: ModifierScopes { get }
    var abilities: [ActivatedAbility] { get }
    var hints: AIHints { get }
    func action(_ event: GameEvent, in context: inout EffectContext)
    func modifiers(in query: EffectQuery) -> CardModifiers
    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption]
    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool
    func playValue(in query: EffectQuery) -> Double?
    func keepValue(in query: EffectQuery) -> Double
    func attackValueBonus(in query: EffectQuery) -> Double
}

public extension GameCard {
    var keywords: Keyword { RulesText.keywords(data.rulesText) }
    var modifierScopes: ModifierScopes { [] }
    var abilities: [ActivatedAbility] { [] }
    var hints: AIHints { AIHints() }

    func action(_ event: GameEvent, in context: inout EffectContext) {}

    func modifiers(in query: EffectQuery) -> CardModifiers { CardModifiers() }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] { [] }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool { false }

    func playValue(in query: EffectQuery) -> Double? { standardPlayValue(in: query) }

    func keepValue(in query: EffectQuery) -> Double { standardKeepValue(in: query) }

    func attackValueBonus(in query: EffectQuery) -> Double { 0 }
}
