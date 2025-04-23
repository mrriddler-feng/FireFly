//
//  ImmersiveView.swift
//  FireFly
//
//  Created by 峰 on 2025/3/12.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)

                if let orb = immersiveContentEntity.findEntity(named: "Orb") {
                    orb.removeFromParent()
                }
                if let haloParticleEmitter = immersiveContentEntity.findEntity(named: "HaloParticleEmitter") {
                    haloParticleEmitter.removeFromParent()
                }
                // Put skybox here.  See example in World project available at
                // https://developer.apple.com/
            }
            
            self.makeHandEntities(in: content)
            content.add(SpaceTrackingManager.shared.setupRoot())
            SpaceTrackingManager.shared.trackDevice()
        }
        .onDisappear() {
            SpaceTrackingManager.shared.stopTrackDevice()
        }
        .task {
            await SpaceTrackingManager.shared.runARKitSession()
        }
        .task {
            await SpaceTrackingManager.shared.monitorSessionEvent()
        }
        .task {
            await SpaceTrackingManager.shared.processHandTrackingUpdate()
        }
        .task {
            await SpaceTrackingManager.shared.processSceneTrackingUpdate()
        }
    }
    
    /// Creates the entity that contains all hand-tracking entities.
    @MainActor
    func makeHandEntities(in content: any RealityViewContentProtocol) {
        // Add the left hand.
        let leftHand = Entity()
        leftHand.components.set(HandTrackingComponent(chirality: .left))
        content.add(leftHand)

        // Add the right hand.
        let rightHand = Entity()
        rightHand.components.set(HandTrackingComponent(chirality: .right))
        content.add(rightHand)
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
