//
//  SpaceTrackingManager.swift
//  FireFly
//
//  Created by 峰 on 2025/2/28.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
class SpaceTrackingManager {
    
    static let shared = SpaceTrackingManager()
    
    let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let sceneTracking = SceneReconstructionProvider()
    private let worldTracking = WorldTrackingProvider()
    private let roomTracking = RoomTrackingProvider()

    private var updateDeviceTask: Task<Void, Never>? = nil

    private let contentRoot = Entity()
    var sceneEntities = [UUID: Entity]()
    
    var leftHandAnchor: HandAnchor?
    var rightHandAnchor: HandAnchor?
    
    var currentRoomAnchor: RoomAnchor? { roomTracking.currentRoomAnchor }
    
    var curDeviceTransform: Transform?
    
    func runARKitSession() async {
        do {
            try await self.session.run([self.worldTracking, self.sceneTracking, self.handTracking, self.roomTracking])
        } catch {
            print("error starting arkit session: \(error.localizedDescription)")
        }
    }
    
    func monitorSessionEvent() async {
        for await event in self.session.events {
            switch event {
            case .authorizationChanged(type: _, status: let status):
                print("Authorization changed to: \(status)")
                
                if status == .denied {
                    print("ARKit authorization is denied by the user")
                }
            case .dataProviderStateChanged(dataProviders: let providers, newState: let state, error: let error):
                print("Data provider changed: \(providers), \(state)")
                if let error {
                    print("Data provider reached an error state: \(error)")
                }
            default:
                fatalError("Unhandled new event type \(event)")
            }
        }
    }
    
    func processHandTrackingUpdate() async {
        for await update in self.handTracking.anchorUpdates {
            switch update.anchor.chirality {
            case .left:
                self.leftHandAnchor = update.anchor
            case .right:
                self.rightHandAnchor = update.anchor
            }
        }
    }
    
    func processSceneTrackingUpdate() async {
        guard SceneReconstructionProvider.isSupported else {
            print("SceneReconstructionProvider is not supported on this device.")
            return
        }

        for await update in self.sceneTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                let entity = self.sceneEntities[update.anchor.id] ?? {
                    let entity = Entity()
                    self.contentRoot.addChild(entity)
                    self.sceneEntities[update.anchor.id] = entity
                    return entity
                }()
                                
                var material = UnlitMaterial(color: .red)
                material.blending = .transparent(opacity: .init(floatLiteral: 0))
                
                guard let mesh = try? await MeshResource(from: update.anchor) else { return }
                entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
                entity.setTransformMatrix(update.anchor.originFromAnchorTransform, relativeTo: nil)
                
                NotificationCenter.default.post(name: .init("SpaceTrackingManagerSceneUpdate"), object: nil)
            case .removed:
                if let entity = self.sceneEntities[update.anchor.id] {
                    entity.removeFromParent()
                    self.sceneEntities.removeValue(forKey: update.anchor.id)
                }
            }
        }
    }
    
    func updateCurrentDevice() {
        let deviceAnchor = self.worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        guard let deviceAnchor, deviceAnchor.isTracked == true else {
            return
        }
        self.curDeviceTransform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
    }
    
    func setupRoot() -> Entity {
        self.contentRoot
    }

    func trackDevice() {
        self.stopTrackDevice()
        self.updateDeviceTask = self.run(self.updateCurrentDevice, withFrequency: 10)
    }
    
    func stopTrackDevice() {
        self.updateDeviceTask?.cancel()
    }
    
    /// Runs a given function at an approximate frequency.
    func run(_ function: @escaping () -> Void, withFrequency freqHz: UInt64) -> Task<Void, Never> {
        return Task {
            while true {
                if Task.isCancelled {
                    return
                }
                
                // Sleeps for 1 s / Hz before calling the function.
                let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / freqHz
                do {
                    try await Task.sleep(nanoseconds: nanoSecondsToSleep)
                } catch {
                    // Sleep fails when the Task is in a canceled state. Exit the loop.
                    return
                }
                
                function()
            }
        }
    }
}
