import AppKit
import Foundation

// Stop both the current identity and the legacy app during a rename update.
let applications = ["org.hackwestex.diskmetrics", "org.hackwestex.volumeguard"].flatMap {
    NSRunningApplication.runningApplications(withBundleIdentifier: $0)
}
for application in applications { _ = application.terminate() }
let deadline = Date().addingTimeInterval(10)
while applications.contains(where: { !$0.isTerminated }) && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
if applications.contains(where: { !$0.isTerminated }) {
    print("The storage app did not quit. Quit it from its menu, then run make update again. No app was replaced.")
    exit(1)
}
