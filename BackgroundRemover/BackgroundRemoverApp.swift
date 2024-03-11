//BackgroundRemoverApp.swift

import SwiftUI

@main
struct BackgroundRemoverApp: App {

    /// A pipeline to define as an environment object.
    @StateObject private var pipeline = EffectsPipeline()
    @StateObject private var gifProcessor = GIFProcessor()

    /// A scene for the app's main window group.
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pipeline)
                .environmentObject(gifProcessor)
        }
    }
}
