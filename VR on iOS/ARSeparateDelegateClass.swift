//
//  ARSeparateDelegateClass.swift
//  VR on iOS
//
//  Created by Brandon on 9/11/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation
import ARKit

class ARSeparateDelegateClass: NSObject, ARSCNViewDelegate {
    
    var current: VRViewController
    
    init(_ current: VRViewController) {
        
        self.current = current
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if current.ARMode {
            
            current.scene.background.contents = current.ARView.scene.background.contents
            
        }
        
    }
    
}
