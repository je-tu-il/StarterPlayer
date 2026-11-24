import Foundation

enum ScoreCategory: String, CaseIterable, Hashable {
    case cards = "Cartes"
    case dice = "Dés"
    case board = "Plateau"

    var icon: String {
        switch self {
        case .cards: "suit.club"
        case .dice: "die.face.5"
        case .board: "square.grid.2x2"
        }
    }
}

enum ScoreRule: Equatable {
    case points, signed, low, signedLow, ranks, wins, single, set
    case skyjo, flip, phase, wizard, qwixx, clever, encore, chess
    case yams, skull

    var lowestWins: Bool { self == .low || self == .signedLow || self == .skyjo || self == .ranks }
    var isSingle: Bool { self == .single }
}

struct ScoreField {
    let label: String
    let range: ClosedRange<Int>

    init(_ label: String, _ range: ClosedRange<Int> = 0...100_000) {
        self.label = label
        self.range = range
    }
}

struct ScoreGame: Identifiable {
    let id: String
    let title: String
    let category: ScoreCategory
    let rule: ScoreRule
    let instructions: String
    let target: Int?
    let labels: [String]

    init(_ id: String, _ title: String, _ category: ScoreCategory, _ rule: ScoreRule,
         _ instructions: String, target: Int? = nil, labels: [String] = []) {
        self.id = id
        self.title = title
        self.category = category
        self.rule = rule
        self.instructions = instructions
        self.target = target
        self.labels = labels
    }

    var fields: [ScoreField] {
        if !labels.isEmpty {
            return labels.map { ScoreField($0, rule == .set || rule == .signed ? -100_000...100_000 : 0...100_000) }
        }
        switch rule {
        case .skyjo: return [ScoreField("Somme des cartes", -24...144), ScoreField("A clôturé (0 ou 1)", 0...1)]
        case .flip: return [
            ScoreField("Somme des cartes Nombre", 0...63), ScoreField("Total des modificateurs +", 0...30),
            ScoreField("Carte ×2 (0 ou 1)", 0...1), ScoreField("Flip 7 (0 ou 1)", 0...1),
            ScoreField("Échec (0 ou 1)", 0...1)
        ]
        case .phase: return [ScoreField("Phase réussie (0 ou 1)", 0...1), ScoreField("Points des cartes restantes")]
        case .wizard: return [ScoreField("Pari", 0...20), ScoreField("Plis gagnés", 0...20)]
        case .qwixx: return ["Rouge", "Jaune", "Vert", "Bleu"].map { ScoreField($0, 0...12) } + [ScoreField("Coups manqués", 0...4)]
        case .clever:
            let colors = id == "clever" ? ["Jaune", "Bleu", "Vert", "Orange", "Violet"] :
                (id == "double-clever" ? ["Argent", "Jaune", "Bleu", "Vert", "Rose"] :
                 ["Jaune", "Turquoise", "Bleu", "Marron", "Rose"])
            return colors.map { ScoreField($0) } + [ScoreField("Renards", 0...10)]
        case .encore: return [
            ScoreField("Colonnes"), ScoreField("Couleurs"), ScoreField("Étoiles non cochées", 0...15),
            ScoreField("Points d’exclamation restants", 0...8)
        ]
        case .wins: return [ScoreField("Victoire (0 ou 1)", 0...1)]
        case .ranks: return [ScoreField("Place", 1...99)]
        case .chess:
            return id == "chess" ? [ScoreField("Résultat en demi-points", 0...2)] :
                [ScoreField("Score en demi-points", -100_000...100_000)]
        case .signed, .signedLow, .set: return [ScoreField("Score de la manche", -100_000...100_000)]
        default: return [ScoreField("Points")]
        }
    }

    func score(_ values: [Int], skyjoMinimum: Int? = nil, minimumCount: Int = 0) -> Int {
        guard values.count == fields.count, zip(values, fields).allSatisfy({ pair in
            pair.1.range.contains(pair.0)
        }) else { return 0 }
        switch rule {
        case .skyjo:
            let failed = skyjoMinimum.map { values[0] > $0 || minimumCount > 1 } ?? false
            return values[1] == 1 && values[0] > 0 && failed ? values[0] * 2 : values[0]
        case .flip: return values[4] == 1 ? 0 : values[0] * (values[2] == 1 ? 2 : 1) + values[1] + values[3] * 15
        case .wizard: return values[0] == values[1] ? 20 + 10 * values[0] : -10 * abs(values[0] - values[1])
        case .qwixx: return values.prefix(4).map { $0 * ($0 + 1) / 2 }.reduce(0, +) - 5 * values[4]
        case .clever: return values.prefix(5).reduce(0, +) + values[5] * (values.prefix(5).min() ?? 0)
        case .encore: return values[0] + values[1] - 2 * values[2] + values[3]
        case .phase: return values[1]
        default: return values.reduce(0, +)
        }
    }

    func display(_ points: Int) -> String {
        rule == .chess ? (Double(points) / 2).formatted() : points.formatted()
    }

    static let all: [ScoreGame] = [
        ScoreGame("belote", "Belote", .cards, .points, "162 points de plis avec le dix de der, hors capot et annonces. Saisissez les points attribués après vérification du contrat.", labels: ["Points attribués", "Belote et rebelote"]),
        ScoreGame("coinche", "Coinche", .cards, .points, "Notez les points attribués à l’équipe après application de son contrat, de la coinche ou de la surcoinche.", labels: ["Points attribués", "Belote et rebelote"]),
        ScoreGame("tarot", "Tarot", .cards, .signed, "Saisissez les scores signés après le contrat et les primes. Les scores des joueurs doivent s’annuler sur chaque donne."),
        ScoreGame("rami", "Rami", .cards, .low, "Saisissez les points des cartes restées en main après l’application de votre variante."),
        ScoreGame("uno", "UNO", .cards, .points, "Créditez au gagnant de la manche la valeur des cartes adverses. Les cartes d’action valent 20 et les jokers 50 selon le barème classique.", target: 500),
        ScoreGame("skyjo", "Skyjo", .cards, .skyjo, "Additionnez les cartes restantes. Inscrivez 1 pour le joueur qui a clôturé. Son score positif double s’il n’est pas seul au minimum.", target: 100),
        ScoreGame("skyjo-action", "Skyjo Action", .cards, .signedLow, "Saisissez le total de la grille après les effets de fin de manche. Les lignes ou colonnes complètes d’étoiles peuvent donner des points négatifs."),
        ScoreGame("flip7", "Flip 7", .cards, .flip, "Entrez la somme des cartes Nombre et les modificateurs. Le bonus Flip 7 vaut 15 et un échec annule tout le score de la manche.", target: 200),
        ScoreGame("take6", "6 qui prend !", .cards, .low, "Comptez les têtes de bœuf ramassées. À 66 ou plus à la fin d’une manche, le plus petit total gagne.", target: 66),
        ScoreGame("president", "Président", .cards, .ranks, "Entrez l’ordre de sortie en commençant à 1. Le total le plus faible départage les joueurs si vous suivez plusieurs manches."),
        ScoreGame("phase10", "Phase 10", .cards, .phase, "Inscrivez 1 si la phase a été accomplie. Le joueur ayant terminé les 10 phases l’emporte, puis le plus faible total de pénalités départage les égalités.", target: 10),
        ScoreGame("skull-king", "Skull King", .cards, .skull, "Paris, plis et bonus, avec table par manche."),
        ScoreGame("the-crew", "The Crew", .cards, .single, "Suivez une ligne par mission et notez le nombre d’essais nécessaires. Utilisez un seul profil pour l’équipage."),
        ScoreGame("wizard", "Wizard", .cards, .wizard, "Un pari réussi vaut 20 plus 10 par pli annoncé. Un écart coûte 10 points par pli."),
        ScoreGame("cabo", "Cabo", .cards, .low, "Saisissez le score de manche final, avec la pénalité pour CABO raté et le cas spécial Kamikaze appliqués à la table."),
        ScoreGame("trio", "Trio", .cards, .wins, "Notez 1 pour une victoire de manche. En mode simple, elle s’obtient avec trois trios ou avec le trio de 7."),
        ScoreGame("five-crowns", "Five Crowns", .cards, .low, "Comptez les cartes restantes pour les 11 donnes. Incluez la valeur des cartes sauvages et des jokers."),
        ScoreGame("canasta", "Canasta", .cards, .signed, "Totalisez les combinaisons, primes de canasta et de sortie, puis retranchez les cartes en main.", target: 5000),
        ScoreGame("cribbage", "Cribbage", .cards, .points, "Saisissez les points de jeu et les points de main ou de crib. La partie se termine dès 121, dans l’ordre où les points ont été marqués.", target: 121, labels: ["Jeu", "Main et crib"]),
        ScoreGame("bridge", "Bridge", .cards, .signed, "Saisissez les résultats de chaque donne par camp après contrat, vulnérabilité et éventuelles pénalités. Pour un tournoi, saisissez le barème retenu."),
        ScoreGame("hearts", "Dame de pique", .cards, .low, "Un cœur vaut 1 et la dame de pique 13. Appliquez à table le cas des 26 points pris par le même joueur.", target: 100),
        ScoreGame("spades", "Spades", .cards, .signed, "Entrez les points du contrat et des plis supplémentaires après pénalités de sacs selon la variante."),
        ScoreGame("euchre", "Euchre", .cards, .points, "Selon la donne, attribuez 1 pour un contrat réussi, 2 pour un euchre ou un balayage, et 4 pour un balayage en solo.", target: 10),
        ScoreGame("gin", "Gin Rami", .cards, .points, "Inscrivez les points de bois mort, puis les primes de gin ou d’undercut de votre barème."),
        ScoreGame("pinochle", "Pinochle", .cards, .signed, "Saisissez les annonces et les points des plis après application du contrat."),
        ScoreGame("skat", "Skat", .cards, .signed, "Saisissez la valeur signée de la partie individuelle après multiplicateurs, surenchère et résultat."),
        ScoreGame("scopa", "Scopa", .cards, .points, "Saisissez les points des cartes, deniers, settebello et primiera, puis un point par scopa.", target: 11, labels: ["Cartes", "Deniers", "Settebello", "Primiera", "Scopas"]),
        ScoreGame("briscola", "Briscola", .cards, .points, "Comptez les points des plis sur 120 par donne. Le camp ayant plus de 60 remporte la donne."),
        ScoreGame("schnapsen", "Schnapsen", .cards, .points, "Attribuez les points de partie après vérification des 66 points, des annonces et des plis adverses."),
        ScoreGame("500", "500", .cards, .signed, "Appliquez la valeur du contrat en positif s’il est réussi ou en négatif s’il est chuté, puis les points des défenseurs.", target: 500),
        ScoreGame("oh-hell", "Ascenseur", .cards, .signed, "Saisissez le score calculé avec votre barème de contrat, qui varie selon les tables."),
        ScoreGame("whist", "Whist", .cards, .points, "Chaque camp compte un point par pli au-delà du sixième pour le whist classique."),
        ScoreGame("pitch", "Pitch", .cards, .signed, "Inscrivez les points de la donne après attribution du haut, du bas, du valet et du jeu, puis vérification du contrat."),
        ScoreGame("sueca", "Sueca", .cards, .points, "Entrez les points de partie attribués au camp gagnant selon le total de ses plis."),
        ScoreGame("mus", "Mus", .cards, .points, "Additionnez les points du grand, du petit, des paires et du jeu ou point après résolution des enchères."),
        ScoreGame("tute", "Tute", .cards, .points, "Saisissez la valeur des plis, des chants et du dernier pli après chaque donne."),
        ScoreGame("mille-bornes", "Mille Bornes", .cards, .points, "Entrez les bornes et les bonus de manche après décompte des bottes et des conditions spéciales.", labels: ["Bornes", "Primes"]),
        ScoreGame("hanabi", "Hanabi", .cards, .single, "Additionnez la hauteur des cinq feux d’artifice pour obtenir le score coopératif sur 25. Un seul profil suffit."),
        ScoreGame("sushi-go", "Sushi Go !", .cards, .set, "Totalisez les cartes de chaque manche. Ajoutez les puddings au dernier décompte, avec les éventuels points négatifs.", labels: ["Cartes de la manche", "Puddings (fin)"]),
        ScoreGame("sushi-go-party", "Sushi Go Party !", .cards, .set, "Totalisez le menu choisi à chaque manche. Décomptez les desserts à la fin de la partie.", labels: ["Cartes de la manche", "Desserts (fin)"]),
        ScoreGame("point-salad", "Point Salad", .cards, .set, "Entrez un sous-total par carte de score, en incluant les pénalités imprimées."),
        ScoreGame("sea-salt", "Sea Salt & Paper", .cards, .set, "Calculez les points des familles puis les bonus de fin. Une victoire immédiate des sirènes se tranche à la table.", labels: ["Familles", "Bonus"]),
        ScoreGame("scout", "SCOUT", .cards, .signed, "Inscrivez les points gagnés moins les cartes restant en main après la fin de manche."),
        ScoreGame("llama", "Lama", .cards, .low, "Comptez les jetons de pénalité encore en possession de chacun après les reprises de jetons.", target: 40),
        ScoreGame("no-thanks", "Non merci !", .cards, .signedLow, "Additionnez la plus petite carte de chaque suite, puis retranchez les jetons conservés."),
        ScoreGame("lost-cities", "Les Cités perdues", .cards, .set, "Saisissez chaque expédition après coût de départ, multiplicateur de paris et prime éventuelle."),
        ScoreGame("battle-line", "Battle Line", .cards, .wins, "Attribuez 1 par partie gagnée. Le résultat se joue sur cinq drapeaux ou trois adjacents."),
        ScoreGame("radlands", "Radlands", .cards, .wins, "Suivez les victoires après destruction des trois camps adverses."),
        ScoreGame("star-realms", "Star Realms", .cards, .wins, "Notez la victoire lorsque l’autorité adverse a atteint zéro."),
        ScoreGame("hero-realms", "Hero Realms", .cards, .wins, "Attribuez 1 au dernier héros ou camp en jeu en mode affrontement."),
        ScoreGame("the-game", "The Game", .cards, .single, "Saisissez le nombre de cartes non jouées pour toute l’équipe. Zéro signifie une victoire."),
        ScoreGame("the-mind", "The Mind", .cards, .single, "Notez le dernier niveau réussi par l’équipe, avec la limite liée au nombre de joueurs."),
        ScoreGame("fox-forest", "Le Renard des bois", .cards, .points, "Saisissez les points des plis selon leur barème non linéaire et les points des cartes 7 prises.", target: 21),
        ScoreGame("claim", "Claim", .cards, .wins, "Attribuez la victoire selon le nombre de factions contrôlées après la seconde phase."),
        ScoreGame("regicide", "Regicide", .cards, .single, "Notez combien de figures ont été vaincues par l’équipe, sur douze."),
        ScoreGame("yams", "Yam’s", .dice, .yams, "Feuille à 13 cases avec prime de 35 à partir de 63 dans la section haute."),
        ScoreGame("yahtzee", "Yahtzee", .dice, .yams, "Feuille à 13 cases avec prime de 35 et bonus Yahtzee de 100 points. Appliquez la règle du joker à la table."),
        ScoreGame("farkle", "Farkle", .dice, .points, "Saisissez les points mis en banque. Un tour perdu vaut zéro. Après 10 000, appliquez le dernier tour prévu par votre édition.", target: 10000),
        ScoreGame("421", "421", .dice, .low, "Suivez les jetons restants à la fin de la décharge ou les pénalités convenues entre parties."),
        ScoreGame("qwixx", "Qwixx", .dice, .qwixx, "Entrez le nombre de croix par rangée, verrou compris s’il est coché. Chaque coup manqué coûte 5 points."),
        ScoreGame("clever", "Très Futé !", .dice, .clever, "Saisissez les cinq sous-totaux de couleur et le nombre de renards. Chaque renard rapporte le plus petit sous-total."),
        ScoreGame("encore", "Encore !", .dice, .encore, "Additionnez colonnes et couleurs. Chaque étoile non cochée coûte 2 points et chaque point d’exclamation restant rapporte 1."),
        ScoreGame("double-clever", "Vraiment Très Futé !", .dice, .clever, "Saisissez les cinq sous-totaux de cette édition dans l’ordre de ses zones. Chaque renard rapporte le plus petit sous-total."),
        ScoreGame("triples-clever", "Très Futé à la puissance trois", .dice, .clever, "Saisissez les cinq sous-totaux de cette édition dans l’ordre de ses zones. Chaque renard rapporte le plus petit sous-total."),
        ScoreGame("zombie-dice", "Zombie Dice", .dice, .points, "Inscrivez les cerveaux conservés, ou zéro si trois tirs ont mis fin au tour.", target: 13),
        ScoreGame("cant-stop", "Can’t Stop", .dice, .wins, "Attribuez 1 au joueur qui ferme sa troisième colonne."),
        ScoreGame("king-tokyo", "King of Tokyo", .dice, .wins, "Attribuez 1 au monstre à 20 points de victoire ou dernier en jeu."),
        ScoreGame("bang-dice", "Bang! Le Jeu de dés", .dice, .wins, "Attribuez 1 au camp vainqueur selon les rôles révélés."),
        ScoreGame("roll-through-ages", "Roll Through the Ages", .dice, .set, "Totalisez monuments et développements, puis retranchez les catastrophes.", labels: ["Monuments", "Développements", "Catastrophes (négatif)"]),
        ScoreGame("railroad-ink", "Railroad Ink", .dice, .set, "Saisissez les réseaux, routes et voies ferrées les plus longues, le centre, les objectifs de l’édition et les erreurs en négatif.", labels: ["Réseaux", "Route la plus longue", "Voie ferrée la plus longue", "Centre", "Objectifs", "Erreurs (négatif)"]),
        ScoreGame("welcome", "Welcome To…", .board, .set, "Décomptez plans, parcs, piscines, lots et pénalités sur les lignes de la feuille.", labels: ["Plans", "Parcs", "Piscines", "Lotissements", "Bonus", "Pénalités (négatif)"]),
        ScoreGame("cartographers", "Cartographers", .board, .set, "Inscrivez les deux objectifs actifs par saison, les pièces et les monstres en négatif.", labels: ["Objectif 1", "Objectif 2", "Pièces", "Monstres (négatif)"]),
        ScoreGame("bohnanza-dice", "Bohnanza : Le Jeu de dés", .dice, .points, "Saisissez les thunes gagnées grâce aux récoltes validées."),
        ScoreGame("qwingo", "Qwinto", .dice, .set, "Saisissez le score des rangées et pentagones, puis inscrivez les coups manqués à −5 chacun.", labels: ["Orange", "Jaune", "Violet", "Pentagones", "Coups manqués (points négatifs)"]),
        ScoreGame("azul", "Azul", .board, .set, "Saisissez les points des poses et les pénalités du plancher, puis les bonus de lignes, colonnes et couleurs.", labels: ["Poses", "Plancher (négatif)", "Lignes", "Colonnes", "Couleurs"]),
        ScoreGame("azul-summer", "Azul : Pavillon d’été", .board, .set, "Saisissez la pose des tuiles, les pénalités et les bonus finaux d’étoiles et de numéros.", labels: ["Poses", "Pénalités (négatif)", "Étoiles", "Numéros"]),
        ScoreGame("azul-stained", "Azul : Les Vitraux de Sintra", .board, .set, "Saisissez les points de motifs et bonus de fin, puis la pénalité du verre brisé.", labels: ["Motifs", "Bonus final", "Verre brisé (négatif)"]),
        ScoreGame("carcassonne", "Carcassonne", .board, .set, "Saisissez villes, chemins, abbayes, prés et extensions retenues, avec leur décompte de fin.", labels: ["Villes", "Chemins", "Abbayes", "Prés", "Extensions"]),
        ScoreGame("ticket-ride", "Les Aventuriers du Rail", .board, .set, "Saisissez les routes, les destinations réussies ou manquées et les primes prévues par la carte.", labels: ["Routes", "Destinations réussies", "Destinations manquées (négatif)", "Primes"]),
        ScoreGame("catan", "Catan", .board, .points, "Comptez colonies, villes, cartes de victoire et cartes spéciales selon votre scénario.", target: 10),
        ScoreGame("7w", "7 Wonders", .board, .set, "Décomptez conflits, pièces, merveille, bâtiments civils, commerce, guildes et sciences.", labels: ["Conflits", "Pièces", "Merveille", "Bâtiments civils", "Commerce", "Guildes", "Sciences"]),
        ScoreGame("7w-duel", "7 Wonders Duel", .board, .set, "Calculez les points civils si aucune suprématie militaire ou scientifique n’a terminé la partie.", labels: ["Civil", "Science", "Commerce", "Guildes", "Merveilles", "Progrès", "Trésor", "Militaire"]),
        ScoreGame("distilled", "Distilled", .board, .set, "Inscrivez points de spiritueux, prix, améliorations et objectifs de distillerie.", labels: ["Spiritueux", "Prix", "Améliorations", "Objectifs", "Autres points"]),
        ScoreGame("wingspan", "Wingspan", .board, .set, "Entrez oiseaux, cartes bonus, objectifs, œufs, nourriture stockée et cartes glissées.", labels: ["Oiseaux", "Cartes bonus", "Objectifs", "Œufs", "Nourriture stockée", "Cartes glissées"]),
        ScoreGame("wyrmspan", "Wyrmspan", .board, .set, "Décomptez dragons, œufs, ressources stockées, cartes glissées, objectifs et guilde.", labels: ["Dragons", "Objectifs", "Guilde", "Œufs", "Ressources stockées", "Cartes glissées", "Autres points"]),
        ScoreGame("flamecraft", "Flamecraft", .board, .set, "Saisissez réputation en cours et gains de fin de partie, dont les dragons fantaisie et pièces.", labels: ["Réputation en cours", "Dragons fantaisie", "Pièces", "Autres gains"]),
        ScoreGame("cascadia", "Cascadia", .board, .set, "Inscrivez les animaux par espèce, corridors par habitat, majorités et jetons Nature.", labels: ["Ours", "Wapitis", "Saumons", "Buses", "Renards", "Habitats", "Majorités", "Jetons Nature"]),
        ScoreGame("calico", "Calico", .board, .set, "Saisissez points des motifs, des chats et des boutons, prime arc-en-ciel comprise.", labels: ["Motifs", "Chats", "Boutons", "Arc-en-ciel"]),
        ScoreGame("harmonies", "Harmonies", .board, .set, "Décomptez chaque type de paysage et les cartes Animal, avec l’esprit de la nature si utilisé.", labels: ["Arbres", "Montagnes", "Bâtiments", "Champs", "Eau", "Animaux", "Esprit"]),
        ScoreGame("akropolis", "Akropolis", .board, .set, "Entrez par quartier le produit de sa valeur par ses étoiles, puis ajoutez les pierres.", labels: ["Habitations", "Marchés", "Caserne", "Temples", "Jardins", "Pierres"]),
        ScoreGame("kingdomino", "Kingdomino", .board, .set, "Inscrivez pour chaque domaine sa taille multipliée par ses couronnes, puis les bonus optionnels.", labels: ["Domaines", "Bonus optionnels"]),
        ScoreGame("patchwork", "Patchwork", .board, .signed, "Additionnez les boutons et l’éventuel bonus 7×7, puis retranchez 2 par case vide.", labels: ["Boutons", "Bonus 7×7", "Cases vides (points négatifs)"]),
        ScoreGame("splendor", "Splendor", .board, .points, "Comptez le prestige des développements et des nobles. À égalité, le moins de développements gagne.", target: 15),
        ScoreGame("splendor-duel", "Splendor Duel", .board, .wins, "Attribuez la victoire selon le seuil atteint en prestige total, en couronnes ou dans une couleur."),
        ScoreGame("stone-age", "L’Âge de pierre", .board, .set, "Saisissez les points de bâtiments, de cartes Civilisation et de ressources restantes.", labels: ["Bâtiments", "Civilisation", "Ressources"]),
        ScoreGame("agricola", "Agricola", .board, .set, "Décomptez les catégories de ferme, les pénalités de cases vides, les aménagements et les bonus.", labels: ["Champs", "Pâturages", "Céréales", "Légumes", "Moutons", "Sangliers", "Bœufs", "Cases vides (négatif)", "Ferme", "Famille", "Bonus"]),
        ScoreGame("caverna", "Caverna", .board, .set, "Décomptez animaux, cultures, aménagements, trésor et pénalités de pièces ou cases manquantes.", labels: ["Animaux", "Cultures", "Aménagements", "Trésor", "Pénalités (négatif)", "Autres points"]),
        ScoreGame("viticulture", "Viticulture", .board, .signed, "Inscrivez la valeur de la piste. Terminez l’année où le seuil de l’édition est atteint."),
        ScoreGame("everdell", "Everdell", .board, .set, "Décomptez cartes, bonus de cartes, événements et jetons de points.", labels: ["Cartes", "Bonus", "Événements", "Jetons"]),
        ScoreGame("parks", "PARKS", .board, .set, "Décomptez les parcs visités, photos, objectifs personnels et éventuels bonus de fin.", labels: ["Parcs", "Photos", "Objectifs", "Autres points"]),
        ScoreGame("quacks", "Les Charlatans de Belcastel", .board, .points, "Additionnez les points de chaudron et les points de fin prévus par votre édition.", labels: ["Chaudron", "Points de fin"]),
        ScoreGame("terraforming", "Terraforming Mars", .board, .set, "Inscrivez le niveau de terraformation, les objectifs, les récompenses, les tuiles et les cartes.", labels: ["Terraformation", "Objectifs", "Récompenses", "Tuiles", "Cartes"]),
        ScoreGame("ark-nova", "Ark Nova", .board, .signed, "Saisissez la différence finale entre les valeurs des deux pistes calculée selon la règle après les bonus."),
        ScoreGame("dune-imperium", "Dune : Imperium", .board, .points, "Comptez alliances, conflits gagnés, cartes et récompenses. Le seuil déclenche la fin de manche.", target: 10),
        ScoreGame("clank", "Clank !", .board, .set, "Décomptez artefacts et objets, or, cartes et jeton de maîtrise. Seuls les joueurs admissibles au décompte sont classés.", labels: ["Artefact et objets", "Or", "Cartes", "Maîtrise"]),
        ScoreGame("small-world", "Small World", .board, .points, "Additionnez les pièces de victoire obtenues après chaque tour."),
        ScoreGame("takenoko", "Takenoko", .board, .set, "Additionnez les objectifs réalisés et l’éventuelle carte Empereur. Appliquez le départage des objectifs panda à la table.", labels: ["Parcelles", "Jardinier", "Panda", "Empereur"]),
        ScoreGame("photosynthesis", "Photosynthesis", .board, .points, "Additionnez les jetons collectés et les points de lumière convertis selon la règle."),
        ScoreGame("camel-up", "Camel Up", .board, .signed, "Saisissez le total de livres égyptiennes après les paris et leurs pénalités."),
        ScoreGame("stone-spirit", "Spirit Island", .board, .single, "Inscrivez le score coopératif calculé avec le niveau de difficulté, victoire ou défaite et état de l’île."),
        ScoreGame("pandemic", "Pandemic", .board, .single, "Pour l’équipe, notez 1 pour une victoire après découverte des quatre remèdes, 0 pour une défaite."),
        ScoreGame("chess", "Échecs", .board, .chess, "Tournoi classique : saisissez 2 pour une victoire (1 point), 1 pour une nulle (½ point) ou 0 pour une défaite."),
        ScoreGame("go", "Go", .board, .chess, "Saisissez le score après le komi, en demi-points. Par exemple, saisissez 15 pour 7,5 points."),
        ScoreGame("othello", "Othello", .board, .points, "Inscrivez le nombre de pions de chaque couleur en fin de partie."),
        ScoreGame("scrabble", "Scrabble", .board, .signed, "Inscrivez le score de chaque mot et, sur la dernière ligne, les ajustements des lettres restantes."),
        ScoreGame("boggle", "Boggle", .board, .points, "Saisissez les points des mots uniques en appliquant le barème de longueur."),
        ScoreGame("domino", "Dominos bloqués", .board, .points, "En mode points des dominos bloqués, notez les points des tuiles adverses qui restent après la partie."),
        ScoreGame("rummikub", "Rummikub", .board, .signed, "Déduisez à chaque perdant ses tuiles restantes et créditez leur somme au gagnant."),
        ScoreGame("sequence", "Sequence", .board, .wins, "Attribuez la victoire au camp ayant le nombre requis de séquences selon la configuration."),
        ScoreGame("quoridor", "Quoridor", .board, .wins, "Attribuez la victoire au premier pion qui atteint le bord opposé."),
        ScoreGame("quarto", "Quarto", .board, .wins, "Attribuez 1 pour un alignement valide de quatre pièces partageant un attribut."),
        ScoreGame("backgammon", "Backgammon", .board, .points, "Saisissez la valeur du videau multipliée par le résultat simple, gammon ou backgammon."),
        ScoreGame("crokinole", "Crokinole", .board, .points, "Saisissez l’écart de score d’une manche pour le camp gagnant, centres à 20 inclus."),
        ScoreGame("dixit", "Dixit", .board, .points, "Inscrivez les points de vote et des cartes leurres par manche selon le barème de votre édition."),
        ScoreGame("just-one", "Just One", .board, .single, "Notez les cartes devinées correctement par le groupe, sur les treize de la partie."),
        ScoreGame("codenames", "Codenames", .board, .wins, "Notez 1 pour l’équipe gagnante après ses agents retrouvés ou la désignation de l’assassin par l’adversaire."),
    ]
}
