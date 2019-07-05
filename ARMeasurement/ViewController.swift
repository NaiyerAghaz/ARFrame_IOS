//
//  ViewController.swift
//  ARMeasurement
//
//  Created by Naiyer on 05/07/19.
//  Copyright © 2019 Naiyer. All rights reserved.
//

import UIKit
import ARKit
import ARMeasure

class ViewController: UIViewController {
    @IBOutlet var measurementLbl: [UILabel]!
    @IBOutlet weak var unitHolder: UIView!
    
    @IBOutlet weak var AugmentedRealityView: ARSCNView!
    var augmentedrealitySession = ARSession()
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var sessionLabelView: UIView!
    var configuration = ARWorldTrackingConfiguration()
    // all flags
    var placeOnPlane = false
    var showFeaturePoints = false
    //6. Create A Variable Which Determines Whether The User Wants To Join The Last & First Markers Together
    var joiningNodes = false
    //create all nodes
    var nodesAdded = [SCNNode]()
    var angleNodes = [SCNNode]()
    var distanceNodes = [SCNNode]()
    var lineNodes = [SCNNode]()
    //Settings Menu
    var settingsMenuShown = false
    var showDistanceLabels = true
    var showAngleLabels = false
    var placementType: ARHitTestResult.ResultType = .featurePoint
    @IBOutlet weak var planeDetections: UISegmentedControl!
    
    @IBAction func setPlaneDetectionTapped(_ control: UISegmentedControl) {
        print("indexx=", control.selectedSegmentIndex)
        if control.selectedSegmentIndex == 1 { placeOnPlane = false} else { placeOnPlane = true}
        setupSessionPreferences()
    }
    
    @IBOutlet weak var featurePoints: UISegmentedControl!
    
    @IBAction func setFeaturePointsTapped(_ control: UISegmentedControl) {
        if control.selectedSegmentIndex == 1 {
            showFeaturePoints = false
        }
        else {
            showFeaturePoints = true
        }
        setupSessionPreferences()
    }
    
    @IBOutlet weak var showDistancePoints: UISegmentedControl!
    
    @IBAction func showDistanceTapped(_ control: UISegmentedControl) {
        if control.selectedSegmentIndex != 1 { showDistanceLabels = true} else { showDistanceLabels = false}
    }
    
    @IBOutlet weak var showAnglePoints: UISegmentedControl!
    @IBAction func showAnglesPointsTapped(_ control: UISegmentedControl) {
        if control.selectedSegmentIndex != 1 {
            showAngleLabels = true
        }
        else {
            showAngleLabels = false
        }
    }
    
    @IBOutlet weak var settingMenu: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        clearMeasurementLabels()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupARSession()
    }
    func clearMeasurementLabels(){
        measurementLbl.forEach {$0.text = ""}
        unitHolder.alpha = 0.0
    }
    //MARK: Setup ARSession
    func setupARSession(){
        AugmentedRealityView.session = augmentedrealitySession
        AugmentedRealityView.delegate = self
        setupSessionPreferences()
    }
    func setupSessionPreferences(){
        configuration.planeDetection = [planeDetection(.None)]
        AugmentedRealityView.debugOptions = debug(.None)
        if placeOnPlane {configuration.planeDetection = [planeDetection(.Both)]}
        if showFeaturePoints{AugmentedRealityView.debugOptions = debug(.FeaturePoints)}
        augmentedrealitySession.run(configuration, options: runOptions(.ResetAndRemove))
        reset()
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if joiningNodes { reset()}
        if settingsMenuShown { return}
        if placeOnPlane {placementType = .existingPlane} else { placementType = .featurePoint}
        guard let currentTouchLocation = touches.first?.location(in: self.AugmentedRealityView),
            let hitTest = self.AugmentedRealityView.hitTest(currentTouchLocation, types: placementType ).last else { return }
        
        //3. Add A Marker Node
        addMarkerNodeFromMatrix(hitTest.worldTransform)
    }
    
    func addMarkerNodeFromMatrix(_ matrix:matrix_float4x4) {
        //1. Create The Marker Node & Add It  To The Scene
        let markerNode = MarkerNode(fromMatrix: matrix)
        self.AugmentedRealityView.scene.rootNode.addChildNode(markerNode)
        //3. Add It To Our NodesAdded Array
        nodesAdded.append(markerNode)
        //4. perform any calculation needed
        getDistanceBetweenNodes(needsJoining: joiningNodes)
        guard let angleResult = calculateAnglesBetweenNodes(joiningNodes: joiningNodes, nodes: nodesAdded) else {
            return
        }
        createAngleNodeLabelOn(angleResult.midNode, angle: angleResult.angle)
    }
    /// Creates An Angle Label Between Three SCNNodes
    ///
    /// - Parameters:
    ///   - node: SCNNode
    ///   - angle: Double
    func createAngleNodeLabelOn(_ node: SCNNode, angle: Double) {
        //format our angle
        let formattedAngle = String(format: "%.2", angle)
        // create the angle label and add to corresponding node.
        let angleText = TextNode(text: formattedAngle, colour: .white)
        angleText.position = SCNVector3(0, 0.01, 0)
        node.addChildNode(angleText)
        // store it
        angleNodes.append(angleText)
        var opacity: CGFloat = 0
        
        if showAngleLabels { opacity = 1 }
        setNodesVisibility(angleNodes, opacity: opacity)
        
    }
    
    //-------------------------------------------
    //MARK: Calculation + Distance & Angle Labels
    //-------------------------------------------
    
    /// Calculates The Distance Between 2 SCNNodes
    func getDistanceBetweenNodes(needsJoining: Bool) {
        // If We Have More Than Two Nodes On Screen We Can Calculate The Distance Between Them
        if nodesAdded.count >= 2 {
            guard let result = calculateDistanceBetweenNodes(joiningNodes: needsJoining, nodes: nodesAdded) else{return}
            // draw a line between two nodes
            let line = MeasuringLineNode(startingVector: result.nodeA, endingVector: result.nodeB)
            self.AugmentedRealityView.scene.rootNode.addChildNode(line)
            nodesAdded.append(line)
            // Create the distance label
            createDistanceLabel(joiningNodes: needsJoining, nodes: nodesAdded, distance: result.distance)
            
        }
    }
    
    func createDistanceLabel(joiningNodes: Bool,nodes:[SCNNode], distance: Float) {
        // get nodes using the positioning
        guard let nodes = positionalNodes(joiningNodes: joiningNodes, nodes: nodes) else { return}
        let nodeA = nodes.nodeA
        let nodeB = nodes.nodeB
        // format our angle
        let formattedDistance = String(format: "%.2f", distance)
        //create a distance Label and add to scene
        let distancelabel = TextNode(text: "\(formattedDistance)m", colour: .white)
        distancelabel.placeBetweenNodes(nodeA, and: nodeB)
        self.AugmentedRealityView.scene.rootNode.addChildNode(distancelabel)
        // generate the measurement label
        generateMeasurementLabelsFrom(distance)
        //Store It
        distanceNodes.append(distancelabel)
        var opacity: CGFloat  = 0
        if showDistanceLabels {opacity = 1}
        setNodesVisibility(distanceNodes, opacity: opacity)
        
    }
    func generateMeasurementLabelsFrom(_ distanceInMetres: Float){
        let sequence = stride(from: 0, to: 5, by: 1)
        let measurement = convertedLengthsFromMetres(distanceInMetres)
        let suffixes = ["m", "cm", "mm", "ft", "in"]
        for index in sequence {
            let labelDisplay = measurementLbl[index]
            let value = "\(String(format: "%.2f", measurement[index].value))\(suffixes[index])"
            labelDisplay.text = value
        }
        unitHolder.alpha = 1
    }
    @IBAction func reset() {
        AugmentedRealityView.scene.rootNode.enumerateChildNodes{(nodeToRemove, _) in nodeToRemove.removeFromParentNode()}
        //2. Clear The NodesAdded Array
        nodesAdded.removeAll()
        angleNodes.removeAll()
        distanceNodes.removeAll()
        lineNodes.removeAll()
        
        //3. Reset The Joining Boolean
        joiningNodes = false
        
        //4. Reset The Labels
        clearMeasurementLabels()
        settingMenu.alpha = 0
        settingsMenuShown = false
    }
    
    @IBAction func joinNodes() {
        
        closeNodes()
    }
    
    @IBAction func settings() {
        var opacity: CGFloat = 0
        var angleOpacity: CGFloat = 0
        var markerOpacity: CGFloat = 0
        
        if settingMenu.alpha == 0 {
            
            settingMenu.alpha = 1
            settingsMenuShown = true
            AugmentedRealityView.rippleView()
            
        } else {
            
            settingMenu.alpha = 0
            settingsMenuShown = false
            opacity = 1
            
            if showAngleLabels { angleOpacity = 1 }
            if showDistanceLabels { markerOpacity = 1 }
            
        }
        setNodesVisibility(angleNodes, opacity: angleOpacity)
        setNodesVisibility(distanceNodes, opacity: markerOpacity)
        let markerLineAndNodes = lineNodes + nodesAdded
        setNodesVisibility(markerLineAndNodes, opacity: opacity)
    }
    // join nodes first and last nodes
    func closeNodes(){
        joiningNodes = true
        getDistanceBetweenNodes(needsJoining: joiningNodes)
        guard let angleR = calculateAnglesBetweenNodes(joiningNodes: joiningNodes, nodes: angleNodes) else {
            return
        }
        createAngleNodeLabelOn(angleR.midNode, angle: angleR.angle)
        guard let angleX = calculateFinalAnglesBetweenNodes(nodesAdded) else {
            return
        }
        createAngleNodeLabelOn(angleX.midNode, angle: angleX.angle)
    }
    
    //---------------------
    //MARK: Node Visibility
    //---------------------
    
    
    /// Sets The Visibility Of The Angle & Distance Text Nodes
    ///
    /// - Parameters:
    ///   - nodes: [SCNNode]
    ///   - opacity: CGFloat
    func setNodesVisibility(_ nodes: [SCNNode], opacity: CGFloat) {
        
        nodes.forEach { (node) in node.opacity = opacity }
        
    }
}
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.statusLabel.text = self.augmentedrealitySession.sessionStatus()
            //  print("validationText!=", self.statusLabel.text!)
            if let validSessionText = self.statusLabel.text {
                
                self.sessionLabelView.isHidden = validSessionText.isEmpty
            }
            
        }
        
    }
    
}
