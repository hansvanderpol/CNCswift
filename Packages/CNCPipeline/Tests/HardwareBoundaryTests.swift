import Foundation
import Testing

/// Hardware-boundary guard for FR-030 and C3 (plan task-shaping note 3).
///
/// The app writes a file and never streams to, drives, or controls machine hardware. This test
/// reads source and manifests as text, so a serial/USB surface hidden behind a typealias or a new
/// wrapper is still caught. The allow-list is deliberately empty: any hardware surface is a
/// violation until an amendment says otherwise.
private let packageNames = [
    "CNCMachineProfile", "CNCDiagnostics", "CNCStorage", "CNCGeometry", "CNCSTL",
    "CNCCutters", "CNCCuttersStore", "CNCMaterials", "CNCMaterialsStore", "CNCToolpath",
    "CNCGCode", "CNCValidation", "CNCSimulation", "CNCPipeline", "MainScreenUI",
    "CutterLibraryModalUI",
]

/// The only surfaces permitted to reach machine hardware. FR-030 allows file output only, so this
/// stays empty; adding an entry here requires an amendment to the specification.
private let hardwareAllowList: Set<String> = []

/// Lexical signatures of serial, USB, and direct machine-control APIs. Each maps to a stable name
/// used in the violation message.
private let hardwareSignatures: [String: String] = [
    "IORSerialPort": "IORSerialPort",
    "ORSSerial": "ORSSerial",
    "SerialPort": "serial port",
    "serialPort": "serial port",
    "IOKit": "IOKit",
    "IOUSB": "USB I/O kit",
    "IOHID": "HID I/O kit",
    "USBDevice": "USB device",
    "baudRate": "serial baud rate",
    "openPort": "serial port open",
    "/dev/tty": "serial device",
    "cu.usb": "USB serial device",
]

/// Package dependencies that would pull in a hardware/serial driver.
private let forbiddenDependencies = ["ORSSerialPort", "SwiftSerial", "SerialPortKit", "IOKit"]

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func swiftFiles(in package: String, root: URL) throws -> [URL] {
    let sources =
        root
        .appendingPathComponent("Packages", isDirectory: true)
        .appendingPathComponent(package, isDirectory: true)
        .appendingPathComponent("Sources", isDirectory: true)
    guard FileManager.default.fileExists(atPath: sources.path) else { return [] }
    return try FileManager.default.subpathsOfDirectory(atPath: sources.path)
        .filter { $0.hasSuffix(".swift") }
        .map { sources.appendingPathComponent($0) }
}

@Test func noHardwareSurfaceInAnyPackageSource() throws {
    let root = repositoryRoot()
    var findings: Set<String> = []
    for package in packageNames {
        for file in try swiftFiles(in: package, root: root) {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (signature, label) in hardwareSignatures where text.contains(signature) {
                let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
                findings.insert("\(relative): \(label)")
            }
        }
    }
    let unexpected = findings.subtracting(hardwareAllowList)
    #expect(
        unexpected.isEmpty,
        "Unexpected machine-hardware surface (allow-list is empty): \(unexpected.sorted())"
    )
}

@Test func noHardwareDriverDependencyInAnyManifest() throws {
    let root = repositoryRoot()
    var findings: Set<String> = []
    for package in packageNames {
        let manifest =
            root
            .appendingPathComponent("Packages", isDirectory: true)
            .appendingPathComponent(package, isDirectory: true)
            .appendingPathComponent("Package.swift")
        let text = try String(contentsOf: manifest, encoding: .utf8)
        for dependency in forbiddenDependencies where text.contains(dependency) {
            findings.insert("\(package): \(dependency)")
        }
    }
    let unexpected = findings.subtracting(hardwareAllowList)
    #expect(
        unexpected.isEmpty,
        "Unexpected hardware driver dependency (allow-list is empty): \(unexpected.sorted())"
    )
}
