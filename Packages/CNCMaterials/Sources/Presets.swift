/// The built-in material library shipped with the app.
public enum Presets {
    /// All shipped materials, each marked with its built-in origin.
    public static let all: [Material] = [
        Material(
            id: "preset-softwood",
            name: "Softwood (pine/basswood)",
            feedBand: 600...800,
            spindleBand: 7000...8000,
            origin: .builtIn,
            shippedVersion: "provisional"
        ),
        Material(
            id: "preset-hardwood",
            name: "Hardwood (oak/maple)",
            feedBand: 400...600,
            spindleBand: 7000...8000,
            origin: .builtIn,
            shippedVersion: "provisional"
        ),
        Material(
            id: "preset-mdf",
            name: "MDF",
            feedBand: 500...700,
            spindleBand: 7000...8000,
            origin: .builtIn,
            shippedVersion: "provisional"
        ),
        Material(
            id: "preset-plywood",
            name: "Plywood",
            feedBand: 500...700,
            spindleBand: 7000...8000,
            origin: .builtIn,
            shippedVersion: "provisional"
        ),
    ]
}
