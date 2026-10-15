import SpriteKit
import SwiftUI

@main
struct AnagrammatonApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

/// Hosts the SpriteKit scene full screen. The scene is laid out on a
/// 720-unit-wide canvas whose height follows the device's aspect ratio.
struct GameView: View {
    @State private var scene: GameScene?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.114, green: 0.141, blue: 0.2)
                if let scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                if scene == nil {
                    scene = GameScene.make(safeSize: geo.size, insets: geo.safeAreaInsets)
                }
            }
        }
        .persistentSystemOverlays(.hidden)
    }
}
