//
//  HuntPackage.swift  ·  SHARED CONTRACT (C). Change only after telling the team.
//  A hunt flattened into plain Codable data so it can travel between phones:
//  as a .quarryhunt file (AirDrop / Messages) or over the nearby connection.
//  B writes the conversions to/from SwiftData in Quarry/Hunt/HuntPackage+SwiftData.swift.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated struct HuntPackage: Codable, Sendable, Hashable {
    var formatVersion: Int = 1
    var shareID: UUID
    var title: String
    var hostName: String
    var checkpoints: [CheckpointPackage]
}

nonisolated struct CheckpointPackage: Codable, Sendable, Hashable {
    var order: Int
    var clue: String
    var kindRaw: String
    var referencePrints: [Data]
    var thumbnail: Data?
    var targetLabel: String?
    var latitude: Double?
    var longitude: Double?
    var radiusMeters: Double
    var requiresLocation: Bool
}

extension UTType {
    /// Declared in Quarry/Info.plist (UTExportedTypeDeclarations), file extension .quarryhunt
    nonisolated static let quarryHunt = UTType(exportedAs: "com.quarryapp.hunt")
}

extension HuntPackage: Transferable {
    /// Lets B use ShareLink(item: package, preview: SharePreview(package.title)) for AirDrop/Messages.
    nonisolated static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .quarryHunt)
    }

    /// Decode a received .quarryhunt file (from .onOpenURL).
    nonisolated static func load(from url: URL) throws -> HuntPackage {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try JSONDecoder().decode(HuntPackage.self, from: Data(contentsOf: url))
    }
}
