public struct CardRegistry: Sendable {
    public typealias Factory = @Sendable (CardData) -> any GameCard

    let factories: [String: Factory]

    public init(factories: [String: Factory]) {
        self.factories = factories
    }

    public func make(_ data: CardData) -> any GameCard {
        factories[data.key]?(data) ?? VanillaCard(data: data)
    }

    public func hasImplementation(forKey key: String) -> Bool {
        factories[key] != nil
    }

    public var keys: [String] { factories.keys.sorted() }

    public static let standard = CardRegistry(factories: blue
        .merging(green) { first, _ in first }
        .merging(red) { first, _ in first }
        .merging(yellow) { first, _ in first }
        .merging(keywordOnly) { first, _ in first })

    static func entry<Card: GameCard>(_ key: String, _ type: Card.Type) -> (String, Factory) {
        (key, { Card(data: $0) })
    }

    static func table(_ entries: [(String, Factory)]) -> [String: Factory] {
        Dictionary(entries, uniquingKeysWith: { first, _ in first })
    }

    static let keywordOnly = table([
        entry("goro-takemura-hands-unclean", KeywordCard.self),
        entry("ruthless-lowlife", KeywordCard.self),
        entry("riding-nomad", KeywordCard.self),
        entry("v-corporate-exile", KeywordCard.self),
    ])

    static let blue = table([
        entry("alt-cunningham-soulkiller-architect", AltCunninghamSoulkillerArchitect.self),
        entry("chrome-reverie", ChromeReverie.self),
        entry("delamain-cab", DelamainCab.self),
        entry("delamain-rideshare-ai", DelamainRideshareAI.self),
        entry("dying-night-v-s-pistol", DyingNightVsPistol.self),
        entry("evelyn-parker-beautiful-enigma", EvelynParkerBeautifulEnigma.self),
        entry("evelyn-parker-scheming-siren", EvelynParkerSchemingSiren.self),
        entry("floor-it", FloorIt.self),
        entry("hacked-corpo", HackedCorpo.self),
        entry("jacked-in-voodoo-boy", JackedInVoodooBoy.self),
        entry("jackie-welles-pour-one-out-for-me", JackieWellesPourOneOutForMe.self),
        entry("judy-lvarez-braindance-maestro", JudyAlvarezBraindanceMaestro.self),
        entry("judy-lvarez-nothing-to-doubt", JudyAlvarezNothingToDoubt.self),
        entry("les-l-mens", LesElemens.self),
        entry("lizzy-wizzy-delicate-weapon", LizzyWizzyDelicateWeapon.self),
        entry("lucyna-kushinada-fresh-beginnings", LucynaKushinadaFreshBeginnings.self),
        entry("maman-brigitte-spirit-of-death", MamanBrigitteSpiritOfDeath.self),
        entry("misty-olszewski-mender-of-broken-spirits", MistyOlszewskiMenderOfBrokenSpirits.self),
        entry("modded-kusanagi", ModdedKusanagi.self),
        entry("modded-muramasa", ModdedMuramasa.self),
        entry("mox-inciters", MoxInciters.self),
        entry("mt0d12-flathead", MT0D12Flathead.self),
        entry("netwatch-netdriver", NetwatchNetdriver.self),
        entry("nocturne-op55-n1", NocturneOP55N1.self),
        entry("placide-voodoo-sentinel", PlacideVoodooSentinel.self),
        entry("pyramid-song", PyramidSong.self),
        entry("reboot-optics", RebootOptics.self),
        entry("rita-wheeler-no-stupid-questions", RitaWheelerNoStupidQuestions.self),
        entry("rogue-amendiares-queen-of-the-afterlife", RogueAmendiaresQueenOfTheAfterlife.self),
        entry("sasha-yakovleva-won-t-let-you-down", SashaYakovlevaWontLetYouDown.self),
        entry("tetratronic-rippler", TetratronicRippler.self),
        entry("three-mouths-one-desire", ThreeMouthsOneDesire.self),
        entry("towerfall", Towerfall.self),
        entry("trust-no-one", TrustNoOne.self),
        entry("unlikely-bond", UnlikelyBond.self),
        entry("wakako-okada-peace-and-harmony", WakakoOkadaPeaceAndHarmony.self),
        entry("westbrook-netrunner", WestbrookNetrunner.self),
    ])

    static let green = table([
        entry("corpo-security", CorpoSecurity.self),
        entry("corporate-surveillance", CorporateSurveillance.self),
        entry("field-operator", FieldOperator.self),
        entry("goro-takemura-losing-his-way", GoroTakemuraLosingHisWay.self),
        entry("hanako-arasaka-daughter-of-the-emperor", HanakoArasakaDaughterOfTheEmperor.self),
        entry("maxtac-av", MaxTacAV.self),
        entry("peace-offering", PeaceOffering.self),
        entry("pepe-najarro-working-doubles", PepeNajarroWorkingDoubles.self),
        entry("saburo-arasaka-stubborn-patriarch", SaburoArasakaStubbornPatriarch.self),
        entry("sandayu-oda-hanako-s-guardian", SandayuOdaHanakosGuardian.self),
        entry("sandevistan", Sandevistan.self),
        entry("saul-bright-stormrider", SaulBrightStormrider.self),
        entry("synapse-burnout", SynapseBurnout.self),
        entry("take-control", TakeControl.self),
        entry("wild-in-the-streets", WildInTheStreets.self),
    ])

    static let red = table([
        entry("6th-street-recruits", SixthStreetRecruits.self),
        entry("adam-smasher-ender-of-legends", AdamSmasherEnderOfLegends.self),
        entry("all-is-lost", AllIsLost.self),
        entry("arasaka-emergency-radioport", ArasakaEmergencyRadioport.self),
        entry("detonate", Detonate.self),
        entry("industrial-assembly", IndustrialAssembly.self),
        entry("johnny-silverhand-never-stop-fighting", JohnnySilverhandNeverStopFighting.self),
        entry("la-llorona-ghost-of-the-past", LaLloronaGhostOfThePast.self),
        entry("mantis-blades", MantisBlades.self),
        entry("meredith-stout-stone-cold-corpo", MeredithStoutStoneColdCorpo.self),
        entry("minotaur", Minotaur.self),
        entry("over-the-edge", OverTheEdge.self),
        entry("royce-psycho-on-the-edge", RoycePsychoOnTheEdge.self),
        entry("satori-sword-of-saburo", SatoriSwordOfSaburo.self),
        entry("screw-lovelorn-fool", ScrewLovelornFool.self),
        entry("swordwise-huscle", SwordwiseHuscle.self),
        entry("v-streetkid", VStreetkid.self),
        entry("valentino-guerrera", ValentinoGuerrera.self),
        entry("yorinobu-arasaka-embracing-destruction", YorinobuArasakaEmbracingDestruction.self),
    ])

    static let yellow = table([
        entry("adam-smasher-metal-over-meat", AdamSmasherMetalOverMeat.self),
        entry("adrenaline-converter", AdrenalineConverter.self),
        entry("afterparty-at-lizzie-s", AfterpartyAtLizzies.self),
        entry("alt-cunningham-mother-of-daemons", AltCunninghamMotherOfDaemons.self),
        entry("augmented-negotiators", AugmentedNegotiators.self),
        entry("bootleg-black-sapphire-show", BootlegBlackSapphireShow.self),
        entry("caliber-totentanz-s-top-dog", CaliberTotentanzsTopDog.self),
        entry("cyberpsychosis", Cyberpsychosis.self),
        entry("dexter-deshawn-one-last-chance", DexterDeShawnOneLastChance.self),
        entry("dum-dum-maelstrom-triggerman", DumDumMaelstromTriggerman.self),
        entry("gilded-mat-n", GildedMaton.self),
        entry("gorilla-arms", GorillaArms.self),
        entry("hanako-arasaka-in-a-gilded-cage", HanakoArasakaInAGildedCage.self),
        entry("heywood-ripperdoc", HeywoodRipperdoc.self),
        entry("jackie-welles-ride-or-die-choom", JackieWellesRideOrDieChoom.self),
        entry("kerry-eurodyne-axe-attitude-audience", KerryEurodyneAxeAttitudeAudience.self),
        entry("kiroshi-optics", KiroshiOptics.self),
        entry("live-with-the-aftermath", LiveWithTheAftermath.self),
        entry("maelstrom-goons", MaelstromGoons.self),
        entry("mandibular-upgrade", MandibularUpgrade.self),
        entry("maxtac-suppression-team", MaxTacSuppressionTeam.self),
        entry("muamar-reyes-el-capit-n", MuamarReyesElCapitan.self),
        entry("offduty-malfini", OffdutyMalfini.self),
        entry("river-ward-detective-on-the-hunt", RiverWardDetectiveOnTheHunt.self),
        entry("rogue-amendiares-preem-solo", RogueAmendiaresPreemSolo.self),
        entry("safety-override", SafetyOverride.self),
        entry("secondhand-bombus", SecondhandBombus.self),
        entry("sketchy-ripper", SketchyRipper.self),
        entry("t-bug-amateur-philosopher", TBugAmateurPhilosopher.self),
        entry("the-heist", TheHeist.self),
        entry("the-relic-experimental-biochip", TheRelicExperimentalBiochip.self),
        entry("trauma-team-operatives", TraumaTeamOperatives.self),
        entry("viktor-vektor-drop-your-illusions", ViktorVektorDropYourIllusions.self),
        entry("viktor-vektor-sit-down-and-relax", ViktorVektorSitDownAndRelax.self),
        entry("viktor-vektor-you-might-feel-a-little-pinch", ViktorVektorYouMightFeelALittlePinch.self),
        entry("zetatech-faceplate", ZetatechFaceplate.self),
    ])
}
