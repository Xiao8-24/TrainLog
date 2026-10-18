"""Preview the unmodified selection view without launch-time navigation."""
from pathlib import Path
import difflib
path = Path("TrainLogWatch/TrainLogWatchApp.swift")
original = path.read_text()
anchor = "WindowGroup { WatchWorkoutView() }"
assert original.count(anchor) == 1
replacement = "WindowGroup { WatchPreviewHost() }"
preview = """
// QA-only host; never included in the published app or release sources.
private struct WatchPreviewHost: View {
    @State private var selection: CardioActivity = .outdoorRun
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--snapshot-activities") {
            NavigationStack { WatchActivitySelection(selection: $selection) }
        } else {
            WatchWorkoutView()
        }
    }
}
"""
updated = original.replace(anchor, replacement) + preview
# Actual list implementation and bindings remain byte-for-byte unchanged.
assert original[original.index("private struct WatchActivitySelection"):].strip() in updated
path.write_text(updated)
Path("artifacts/watch/preview-host.diff").write_text("".join(difflib.unified_diff(original.splitlines(True), updated.splitlines(True), fromfile="released-app", tofile="qa-only-preview-host")))
