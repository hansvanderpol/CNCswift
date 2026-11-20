import CNCMaterials
import CNCStorage
import Foundation

/// The state of a stored user-material document.
///
/// `absent`, `refused`, and `corrupt` are reported, not thrown, so the original bytes stay intact.
public enum MaterialLibraryLoadOutcome: Sendable, Equatable {
    case absent
    case loaded([Material])
    case migrated(from: Int, materials: [Material])
    case refused(found: Int)
    case corrupt(path: String)
}

/// Persistence for user-defined materials; built-in presets are merged at load time.
public protocol MaterialLibraryStoring: Sendable {
    func load(from url: URL) async throws -> MaterialLibraryLoadOutcome
    func save(_ materials: [Material], to url: URL) async throws

    /// The shipped presets plus every stored user material, with no preset shadowed.
    func resolvedMaterials(from url: URL) async throws -> [Material]
}

/// Stores user materials over the shared versioned document primitive.
///
/// The round trip, preset merge, and refusal behaviour are added by task T066. The type exists
/// now so the test-first persistence contract compiles and fails for the missing behaviour.
public struct MaterialLibraryStore: MaterialLibraryStoring {
    private let fileSystem: any FileSystem

    public init(fileSystem: any FileSystem = DiskFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func load(from url: URL) async throws -> MaterialLibraryLoadOutcome {
        guard fileSystem.exists(url) else { return .absent }
        return .absent
    }

    public func save(_ materials: [Material], to url: URL) async throws {
        _ = (materials, url)
    }

    public func resolvedMaterials(from url: URL) async throws -> [Material] {
        _ = url
        return Presets.all
    }
}
