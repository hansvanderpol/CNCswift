import CNCCutters
import CNCMachineProfile
import Foundation

public enum EffectiveValueSource: String, Sendable, Equatable {
    case cutterPrefill
    case nearestBound
    case userChoice
}

public enum MaterialResolutionError: Error, Equatable, Sendable {
    case outsideIntersection
}

public enum BandKind: String, Sendable, Equatable {
    case feed
    case spindle
}

public struct BandConflict: Equatable, Sendable {
    public let band: BandKind
    public let message: String

    public init(band: BandKind, message: String) {
        self.band = band
        self.message = message
    }
}

public enum ResolutionOutcome: Equatable, Sendable {
    case resolved(EffectiveCuttingValues)
    case noOverlap([BandConflict])
}

public struct EffectiveCuttingValues: Equatable, Sendable {
    public let feed: Double
    public let spindle: Double
    public let source: EffectiveValueSource
    public let confirmed: Bool

    public init(
        feed: Double,
        spindle: Double,
        source: EffectiveValueSource,
        material: Material,
        profile: MachineProfile
    ) throws {
        let feedRange = Self.feedIntersection(material: material, profile: profile)
        let spindleRange = Self.spindleIntersection(material: material, profile: profile)
        guard let feedRange, feedRange.contains(feed),
            let spindleRange, spindleRange.contains(spindle)
        else {
            throw MaterialResolutionError.outsideIntersection
        }
        self.feed = feed
        self.spindle = spindle
        self.source = source
        self.confirmed = false
    }

    private init(feed: Double, spindle: Double, source: EffectiveValueSource, confirmed: Bool) {
        self.feed = feed
        self.spindle = spindle
        self.source = source
        self.confirmed = confirmed
    }

    public static func resolve(
        material: Material,
        cutter: Cutter,
        profile: MachineProfile
    ) -> ResolutionOutcome {
        let feedRange = feedIntersection(material: material, profile: profile)
        let spindleRange = spindleIntersection(material: material, profile: profile)

        var conflicts: [BandConflict] = []
        if feedRange == nil {
            conflicts.append(
                BandConflict(
                    band: .feed,
                    message:
                        "Material \(material.name) feed band \(format(material.feedBand.lowerBound))-\(format(material.feedBand.upperBound)) mm/min cannot satisfy the profile ceiling of \(format(profile.limits.maxFeedRate)) mm/min."
                )
            )
        }
        if spindleRange == nil {
            conflicts.append(
                BandConflict(
                    band: .spindle,
                    message:
                        "Material \(material.name) spindle band \(formatInt(material.spindleBand.lowerBound))-\(formatInt(material.spindleBand.upperBound)) RPM cannot satisfy the profile range \(formatInt(profile.limits.spindleMin))-\(formatInt(profile.limits.spindleMax)) RPM."
                )
            )
        }
        if !conflicts.isEmpty {
            return .noOverlap(conflicts)
        }

        guard let feedRange, let spindleRange else {
            return .noOverlap(conflicts)
        }

        let (feed, feedSource) = prefill(value: cutter.feedRate, in: feedRange)
        let (spindle, spindleSource) = prefill(value: cutter.spindleSpeed, in: spindleRange)
        let overallSource: EffectiveValueSource
        if feedSource == .nearestBound || spindleSource == .nearestBound {
            overallSource = .nearestBound
        } else {
            overallSource = .cutterPrefill
        }

        return .resolved(
            EffectiveCuttingValues(
                feed: feed,
                spindle: spindle,
                source: overallSource,
                confirmed: false
            )
        )
    }

    private static func feedIntersection(
        material: Material, profile: MachineProfile
    ) -> ClosedRange<Double>? {
        let lower = max(material.feedBand.lowerBound, 0)
        let upper = min(material.feedBand.upperBound, profile.limits.maxFeedRate)
        return lower <= upper ? lower...upper : nil
    }

    private static func spindleIntersection(
        material: Material, profile: MachineProfile
    ) -> ClosedRange<Double>? {
        let lower = max(material.spindleBand.lowerBound, profile.limits.spindleMin)
        let upper = min(material.spindleBand.upperBound, profile.limits.spindleMax)
        return lower <= upper ? lower...upper : nil
    }

    private static func prefill(
        value: Double, in range: ClosedRange<Double>
    ) -> (Double, EffectiveValueSource) {
        if range.contains(value) {
            return (value, .cutterPrefill)
        }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return (clamped, .nearestBound)
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.3f", value)
    }

    private static func formatInt(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}
