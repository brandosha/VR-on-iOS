//
//  VRViewController.swift
//  VR on iOS
//
//  Created by Brandon on 6/20/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import SceneKit
import ARKit
import UIKit
import Darwin

/// The `UIViewController` that manages displaying the VR content on the device
class VRViewController: UIViewController, ARSessionDelegate, SCNSceneRendererDelegate {
    
    @IBOutlet var vrView: UIView!
    
    let session = ARSession()
    private var arDelegate: ARSeparateDelegateClass!
    
    /// The `VRScene`s that can be displayed in VR
    var scenes: [String:VRScene] = [:] {
        
        didSet {
            
            for data in scenes {
                
                if mainScene.rootNode.childNode(withName: data.key, recursively: false) != nil {
                    
                    continue
                    
                } else {
                    
                    let newSceneRoot = data.value.rootNode
                    
                    for sceneNode in data.value.scene.rootNode.childNodes {
                        
                        newSceneRoot.addChildNode(sceneNode)
                        
                    }
                    
                    newSceneRoot.isHidden = false
                    newSceneRoot.name = data.key
                    
                    data.value.setup()
                    
                    mainScene.rootNode.addChildNode(newSceneRoot)
                    
                }
                
            }
            
        }
        
    }
    
    private var mainScene = SCNScene()
    
    /// The main scene that contains all of the `VRScene`s in  the `scenes` variable
    var scene: SCNScene {
        
        return mainScene
        
    }
    
    private var sceneViewL: SCNView!
    private var sceneViewR: SCNView!
    private var externalSceneView: SCNView?
    
    private var sizeConstraints: [String: CGFloat]!
    
    /// The `ARSSCNView` that the `VRViewController` retrieves world tracking data from
    let ARView = ARSCNView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    
    private var _mainCameraNode = SCNNode()
    
    /// The main camera, use this node to determine the position of the user in the world
    var mainCameraNode: SCNNode {
        
        return _mainCameraNode
        
    }
    
    /// The origin of the world that the `mainCameraNode` is attached to, when `clampSceneToFloor` is `true` avoid changing the y position of this node
    var mainPointOfView = SCNNode()
    
    private var tooFarFromOriginNode = SCNNode()
    
    /// Determines the size of one unit in 3D scene files, calculated by one meter divided by this number ex. `multiplier = 100` makes one unit equal to one centemeter in real world space while `multiplier = 1` (default) makes one unit equal to one meter
    var multiplier: Float = 1 {
        
        didSet {
            
            if multiplier != 39.37 && multiplier != 1 {
                
                measurmentType = .other
                
            }
            
        }
        
    }
    
    /// Determines the size of one unit in 3D scene files
    ///
    /// - meters: One unit equals one meter in real world space
    /// - inches: One unit equals one inch in real world space
    /// - other: this should not be set except by the `multiplier` variable's `didSet`
    enum systemOfMeasurment: Float {
        
        case meters = 1
        case inches = 39.37
        case other = 0
        
    }
    
    /// Determines the size of one unit in 3D scene files ex. `measurmentType = .inches` makes one unit equal to one inch in real world space
    var measurmentType: systemOfMeasurment = .meters {
        
        willSet {
            
            if newValue.rawValue != 0 {
                
                multiplier = newValue.rawValue
                
            }
            
            let tooFarFromOriginTube = SCNCylinder(radius: CGFloat(1 * multiplier), height: CGFloat(5 * multiplier))
            tooFarFromOriginTube.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.925490200519562, green: 0.235294118523598, blue: 0.10196078568697, alpha: 1.0)
            tooFarFromOriginTube.firstMaterial?.isDoubleSided = true
            
            tooFarFromOriginNode = SCNNode(geometry: tooFarFromOriginTube)
            tooFarFromOriginNode.name = "tooFarFromOriginNode"
            tooFarFromOriginNode.opacity = 0
            tooFarFromOriginNode.position = SCNVector3(0, 0, 0)
            tooFarFromOriginNode.castsShadow = false
            
            mainPointOfView.replaceChildNode(mainPointOfView.childNode(withName: "tooFarFromOriginNode", recursively: false)!, with: tooFarFromOriginNode)
            
            sceneViewR.pointOfView?.position = SCNVector3(0.05 * multiplier, 0, 0.075 * multiplier)
            sceneViewR.pointOfView?.camera?.zNear = Double(0.03 * multiplier)
            sceneViewR.pointOfView?.camera?.zFar = Double(10 * multiplier)
            
            sceneViewL.pointOfView?.position = SCNVector3(-0.05 * multiplier, 0, 0.075 * multiplier)
            sceneViewL.pointOfView?.camera?.zNear = Double(0.03 * multiplier)
            sceneViewL.pointOfView?.camera?.zFar = Double(10 * multiplier)
            
            _mainCameraNode.camera?.zNear = Double(0.05 * multiplier)
            _mainCameraNode.camera?.zFar = Double(10 * multiplier)
            
            _mainCameraNode.position.x *= multiplier
            _mainCameraNode.position.y *= multiplier
            _mainCameraNode.position.z *= multiplier
            
            if let imgNode = imageNode {
                
                imgNode.position.x = referenceImageAnchor.transform.columns.3.x * multiplier
                imgNode.position.y = referenceImageAnchor.transform.columns.3.y * multiplier
                imgNode.position.z = referenceImageAnchor.transform.columns.3.z * multiplier
                
                imgNode.scale = SCNVector3(multiplier, multiplier, multiplier)
                
            }
            
        }
        
    }
    
    /// Controls wether or not the user can interact with the scene, user interacts by tapping on the screen
    var interactive: Bool = false {
        
        didSet {
            
            if interactive == true {
                
                let rViewCenter = CGPoint(x: sizeConstraints["window width"]! / 2, y: sizeConstraints["height"]! / 2)
                
                DispatchQueue.main.async {
                    
                    let circleViewR = UIView(frame: CGRect(x: rViewCenter.x - 2, y: rViewCenter.y - 2, width: 4, height: 4))
                    circleViewR.tag = 1
                    circleViewR.backgroundColor = UIColor.white
                    circleViewR.layer.borderColor = UIColor.black.cgColor
                    circleViewR.layer.borderWidth = 1
                    
                    self.sceneViewR.addSubview(circleViewR)
                    self.sceneViewR.bringSubviewToFront(circleViewR)
                    
                }
                
                DispatchQueue.main.async {
                    
                    self.vrView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapRecognizer)))
                    
                }
                
            } else {
                
                for view in vrView.subviews {
                    
                    if view.tag == 1 {
                        
                        view.removeFromSuperview()
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    @objc func tapRecognizer() {
        
        guard let userNode = currentLookAtObject else {
            
            return
            
        }
        
        guard let userPos = currentLookAtPoint else {
            
            return
            
        }
        
        userTapped(lookingAt: userNode, lookingAt: userPos)
        
    }
    
    /// The `VRObject` that the user is currently holding
    var holdingObject: VRObject?
    
    
    /// This function gets called whenever the user taps on the screen
    ///
    /// - Parameters:
    ///   - object: The object that the user is currently looking at
    ///   - position: The point in the currently displayed `VRScene` that the user is looking at
    func userTapped(lookingAt object: VRObject, lookingAt position: SCNVector3) {
        
        if holdingObject == nil && object.type != .static {
            
            let taken = object.take()
            
            if taken {
                
                holdingObject = object
                
            }
            
        } else if holdingObject == object {
            
            let replaced = object.replace()
            
            if !replaced {
                
                holdingObject = nil
                
            }
            
        } else if holdingObject != nil {
            
            _ = holdingObject!.use(on: object)
            
        } else {
            
            _ = object.use(on: object)
            
        }
        
    }
    
    /// Set this value to true if you would like to overlay the virtual scene over the real world
    var ARMode: Bool = false
    
    /// Set this value to true if you would like the bottom of the scene to be automatically placed on the ground
    var clampSceneToFloor: Bool = false {
        
        didSet {
            
            if clampSceneToFloor {
                
                if let newFloorYPos = floorPlaneAnchor?.transform.columns.3.y {
                    
                    mainPointOfView.position.y = -newFloorYPos * multiplier
                    
                }
                
            }
            
        }
        
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool { get{ return true } }
    
    override func loadView(){
        
        super.loadView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(VRViewController.didConnectToExternalDisplay), name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(VRViewController.didDisconnectFromExternalDisplay), name: UIScreen.didDisconnectNotification, object: nil)
        
        if UIScreen.screens.count > 1 {
            
            didConnectToExternalDisplay()
            
        }
        
        vrView = UIView()
        
        vrView.setNeedsLayout()
        vrView.layoutIfNeeded()
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let vrWindowWidth = (screenWidth - 8) / 2
        
        sizeConstraints = ["width": screenWidth, "height": screenHeight, "window width": vrWindowWidth]
        
        let lFrame = CGRect(x: 0, y: 0, width: vrWindowWidth, height: screenHeight)
        let rFrame = CGRect(x: vrWindowWidth + 4, y: 0, width: vrWindowWidth, height: screenHeight)
        
        sceneViewL = SCNView(frame: lFrame)
        sceneViewR = SCNView(frame: rFrame)
        
        sceneViewL.backgroundColor = UIColor.black
        sceneViewR.backgroundColor = UIColor.black
        
        sceneViewL.scene = mainScene
        sceneViewR.scene = mainScene
        
        sceneViewL.autoenablesDefaultLighting = true
        sceneViewR.autoenablesDefaultLighting = true
        
        let leftCam = SCNNode()
        leftCam.camera = SCNCamera()
        leftCam.camera?.zNear = Double(0.05 * multiplier)
        leftCam.camera?.zFar = Double(10 * multiplier)
        leftCam.position = SCNVector3(-0.75, 0, 2)
        
        let rightCam = SCNNode()
        rightCam.camera = SCNCamera()
        rightCam.camera?.zNear = Double(0.05 * multiplier)
        rightCam.camera?.zFar = Double(10 * multiplier)
        rightCam.position = SCNVector3(0.75, 0, 2)
        
        _mainCameraNode.addChildNode(leftCam)
        _mainCameraNode.addChildNode(rightCam)
        
        _mainCameraNode.camera = SCNCamera()
        _mainCameraNode.camera?.zNear = Double(0.05 * multiplier)
        _mainCameraNode.camera?.zFar = Double(10 * multiplier)
        
        mainScene.rootNode.addChildNode(mainPointOfView)
        mainPointOfView.addChildNode(_mainCameraNode)
        
        sceneViewL.pointOfView = leftCam
        sceneViewR.pointOfView = rightCam
        
        sceneViewL.delegate = self
        
        ARView.session = session
        
        arDelegate = ARSeparateDelegateClass(self)
        ARView.delegate = arDelegate
        
        self.view = vrView
        
        self.view.addSubview(sceneViewL)
        self.view.addSubview(sceneViewR)
        
        self.view.addSubview(ARView)
        vrView.sendSubviewToBack(ARView)
        
        sceneViewL.preferredFramesPerSecond = 60
        sceneViewR.preferredFramesPerSecond = 60
        
        // ARView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        // sceneViewL.showsStatistics = true
        // sceneViewR.showsStatistics = true
        
        let tooFarFromOriginTube = SCNTube(innerRadius: CGFloat(0.8 * multiplier), outerRadius: CGFloat(0.9 * multiplier), height: CGFloat(5 * multiplier))
        tooFarFromOriginTube.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.925490200519562, green: 0.235294118523598, blue: 0.10196078568697, alpha: 1.0)
        
        tooFarFromOriginNode = SCNNode(geometry: tooFarFromOriginTube)
        tooFarFromOriginNode.name = "tooFarFromOriginNode"
        tooFarFromOriginNode.opacity = 0
        tooFarFromOriginNode.position = SCNVector3(0, 0, 0)
        
        mainPointOfView.addChildNode(tooFarFromOriginNode)
        
        sceneViewL.isPlaying = true
        sceneViewR.isPlaying = true
        
        setUpTechniques()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        let config = setUpConfig()
        
        session.delegate = self
        session.run(config, options: [.removeExistingAnchors, .resetTracking])
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        session.pause()
        
    }
    
    func setUpTechniques() {
        
        if let path = Bundle.main.path(forResource: "NodeTechnique", ofType: "plist") {
            
            if let dict = NSDictionary(contentsOfFile: path)  {
                
                let dict2 = dict as! [String : AnyObject]
                let technique = SCNTechnique(dictionary:dict2)
                
                sceneViewR.technique = technique
                sceneViewL.technique = technique
                externalSceneView?.technique = technique
                
            }
            
        }
        
    }
    
    func setUpConfig() -> ARWorldTrackingConfiguration {
        
        let config = ARWorldTrackingConfiguration()
        
        config.planeDetection = .horizontal
        
        config.isAutoFocusEnabled = false
        config.isLightEstimationEnabled = false
        config.worldAlignment = .gravity
        config.providesAudioData = false
        
        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            
            config.detectionImages = referenceImages
            
        }
        
        return config
        
    }
    
    var currentDistance: Float {
        
        let pos = _mainCameraNode.position
        
        let distance = sqrt((pos.x * pos.x) + (pos.y * pos.y))
        
        return distance
        
    }
    
    private var recentLookAtPointDistances: [Float] = []
    private var currentLookAtObject: VRObject?
    private var currentLookAtPoint: SCNVector3?
    
    var safetyNet = false
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if(Int(time.truncatingRemainder(dividingBy: 4)) == 0) {
            
            if currentDistance / multiplier > 0.7 && !ARMode && tooFarFromOriginNode.opacity < 0.5 && safetyNet {
                
                tooFarFromOriginNode.isHidden = false
                
                tooFarFromOriginNode.runAction(SCNAction.fadeOpacity(to: 0.5, duration: 0.1))
                
            } else if(tooFarFromOriginNode.opacity > 0) {
                
                tooFarFromOriginNode.runAction(SCNAction.fadeOpacity(to: 0, duration: 0.3)) {
                    
                    self.tooFarFromOriginNode.isHidden = true
                    
                }
                
            }
            
            self.sceneViewL.isPlaying = true
            self.sceneViewR.isPlaying = true
            
            self.externalSceneView?.isPlaying = true
            
        }
        
        if interactive {
            
            var center = CGPoint()
            
            DispatchQueue.main.async {
                
                center = CGPoint(x: self.sceneViewR.frame.width / 2, y: self.sceneViewR.frame.height / 2)
                
            }
            
            let hitTestResults = sceneViewR.hitTest(center, options: [:])
            
            if hitTestResults.count > 0 {
                
                let resultNode = hitTestResults[0].node
                
                if let object = resultNode as? VRObject {
                    
                    if object.findable {
                        
                        currentLookAtObject?.setHighlighted(to: false)
                        resultNode.setHighlighted(to: true)
                        currentLookAtObject = object
                        
                    }
                    
                }
                
                currentLookAtPoint = hitTestResults[0].worldCoordinates
                
            }
            
        }
        
        _mainCameraNode.eulerAngles = ARView.pointOfView!.eulerAngles
        
        _mainCameraNode.position.x = ARView.pointOfView!.worldPosition.x * multiplier
        _mainCameraNode.position.y = ARView.pointOfView!.worldPosition.y * multiplier
        _mainCameraNode.position.z = ARView.pointOfView!.worldPosition.z * multiplier
        
    }
    
    private var referenceImageAnchor: ARImageAnchor!
    private var floorPlaneAnchor: ARPlaneAnchor?
    
    private var imageNode: SCNNode!
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
        for anchor in anchors {
            
            if let imageAnchor = anchor as? ARImageAnchor {
                
                referenceImageAnchor = imageAnchor
                
                let referenceImage = imageAnchor.referenceImage
                
                let sphere = SCNSphere(radius: (referenceImage.physicalSize.width / 2) * CGFloat(multiplier))
                sphere.firstMaterial?.diffuse.contents = UIColor.red
                sphere.firstMaterial?.isDoubleSided = true
                
                imageNode = SCNNode(geometry: sphere)
                imageNode.opacity = 1
                imageNode.name = "image_node"
                
                if let node = ARView.node(for: anchor) {
                    
                    imageNode.eulerAngles = node.eulerAngles
                    
                }
                
                let pos = anchor.transform.columns.3
                
                imageNode.position = SCNVector3(pos.x * multiplier, pos.y * multiplier, pos.z * multiplier)
                
                imageNode.scale = SCNVector3(multiplier, multiplier, multiplier)
                
                mainPointOfView.addChildNode(imageNode)
                
            }
            
            if !clampSceneToFloor {
                
                return
                
            }
            
            guard let planeAnchor = anchor as? ARPlaneAnchor else {
                
                return
                
            }
            
            var currentFloorYPos: Float = 0
            
            if let anchorYPos = floorPlaneAnchor?.transform.columns.3.y {
                
                currentFloorYPos = anchorYPos
                
            }
            
            let floorYPos = anchor.transform.columns.3.y
            
            if floorYPos < currentFloorYPos {
                
                mainPointOfView.position.y = -floorYPos * multiplier
                
                floorPlaneAnchor = planeAnchor
                
            }
            
        }
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        guard let anchor = referenceImageAnchor else {
            
            return
            
        }
        
        guard let node = ARView.node(for: anchor) else {
            
            return
            
        }
        
        let imagePos = SCNVector3(
            (node.position.x) * multiplier,
            (node.position.y) * multiplier,
            (node.position.z) * multiplier
        )
        
        imageNode.position = imagePos
        
        imageNode.eulerAngles.x = node.eulerAngles.x
        imageNode.eulerAngles.y = node.eulerAngles.y
        imageNode.eulerAngles.z = node.eulerAngles.z
        
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
        for anchor in anchors {
            
            if anchor === floorPlaneAnchor && clampSceneToFloor {
                
                let newFloorYPos = anchor.transform.columns.3.y
                
                mainPointOfView.position.y = -newFloorYPos * multiplier
                
            }
            
        }
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
        var errorStr = "\(error)"
        
        let openSettings: ((UIAlertAction) -> Void)? = { (_) -> Void in
            
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                
                return
                
            }
            
            if UIApplication.shared.canOpenURL(settingsUrl) {
                
                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                    
                    //  print("Settings opened: \(success)")
                    
                })
            }
            
        }
        
        var shouldOpenSettings = false
        
        if let arError = error as? ARError {
            
            switch arError.code {
                
            case .cameraUnauthorized:
                
                errorStr = "Permission to use the device's camera has been denied."
                
                shouldOpenSettings = true
                
            case .microphoneUnauthorized:
                
                errorStr = "Permission to use the device's microphone has been denied."
                
                shouldOpenSettings = true
                
            case .unsupportedConfiguration:
                
                errorStr = "The AR Session Configuration is not supported by the current device."
                
                shouldOpenSettings = false
                
            case .sensorUnavailable:
                
                errorStr = "A sensor required to run the session is not available."
                
                shouldOpenSettings = false
                
            case .sensorFailed:
                
                errorStr = "A sensor failed to provide the required input."
                
                shouldOpenSettings = false
                
            default:
                
                errorStr = "An unknown error occured while attempting to run the AR Session."
                
                shouldOpenSettings = false
                
            }
            
        }
        
        let alert = UIAlertController(title: "ARKit Encountered An Error", message: errorStr, preferredStyle: .alert)
        
        if shouldOpenSettings {
            
            alert.addAction(UIAlertAction(title: "Settings", style: .cancel, handler: openSettings))
            
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default){ action in exit(0) })
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    
    /// Use this function to display one of the `VRScene`s in the `scenes` array
    ///
    /// - Parameter named: The key that points to the `VRScene` in the `scenes` array that you would like to display
    func displayScene(_ named: String) {
        
        guard let newScene = scenes[named] else {
            
            return
            
        }
        
        currentLookAtObject?.setHighlighted(to: false)
        
        currentLookAtObject = nil
        currentLookAtPoint = nil
        
        for sceneData in scenes {
            
            if sceneData.value.rootNode !== newScene.rootNode {
                
                sceneData.value.rootNode.isHidden = true
                
            } else {
                
                newScene.switchSceneSetup()
                
                sceneData.value.rootNode.isHidden = false
                
            }
            
        }
        
        if clampSceneToFloor == true {
            
            clampSceneToFloor = true
            
        }
        
    }
    
    private var externalWindow: UIWindow!
    
    @objc func didConnectToExternalDisplay() {
        
        if let externalScreen = UIScreen.screens.last {
            
            externalWindow = UIWindow(frame: externalScreen.bounds)
            
            let externalVC = UIViewController()
            externalWindow.rootViewController = externalVC
            
            externalWindow.screen = externalScreen
            
            let externalScreenView = UIView(frame: externalWindow.frame)
            externalWindow.addSubview(externalScreenView)
            
            externalWindow.isHidden = false
            
            externalSceneView = SCNView(frame: externalWindow.frame)
            externalSceneView!.scene = mainScene
            externalSceneView!.pointOfView = _mainCameraNode
            
            externalScreenView.addSubview(externalSceneView!)
            
            externalScreen.overscanCompensation = UIScreen.OverscanCompensation(rawValue: 3)!
            
        }
        
    }
    
    @objc func didDisconnectFromExternalDisplay() {
        
        externalWindow.isHidden = true
        externalWindow = nil
        externalSceneView = nil
        
    }
    
}
