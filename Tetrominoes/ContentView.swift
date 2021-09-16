//
//  ContentView.swift
//  Tetrominoes
//
//  Created by Nien Lam on 9/15/21.
//  Copyright © 2021 Line Break, LLC. All rights reserved.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    let uiSignal = PassthroughSubject<UISignal, Never>()
    
    enum UISignal {
        case straightSelected
        case squareSelected
        case tSelected
        case lSelected
        case skewSelected
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        ZStack {
            // AR View.
            ARViewContainer(viewModel: viewModel)
            
            // Bottom buttons.
            HStack {
                Button {
                    viewModel.uiSignal.send(.straightSelected)
                } label: {
                    tetriminoIcon("straight", color: Color(red: 0, green: 1, blue: 1))
                }
                
                Button {
                    viewModel.uiSignal.send(.squareSelected)
                } label: {
                    tetriminoIcon("square", color: .yellow)
                }
                
                Button {
                    viewModel.uiSignal.send(.tSelected)
                } label: {
                    tetriminoIcon("t", color: .purple)
                }
                
                Button {
                    viewModel.uiSignal.send(.lSelected)
                } label: {
                    tetriminoIcon("l", color: .orange)
                }
                
                Button {
                    viewModel.uiSignal.send(.skewSelected)
                } label: {
                    tetriminoIcon("skew", color: .green)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 30)
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }
    
    // Helper method for rendering icon.
    func tetriminoIcon(_ image: String, color: Color) -> some View {
        Image(image)
            .resizable()
            .padding(3)
            .frame(width: 44, height: 44)
            .background(color)
            .cornerRadius(5)
    }
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var originAnchor: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()
    
    // Empty entity for cursor.
    var cursor: Entity!
    
    // Root entities for pieces.
    var straightEntity: Entity!
    var squareEntity: Entity!
    var tEntity: Entity!
    var lEntity: Entity!
    var skewEntity: Entity!
    
    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
        
        setupEntities()

        // Enable straight piece on startup.
        straightEntity.isEnabled  = true
        squareEntity.isEnabled    = false
        tEntity.isEnabled         = false
        lEntity.isEnabled         = false
        skewEntity.isEnabled      = false

    }
    
    func setupScene() {
        // Setup world tracking and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.session.run(configuration)
        
        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            self.updateCursor()
        }.store(in: &subscriptions)
        
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
    }
    
    // Hide/Show active tetromino.
    func processUISignal(_ signal: ViewModel.UISignal) {
        straightEntity.isEnabled  = false
        squareEntity.isEnabled    = false
        tEntity.isEnabled         = false
        lEntity.isEnabled         = false
        skewEntity.isEnabled      = false
        
        switch signal {
        case .straightSelected:
            straightEntity.isEnabled = true
        case .squareSelected:
            squareEntity.isEnabled = true
        case .tSelected:
            tEntity.isEnabled = true
        case .lSelected:
            lEntity.isEnabled = true
        case .skewSelected:
            skewEntity.isEnabled = true
        }
    }
    
    // Move cursor to plane detected.
    func updateCursor() {
        // Raycast to get cursor position.
        let results = raycast(from: center,
                              allowing: .existingPlaneGeometry,
                              alignment: .any)
        
        // Move cursor to position if hitting plane.
        if let result = results.first {
            cursor.isEnabled = true
            cursor.move(to: result.worldTransform, relativeTo: originAnchor)
        } else {
            cursor.isEnabled = false
        }
    }
    
    func setupEntities() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)
        
        // Create and add empty cursor entity to origin anchor.
        cursor = Entity()
        originAnchor.addChild(cursor)
        
        // Create root tetrominoes. ////
        
        // Box mesh.
        let boxSize: Float      = 0.03
        let cornerRadius: Float = 0.002
        let boxMesh = MeshResource.generateBox(size: boxSize, cornerRadius: cornerRadius)
        
        // Colored materials.
        let cyanMaterial    = SimpleMaterial(color: .cyan, isMetallic: false)
        let yellowMaterial  = SimpleMaterial(color: .yellow, isMetallic: false)
        let purpleMaterial  = SimpleMaterial(color: .purple, isMetallic: false)
        let orangeMaterial  = SimpleMaterial(color: .orange, isMetallic: false)
        let greenMaterial   = SimpleMaterial(color: .green, isMetallic: false)
        
        // Create an relative origin entity for centering the root box of each tetromino.
        let relativeOrigin = Entity()
        relativeOrigin.position.y = boxSize / 2
        cursor.addChild(relativeOrigin)
        
        // Straight piece.
        straightEntity = ModelEntity(mesh: boxMesh, materials: [cyanMaterial])
        relativeOrigin.addChild(straightEntity)
        
        // Square piece.
        squareEntity = ModelEntity(mesh: boxMesh, materials: [yellowMaterial])
        relativeOrigin.addChild(squareEntity)
        
        // T piece.
        tEntity = ModelEntity(mesh: boxMesh, materials: [purpleMaterial])
        relativeOrigin.addChild(tEntity)
        
        // L piece.
        lEntity = ModelEntity(mesh: boxMesh, materials: [orangeMaterial])
        relativeOrigin.addChild(lEntity)
        
        // Skew piece.
        skewEntity = ModelEntity(mesh: boxMesh, materials: [greenMaterial])
        relativeOrigin.addChild(skewEntity)
        
        
        // TODO: Create tetrominoes //////////////////////////////////////
        
        // ... create straight piece.
        
        // 1. Clone new cube.
        let newCube = straightEntity.clone(recursive: false)
        
        // 2. Set position based on root tetromino entity.
        newCube.position.y = boxSize
        
        // 3. Add child to root tetromino entity.
        straightEntity.addChild(newCube)



        // ... create square piece.
        



        // ... create t piece.


        
        
        // ... create l piece.

        
        
        
        // ... create skew piece.
        
        
        
        
        /////////////////////////////////////////////////////////////////////////
    }
}
