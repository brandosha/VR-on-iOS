//
//  VRScene.swift
//  VR on iOS
//
//  Created by Brandon on 8/14/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation
import SceneKit

protocol VRScene {
    
    /// The scene that diplays the value
    var scene: SCNScene { get set }
    
    /// Use current to allow your scene to access other varibles within the same view controller
    /// :param: current: the view controller that you are initializing the scene in
    init(_ current: VRViewController)
    
    /// Define different VRObjects and their functions
    func setup()
    
    /// Define what happens before the scene is diplayed
    func switchSceneSetup()
    
}
