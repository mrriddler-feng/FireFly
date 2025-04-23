//
//  FireFlyApp.swift
//  FireFly
//
//  Created by 峰 on 2025/3/12.
//

import SwiftUI
import RealityKitContent

@main
struct FireFlyApp: App {

    @State private var appModel = AppModel()
    
    init() {
        CatchSystem.registerSystem()
        OrbComponent.registerComponent()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
