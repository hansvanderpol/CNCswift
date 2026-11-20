import CutterLibraryModalUI
import Testing

/// Announcement wording for the cutter-library workflow (FR-070, SC-009).
@Test func cutterRowAnnouncementCarriesIdentityAndDimensions() {
    #expect(
        AccessibilityText.cutterRowLabel(name: "Ball 3", type: "ballNose")
            == "Cutter Ball 3, ballNose"
    )
    let value = AccessibilityText.cutterRowValue(shank: "3", cut: "12")
    #expect(value.contains("3 millimetres"))
    #expect(value.contains("12 millimetres"))
    #expect(AccessibilityText.deleteCutterLabel("Ball 3") == "Delete Ball 3")
}

@Test func fieldAndErrorAnnouncementsNameTheBrokenField() {
    #expect(AccessibilityText.libraryError("Disk full").contains("Disk full"))
    let hint = AccessibilityText.fieldHint(for: .shankDiameter)
    #expect(hint.contains("shank diameter"))
    #expect(hint.contains("validated"))
    #expect(AccessibilityText.fieldHint(for: .feedRate).contains("feed rate"))
}
