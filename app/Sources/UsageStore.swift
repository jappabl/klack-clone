import Foundation

/// Usage tracking behind the Stats pane.
///
/// The metrics, their names and their grouping are sourced — the developer's
/// own Raycast extension reads Klack's stats and shows exactly this shape
/// (Keystrokes / Dings / Clicks, then Favourite Switches ranked by count, under
/// a "Tracking since <date>" line). What is not sourced is how Klack persists
/// them, so this uses a plain JSON file.
final class UsageStore {

    static let shared = UsageStore()

    private(set) var keystrokes = 0
    private(set) var dings = 0
    private(set) var clicks = 0
    private(set) var perSwitch: [String: Int] = [:]
    private(set) var since = Date()

    private let url: URL
    private var dirty = false
    private var timer: Timer?

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("KlackClone", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("usage.json")
        load()
        // Counting happens on every keystroke; writing does not. Flush on a
        // timer and on termination instead.
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.flush()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NSApplicationWillTerminateNotification"),
                                               object: nil, queue: .main) { [weak self] _ in
            self?.flush()
        }
    }

    // MARK: counting

    func countKeystroke(switchName: String) {
        keystrokes += 1
        perSwitch[switchName, default: 0] += 1
        dirty = true
    }
    func countDing()  { dings += 1;  dirty = true }
    func countClick() { clicks += 1; dirty = true }

    /// Used by --stats-verify to reproduce the reference numbers for the
    /// geometry check without touching the user's real counts.
    func seed(keystrokes k: Int, dings d: Int, clicks c: Int,
              perSwitch p: [String: Int], since s: Date) {
        keystrokes = k; dings = d; clicks = c; perSwitch = p; since = s; dirty = false
    }

    func reset() {
        keystrokes = 0; dings = 0; clicks = 0; perSwitch = [:]; since = Date()
        dirty = true; flush()
    }

    // MARK: presentation, matching the Raycast extension's formatting

    static let fmt: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = ","
        return f
    }()
    private func str(_ n: Int) -> String {
        n == 0 ? "—" : (UsageStore.fmt.string(from: NSNumber(value: n)) ?? "\(n)")
    }
    var keystrokesText: String { str(keystrokes) }
    var dingsText: String      { str(dings) }
    var clicksText: String     { str(clicks) }
    var sinceText: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return "Tracking since \(f.string(from: since))"
    }
    /// Ranked, highest first — "Favourite Switches".
    var favourites: [(name: String, count: Int)] {
        perSwitch.filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }
    func countText(_ n: Int) -> String { str(n) }

    // MARK: persistence

    private struct Blob: Codable {
        var keystrokes: Int; var dings: Int; var clicks: Int
        var perSwitch: [String: Int]; var since: Date
    }

    private func load() {
        guard let d = try? Data(contentsOf: url),
              let b = try? JSONDecoder().decode(Blob.self, from: d) else { return }
        keystrokes = b.keystrokes; dings = b.dings; clicks = b.clicks
        perSwitch = b.perSwitch; since = b.since
    }

    func flush() {
        guard dirty else { return }
        let b = Blob(keystrokes: keystrokes, dings: dings, clicks: clicks,
                     perSwitch: perSwitch, since: since)
        if let d = try? JSONEncoder().encode(b) { try? d.write(to: url, options: .atomic) }
        dirty = false
    }

    var path: String { url.path }
}
