import CNCCutters
import CNCMachineProfile
import Foundation

/// Where prefilled effective feed and spindle values came from.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public enum EffectiveValueSource: String, Sendable, Equatable {
    /// Values came directly from the cutter record.
    case cutterPrefill
    /// At least one value was clamped to the nearest allowed bound.
    case nearestBound
    /// Values were selected by the user.
    case userChoice
}

/// Reasons a requested effective value could not be accepted.
///
/// - Concurrency: `Sendable` error value; safe to share across concurrency boundaries.
public enum MaterialResolutionError: Error, Equatable, Sendable {
    /// The value lies outside the material/profile intersection.
    case outsideIntersection
}

/// The band that caused a resolution conflict.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public enum BandKind: String, Sendable, Equatable {
    /// The feed band.
    case feed
    /// The spindle band.
    case spindle
}

/// One band whose material range cannot satisfy the machine profile.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct BandConflict: Equatable, Sendable {
    /// The band that conflicts.
    public let band: BandKind
    /// A human-readable explanation of the conflict.
    public let message: String

    /// Creates a conflict for a band with an explanatory message.
    public init(band: BandKind, message: String) {
        self.band = band
        self.message = message
    }
}

/// The result of intersecting material bands with a machine profile.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public enum ResolutionOutcome: Equatable, Sendable {
    /// Valid values with a recorded source and confirmation state.
    case resolved(EffectiveCuttingValues)
    /// The bands that cannot be satisfied.
    case noOverlap([BandConflict])
}

/// Effective feed and spindle values for one job, with source and confirmation state.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct EffectiveCuttingValues: Equatable, Sendable {
    /// The effective feed rate in mm/min.
    public let feed: Double
    /// The effective spindle speed in RPM.
    public let spindle: Double
    /// Where the prefilled values came from.
    public let source: EffectiveValueSource
    /// Whether the user has confirmed the values.
    public let confirmed: Bool

    /// Creates unconfirmed values, validated against the material/profile intersection.
    ///
    /// - Throws: `MaterialResolutionError.outsideIntersection` when feed or spindle lies
    ///   outside the allowed intersection.
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

    /// Returns the same values with the user's per-job confirmation recorded (FR-079).
    ///
    /// Resolution always produces an unconfirmed value; only an explicit UI confirmation may call
    /// this. The returned value is a copy, so a prefilled value is never mutated in place.
    public func confirming() -> EffectiveCuttingValues {
        EffectiveCuttingValues(
            feed: feed,
            spindle: spindle,
            source: source,
            confirmed: true
        )
    }

    /// Resolves material bands against profile limits, prefilling from the cutter.
    ///
    /// - Returns: `.resolved` with unconfirmed values, or `.noOverlap` for every conflict.
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
