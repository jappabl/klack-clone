import Foundation

/// Where the measurement flags write their output.
///
/// Only the harness uses these — `--sound-test`, `--settings-shot`, the floor
/// runs and the ScreenCaptureKit dumps. The shipping app never writes here.
enum Paths {

    /// Walk up from the executable until something looks like the working
    /// tree, so the harness runs from any checkout rather than from one
    /// author's home directory. Falls back to the working directory when the
    /// app is installed and the tree is nowhere above it.
    static let repoRoot: URL = {
        var d = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        for _ in 0..<8 {
            d.deleteLastPathComponent()
            if FileManager.default.fileExists(
                atPath: d.appendingPathComponent("app/Sources").path) { return d }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }()

    static func shots(_ name: String) -> URL {
        let d = repoRoot.appendingPathComponent("shots")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent(name)
    }
}
