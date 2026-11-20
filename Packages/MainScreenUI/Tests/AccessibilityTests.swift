import MainScreenUI
import Testing

/// VoiceOver wording is user-facing content: these tests pin the facts each announcement must carry
/// (FR-070, SC-009) without depending on a running SwiftUI view.
@Test func cutterAnnouncementNamesIdentityAndSelectionState() {
    let selected = AccessibilityText.cutterValue(
        isSelected: true, diameter: "6", feed: "1200", spindle: "18000"
    )
    #expect(selected.contains("Selected"))
    #expect(selected.contains("6 millimetres cutting diameter"))
    #expect(selected.contains("1200 millimetres per minute"))
    #expect(selected.contains("18000 RPM"))

    let unselected = AccessibilityText.cutterValue(
        isSelected: false, diameter: "3", feed: "900", spindle: "15000"
    )
    #expect(unselected.hasPrefix("Not selected"))
    #expect(AccessibilityText.cutterLabel(name: "Flat 6", type: "flat") == "Cutter Flat 6, flat")
}

@Test func everyGenerationStateHasASpokenDescription() {
    #expect(AccessibilityText.generationStatus(.idle) == "Idle")
    #expect(AccessibilityText.generationStatus(.running) == "Generating")
    #expect(AccessibilityText.generationStatus(.ready) == "Ready to preview")
    #expect(AccessibilityText.generationStatus(.cancelled) == "Cancelled")

    let blocked = AccessibilityText.generationStatus(.blocked(["Confirm units", "Select cutter"]))
    #expect(blocked.contains("Confirm units"))
    #expect(blocked.contains("Select cutter"))

    let failed = AccessibilityText.generationStatus(.failed("Bad STL"))
    #expect(failed.contains("Bad STL"))
}

@Test func progressAndStockAnnouncementsCarryTheirValues() {
    #expect(AccessibilityText.progress(completed: 3, total: 7) == "3 of 7 stages")
    #expect(AccessibilityText.progress(completed: 0, total: 0) == "0 of 1 stages")
    #expect(AccessibilityText.stockFieldLabel("Width") == "Stock Width in millimetres")
    #expect(AccessibilityText.stockFieldHint("Depth").contains("positive depth"))
    #expect(AccessibilityText.stockFieldHint("Depth").contains("millimetres"))
}
