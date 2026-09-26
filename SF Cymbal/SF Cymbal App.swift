import ComposableArchitecture
import SwiftUI

@main
struct SFCymbalApp: App {
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        DocumentGroup(newDocument: ProjectDocument()) { file in
            DocumentEditorView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            AppCommands()
            UpdateCommands(updater: updater)
        }
        .defaultSize(width: 1120, height: 780)
        .windowResizability(.contentMinSize)
    }
}
