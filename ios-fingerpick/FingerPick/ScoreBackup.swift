import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ScoreBackup: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    private static let maxSize = 16_000_000
    private static let rosterKey = "fingerpick.roster.v1"
    private static let historyKey = "fingerpick.draws.v1"
    private static let lowestKey = "fingerpick.free.lowestWins.v1"
    private static let freeKey = "fingerpick.free.rounds.v1"
    private static let yamsKey = "fingerpick.yams.v1"
    private static let yahtzeeKey = "fingerpick.yahtzee.v1"
    private static let skullKey = "fingerpick.skull.v1"
    private static var keys: [String] {
        Array(catalogByKey.keys) + [rosterKey, historyKey, freeKey, yamsKey, yahtzeeKey, skullKey]
    }
    private static var catalogByKey: [String: ScoreGame] {
        Dictionary(uniqueKeysWithValues: ScoreGame.all.map { ("fingerpick.catalog.v1.\($0.id)", $0) })
    }

    private struct Archive: Codable {
        let version: Int
        let data: [String: Data]
        let lowestWins: Bool
    }

    private let archive: Archive

    init(defaults: UserDefaults = .standard) {
        let keys = Self.keys
        let data = keys.reduce(into: [String: Data]()) { items, key in
            if let value = defaults.data(forKey: key), !value.isEmpty { items[key] = value }
        }
        archive = Archive(version: 1, data: data, lowestWins: defaults.bool(forKey: Self.lowestKey))
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.format }
        archive = try Self.read(data)
    }

    init(url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= Self.maxSize else { throw BackupError.format }
        archive = try Self.read(Data(contentsOf: url, options: .mappedIfSafe))
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(archive)
        guard data.count <= Self.maxSize else { throw BackupError.format }
        return FileWrapper(regularFileWithContents: data)
    }

    func restore(to defaults: UserDefaults = .standard) {
        let keys = Self.keys
        for key in keys {
            if let data = archive.data[key] { defaults.set(data, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        defaults.set(archive.lowestWins, forKey: Self.lowestKey)
    }

    private static func read(_ data: Data) throws -> Archive {
        guard data.count <= maxSize else { throw BackupError.format }
        let decoder = JSONDecoder()
        let archive = try decoder.decode(Archive.self, from: data)
        guard archive.version == 1 else { throw BackupError.format }
        let catalog = catalogByKey
        for (key, value) in archive.data {
            switch key {
            case rosterKey:
                guard validRoster(try decoder.decode([Player].self, from: value)) else { throw BackupError.format }
            case historyKey:
                let records = try decoder.decode([DrawRecord].self, from: value)
                guard records.count <= 200, Set(records.map(\.id)).count == records.count else { throw BackupError.format }
            case freeKey:
                let rounds = try decoder.decode([BasicRound].self, from: value)
                guard rounds.count <= 10_000, Set(rounds.map(\.id)).count == rounds.count,
                      rounds.allSatisfy({ $0.scores.values.allSatisfy { (-100_000...100_000).contains($0) } })
                else { throw BackupError.format }
            case yamsKey, yahtzeeKey:
                let snapshot = try decoder.decode(YamsView.Snapshot.self, from: value)
                guard snapshot.sheets.values.allSatisfy({ sheet in
                    (0...12).contains(sheet.extraYahtzees) && sheet.scores.values.allSatisfy { (0...500).contains($0) }
                }) else { throw BackupError.format }
            case skullKey:
                let snapshot = try decoder.decode(SkullKingView.Snapshot.self, from: value)
                guard snapshot.sheets.values.allSatisfy({ sheet in
                    sheet.rounds.allSatisfy { item in
                        (1...10).contains(item.key) && (0...10).contains(item.value.bet ?? 0)
                            && (0...10).contains(item.value.tricks ?? 0) && (0...500).contains(item.value.bonus)
                    }
                }) else { throw BackupError.format }
            default:
                guard let game = catalog[key] else { throw BackupError.format }
                let match = try decoder.decode(CatalogMatch.self, from: value)
                let players = Set(match.players.map(\.id))
                guard validRoster(match.players), !match.rounds.isEmpty, match.rounds.count <= 500,
                      Set(match.rounds.map(\.id)).count == match.rounds.count,
                      match.rounds.allSatisfy({ round in
                          round.entries.allSatisfy { entry in
                              players.contains(entry.key) && entry.value.count == game.fields.count
                                  && zip(entry.value, game.fields).allSatisfy { $0.1.range.contains($0.0) }
                          }
                      }) else { throw BackupError.format }
            }
        }
        return archive
    }

    private static func validRoster(_ roster: [Player]) -> Bool {
        roster.count <= 52 && Set(roster.map(\.id)).count == roster.count
    }

    private enum BackupError: LocalizedError {
        case format
        var errorDescription: String? { "Ce fichier de sauvegarde est trop volumineux ou son format est incompatible." }
    }
}
