//
//  HandTrackingComponent.swift
//  FireFly
//
//  Created by 峰 on 2025/3/13.
//

import RealityKit

struct HandTrackingComponent: Component {
    /// The chirality for the hand this component tracks.
    let chirality: AnchoringComponent.Target.Chirality
    
    /// Creates a new hand-tracking component.
    /// - Parameter chirality: The chirality of the hand target.
    init(chirality: AnchoringComponent.Target.Chirality) {
        self.chirality = chirality
    }
}
