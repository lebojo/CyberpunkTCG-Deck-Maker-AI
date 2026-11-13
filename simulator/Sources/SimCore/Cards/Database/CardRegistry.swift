enum Behavior: Sendable {
    case vanilla, mantis
    case sixthStreetRecruits, adamSmasher, adrenalineConverter, afterparty, allIsLost
    case altMother, altSoulkiller, radioport, negotiators, chromeReverie
    case corpoSecurity, corporateSurveillance, cyberpsychosis, detonate, dexter
    case dumDum, fieldOperator, floorIt, gorillaArms, goroLegend
    case goroUnit, hanako, industrialAssembly, voodooBoy, jackie
    case johnny, kiroshi, laLlorona, lesElemens, lizzyWizzy
    case goons, mandibular, meredith, minotaur, kusanagi
    case flathead, malfini, overTheEdge, peaceOffering, pepe
    case placide, pyramidSong, riverWard, royce, ruthlessLowlife
    case saburo, safetyOverride, oda, sandevistan, satori
    case saulBright, screw, bombus, ripper, huscle
    case takeControl, heist, threeMouths, towerfall, trustNoOne
    case vStreetkid, valentino, viktorDrop, viktorSitDown, wildInTheStreets
    case yorinobu, zetatech
    case bootleg, mamanBrigitte, maxTacAV, nocturne, synapseBurnout, relic

    init(name: String) {
        self = Behavior.table[Behavior.normalize(name)] ?? .vanilla
    }

    static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: " - ", with: "-")
            .replacingOccurrences(of: "’", with: "'")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    private static let table: [String: Behavior] = {
        let entries: [(String, Behavior)] = [
            ("6th Street Recruits", .sixthStreetRecruits),
            ("Adam Smasher-Ender of Legends", .adamSmasher),
            ("Adrenaline Converter", .adrenalineConverter),
            ("Afterparty at Lizzie's", .afterparty),
            ("All is Lost", .allIsLost),
            ("Alt Cunningham-Mother of Daemons", .altMother),
            ("Alt Cunningham-Soulkiller Architect", .altSoulkiller),
            ("Arasaka Emergency Radioport", .radioport),
            ("Augmented Negotiators", .negotiators),
            ("Chrome Reverie", .chromeReverie),
            ("Corpo Security", .corpoSecurity),
            ("Corporate Surveillance", .corporateSurveillance),
            ("Cyberpsychosis", .cyberpsychosis),
            ("Detonate", .detonate),
            ("Dexter DeShawn-One Last Chance", .dexter),
            ("Dum Dum-Maelstrom Triggerman", .dumDum),
            ("Field Operator", .fieldOperator),
            ("Floor It", .floorIt),
            ("Gorilla Arms", .gorillaArms),
            ("Goro Takemura-Hands Unclean", .goroLegend),
            ("Goro Takemura-Losing His Way", .goroUnit),
            ("Hanako Arasaka-Daughter of the Emperor", .hanako),
            ("Industrial Assembly", .industrialAssembly),
            ("Jacked-In Voodoo Boy", .voodooBoy),
            ("Jackie Welles-Pour One Out For Me", .jackie),
            ("Johnny Silverhand-Never Stop Fighting", .johnny),
            ("Kiroshi Optics", .kiroshi),
            ("La Llorona-Ghost of the Past", .laLlorona),
            ("Les Élémens", .lesElemens),
            ("Lizzy Wizzy-Delicate Weapon", .lizzyWizzy),
            ("Maelstrom Goons", .goons),
            ("Mandibular Upgrade", .mandibular),
            ("Meredith Stout-Stone Cold Corpo", .meredith),
            ("Minotaur", .minotaur),
            ("Mantis Blades", .mantis),
            ("Modded Kusanagi", .kusanagi),
            ("MT0D12 Flathead", .flathead),
            ("Offduty Malfini", .malfini),
            ("Over the Edge", .overTheEdge),
            ("Peace Offering", .peaceOffering),
            ("Pepe Najarro-Working Doubles", .pepe),
            ("Placide-Voodoo Sentinel", .placide),
            ("Pyramid Song", .pyramidSong),
            ("River Ward-Detective on the Hunt", .riverWard),
            ("Royce-Psycho on the Edge", .royce),
            ("Ruthless Lowlife", .ruthlessLowlife),
            ("Saburo Arasaka-Stubborn Patriarch", .saburo),
            ("Safety Override", .safetyOverride),
            ("Sandayu Oda-Hanako's Guardian", .oda),
            ("Sandevistan", .sandevistan),
            ("Satori-Sword of Saburo", .satori),
            ("Saul Bright-Stormrider", .saulBright),
            ("Screw-Lovelorn Fool", .screw),
            ("Secondhand Bombus", .bombus),
            ("Sketchy Ripper", .ripper),
            ("Swordwise Huscle", .huscle),
            ("Take Control", .takeControl),
            ("The Heist", .heist),
            ("Three Mouths, One Desire", .threeMouths),
            ("Towerfall", .towerfall),
            ("Trust No One", .trustNoOne),
            ("V-Streetkid", .vStreetkid),
            ("Valentino Guerrera", .valentino),
            ("Viktor Vektor-Drop Your Illusions", .viktorDrop),
            ("Viktor Vektor-Sit Down and Relax", .viktorSitDown),
            ("Wild in the Streets", .wildInTheStreets),
            ("Yorinobu Arasaka-Embracing Destruction", .yorinobu),
            ("Zetatech Faceplate", .zetatech),
            ("Bootleg Black Sapphire Show", .bootleg),
            ("Maman Brigitte-Spirit of Death", .mamanBrigitte),
            ("MaxTac AV", .maxTacAV),
            ("Nocturne OP55 N1", .nocturne),
            ("Synapse Burnout", .synapseBurnout),
            ("The Relic-Experimental Biochip", .relic),
        ]
        return Dictionary(uniqueKeysWithValues: entries.map { (normalize($0.0), $0.1) })
    }()
}
