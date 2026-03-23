import SwiftUI
import AppKit

@main
struct Novel_Writer_NativeApp: App {
    @StateObject private var model = NativeAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .background(WindowFrameAutosaveConfigurator())
        }
        .defaultSize(width: 1360, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Scene") {
                    model.createScene()
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])

                Button("New Chapter") {
                    model.createChapter()
                }
                .keyboardShortcut("N", modifiers: [.command, .option])
            }
        }
    }
}

struct WindowFrameAutosaveConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        AutosaveWindowProbeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class AutosaveWindowProbeView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        if window.frameAutosaveName != "NovelWriterNativeMainWindow" {
            window.setFrameAutosaveName("NovelWriterNativeMainWindow")
        }
    }
}
