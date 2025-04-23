//
//  CatchSystem.swift
//  FireFly
//
//  Created by 峰 on 2025/3/13.
//

import RealityKit
import RealityKitContent
import UIKit

class MutiSceneInstance {
    static let shared = MutiSceneInstance()
    var hasSceneStart: Bool = false
}

class CatchSystem : System {
    
    var leftHandEntity = Entity()
    var rightHandEntity = Entity()
    var orbEntity = Entity()
    var absorbParticleEntity = Entity()
    var haloParticleEntity = Entity()

    var sceneUpdateTimer: Timer? = nil
    
    let orbQuery = EntityQuery(where: .has(OrbComponent.self))
    let handQuery = EntityQuery(where: .has(HandTrackingComponent.self))

    let orbColors: [UIColor] = [.red, .green, .blue, .yellow, .cyan, .orange, .magenta]

    private var hasFoundOrb = false
    private var hasFoundHand = false
    private var isOrbPlaced = false
    private var hasStartedSceneUpdate = false
    private var hasStartedDisintegrate = false
    
    required init(scene: Scene) {
        if !MutiSceneInstance.shared.hasSceneStart {
            MutiSceneInstance.shared.hasSceneStart = true
            NotificationCenter.default.addObserver(self, selector: #selector(self.handleSceneUpdate), name: .init("SpaceTrackingManagerSceneUpdate"), object: nil)
        }
        Task {
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                if let absorbParticleEntity = immersiveContentEntity.findEntity(named: "AbsorbParticleEmitter") {
                    self.absorbParticleEntity = absorbParticleEntity
                }
                
                if let haloParticleEntity = immersiveContentEntity.findEntity(named: "HaloParticleEmitter") {
                    self.haloParticleEntity = haloParticleEntity
                }
                
                if let orbEntity = immersiveContentEntity.findEntity(named: "Orb") {
                    self.orbEntity = orbEntity
                    self.hasFoundOrb = true
                }
                
                self.changeColor()
            }
        }
    }
    
    func update(context: SceneUpdateContext) {
        guard self.hasFoundOrb else { return }
        
        self.findHandEntity(context: context)
        self.updateHandEntity()
        self.updateParticleEntity()
        self.checkHandAndOrbDistance()
    }
    
    func findHandEntity(context: SceneUpdateContext) {
        if !self.hasFoundHand {
            let handEntities = context.entities(matching: self.handQuery, updatingSystemWhen: .rendering)
            for handEntity in handEntities {
                guard let handComponent = handEntity.components[HandTrackingComponent.self] else { continue }
                if handComponent.chirality == .left {
                    self.leftHandEntity = handEntity
                } else if handComponent.chirality == .right {
                    self.rightHandEntity = handEntity
                }
            }
            self.hasFoundHand = true
        }
    }
    
    func changeColor() {
        var mat = self.orbEntity.components[ModelComponent.self]?.materials.first as! ShaderGraphMaterial
        do {
            let color = self.orbColors[Int.random(in: 0 ... (self.orbColors.count - 1))]
            try mat.setParameter(name: "EmissiveColor", value: .color(color))
            self.orbEntity.components[ModelComponent.self]?.materials = [mat]
            
            var haloParticleEmitterComponent = self.haloParticleEntity.components[ParticleEmitterComponent.self]!
            haloParticleEmitterComponent.mainEmitter.color = .constant(.single(color))
            self.haloParticleEntity.components[ParticleEmitterComponent.self] = haloParticleEmitterComponent
            
            var absorbParticleEmitterComponent = self.absorbParticleEntity.components[ParticleEmitterComponent.self]!
            absorbParticleEmitterComponent.mainEmitter.color = .constant(.single(color))
            self.absorbParticleEntity.components[ParticleEmitterComponent.self] = absorbParticleEmitterComponent
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func changeOrbDisintegrate(disintegrate: Float) {
        var mat = self.orbEntity.components[ModelComponent.self]?.materials.first as! ShaderGraphMaterial
        do {
            try mat.setParameter(name: "Disintegration", value: .float(disintegrate))
            self.orbEntity.components[ModelComponent.self]?.materials = [mat]
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func changeHaloSize(size: Float) {
        var particleEmitterComponent = self.haloParticleEntity.components[ParticleEmitterComponent.self]!
        particleEmitterComponent.mainEmitter.size = size
        self.haloParticleEntity.components[ParticleEmitterComponent.self] = particleEmitterComponent
    }
    
    @MainActor func updateHandEntity() {
        if let leftHandAnchor = SpaceTrackingManager.shared.leftHandAnchor {
            if let handSkeleton = leftHandAnchor.handSkeleton {
                let anchorFromJointTransform = handSkeleton.joint(.indexFingerTip).anchorFromJointTransform
                
                // Update the joint entity to match the transform of the person's hand joint.
                self.leftHandEntity.setTransformMatrix(
                    leftHandAnchor.originFromAnchorTransform * anchorFromJointTransform,
                    relativeTo: nil
                )
            }
        }
        
        if let rightHandAnchor = SpaceTrackingManager.shared.rightHandAnchor {
            if let handSkeleton = rightHandAnchor.handSkeleton {
                let anchorFromJointTransform = handSkeleton.joint(.indexFingerTip).anchorFromJointTransform
                
                // Update the joint entity to match the transform of the person's hand joint.
                self.rightHandEntity.setTransformMatrix(
                    rightHandAnchor.originFromAnchorTransform * anchorFromJointTransform,
                    relativeTo: nil
                )
            }
        }
    }
    
    func updateParticleEntity() {
        if var particleEmitter = self.absorbParticleEntity.components[ParticleEmitterComponent.self] {
            let pos = self.rightHandEntity.position(relativeTo: self.absorbParticleEntity)
            particleEmitter.mainEmitter.attractionCenter = pos
            self.absorbParticleEntity.components[ParticleEmitterComponent.self] = particleEmitter
        } else {
            fatalError("Cannot find particle emitter")
        }
    }
    
    @objc func handleSceneUpdate() {
        guard !self.hasStartedSceneUpdate else { return }
        self.hasStartedSceneUpdate = true
        self.sceneUpdateTimer?.invalidate()
        
        let timer = Timer(timeInterval: 2.0, repeats: false) { [weak self] _ in
                   
            Task {
                await MainActor.run { [weak self] in
                    self?.placeOrbIfNeeded()
                }
            }
            
            self?.sceneUpdateTimer?.invalidate()
            self?.sceneUpdateTimer = nil
            self?.hasStartedSceneUpdate = false
        }
        RunLoop.main.add(timer, forMode: .common)
        self.sceneUpdateTimer = timer
    }
    
    @MainActor func placeOrbIfNeeded() {
        guard let curDeviceTransform = SpaceTrackingManager.shared.curDeviceTransform else { return }
        
        if self.isOrbPlaced && !self.isSceneCollision(point: self.orbEntity.transform.translation, factor: 0.25) {
            return
        }
        
        var randomPoint = curDeviceTransform.translation
        
        repeat {
            randomPoint = curDeviceTransform.translation
            randomPoint += [
                Float.random(in: -1 ... 1),
                0,
                Float.random(in: -2 ... -1)
            ]
        } while self.isSceneCollision(point: randomPoint, factor: 0.1) || !self.isInCurrentRoom(position: randomPoint)
        
        self.orbEntity.setPosition(randomPoint, relativeTo: nil)
        self.changeColor()
        self.changeOrbDisintegrate(disintegrate: 0)
        self.changeHaloSize(size: 0.05)
        self.orbEntity.addChild(self.haloParticleEntity)
        SpaceTrackingManager.shared.setupRoot().addChild(self.orbEntity)
        self.isOrbPlaced = true
    }
    
    @MainActor func isSceneCollision(point: SIMD3<Float>, factor: Float) -> Bool {
        var res = true
        for (_, entity) in SpaceTrackingManager.shared.sceneEntities {
            guard let modeComponent = entity.components[ModelComponent.self] else { continue }
            let distance = modeComponent.mesh.bounds.distanceSquared(toPoint: point)
            if distance < factor {
                res = false
                break
            }
        }
        return res
    }
    
    @MainActor func isInCurrentRoom(position: SIMD3<Float>) -> Bool {
        guard let currentRoomAnchor = SpaceTrackingManager.shared.currentRoomAnchor else { return false }
        return currentRoomAnchor.contains(position)
    }
    
    func checkHandAndOrbDistance() {
        let orbPos = self.orbEntity.position(relativeTo: nil)

        guard orbPos != .zero, !self.hasStartedDisintegrate else { return }
        
        let pos = self.rightHandEntity.position(relativeTo: nil)
        let distance = distance(orbPos, pos)
        if distance > 0.1 {
            return
        }
                                
        // start the particle animation
        self.orbEntity.addChild(self.absorbParticleEntity)
                        
        // Animate the disintegration of the orb
        let frameRate: TimeInterval = 1.0/60.0 // 60FPS
        let duration: TimeInterval = 2
        let targetValue: Float = 1
        let haloTargetValue: Float = 0.05
        let totalFrames = Int(duration / frameRate)
        var currentFrame = 0
        var disintegrate: Float = 0
        
        Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true, block: { [weak self] timer in
            self?.hasStartedDisintegrate = true
            
            currentFrame += 1
            let progress = Float(currentFrame) / Float(totalFrames)
            
            disintegrate = progress * targetValue
            
            // set the parameter value and then assign the material back to the model component
            self?.changeOrbDisintegrate(disintegrate: disintegrate)
            
            self?.changeHaloSize(size: (1 - progress) * haloTargetValue)
            
            if currentFrame >= totalFrames {
                timer.invalidate()
                //Adding a delay for removal of orb so the particle system can live a little longer
                Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                    Task {
                        await MainActor.run { [weak self] in
                            guard let hasStartedDisintegrate = self?.hasStartedDisintegrate, hasStartedDisintegrate else { return }
                            
                            self?.absorbParticleEntity.removeFromParent()
                            self?.haloParticleEntity.removeFromParent()
                            self?.orbEntity.removeFromParent()
                            self?.isOrbPlaced = false
                            self?.placeOrbIfNeeded()
                            self?.hasStartedDisintegrate = false
                        }
                    }
                }
            }
        })
    }
}
