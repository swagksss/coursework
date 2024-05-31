//
//  ViewController.swift
//
//


import UIKit
import RealityKit
import Combine

class ViewController: UIViewController {
    @IBOutlet var arView: ARView!
    
    var timer: Timer?
    var timeRemaining: Int = 60
    var timeModelAnchor: AnchorEntity?
    var cancellables: Set<AnyCancellable> = []
    var winModelAnchor: AnchorEntity?

    var cards: [Entity] = []
    var flippedCards: [Entity] = []
    var matchedCards: Set<Entity> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let anchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
        arView.scene.addAnchor(anchor)
        
        // Load models
        var cancellable: AnyCancellable? = nil
        cancellable = ModelEntity.loadModelAsync(named: "plane")
            .append(ModelEntity.loadModelAsync(named: "train"))
            .append(ModelEntity.loadModelAsync(named: "house"))
            .append(ModelEntity.loadModelAsync(named: "dog"))
            .append(ModelEntity.loadModelAsync(named: "plant2"))
            .append(ModelEntity.loadModelAsync(named: "plant"))
            .append(ModelEntity.loadModelAsync(named: "donut"))
            .append(ModelEntity.loadModelAsync(named: "cake"))
            .collect()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error: \(error)")
                }
                cancellable?.cancel()
            }, receiveValue: { entities in
                self.setupGame(with: entities, anchor: anchor)
                cancellable?.cancel()
            })
        
        // Setup timer label, restart button, and tap gesture recognizer
        setupTimerLabel()
        setupRestartButton()
        setupTapGestureRecognizer()
        
        // Add "memo" model above the game field
        addMemoModel(anchor: anchor)
    }
    func setupGame(with entities: [ModelEntity], anchor: AnchorEntity) {
        // Prepare cards and objects
        var objects: [ModelEntity] = []
        
        let modelNames = ["plane", "train", "house", "dog", "plant2", "plant", "donut", "cake"]
        
        for (index, entity) in entities.enumerated() {
            entity.setScale(SIMD3<Float>(0.005, 0.005, 0.005), relativeTo: anchor) // Уменьшаем масштаб объектов
            entity.generateCollisionShapes(recursive: true)
            entity.name = modelNames[index] // Assign a custom name
            
            for _ in 1...2 {
                objects.append(entity.clone(recursive: true))
            }
        }
        
        objects.shuffle()
        
        for _ in 1...16 {
            let box = MeshResource.generateBox(width: 0.1, height: 0.005, depth: 0.1) // Уменьшаем размеры карт
            let metalMaterial = SimpleMaterial(color: .gray, isMetallic: true)
            let model = ModelEntity(mesh: box, materials: [metalMaterial])
            model.generateCollisionShapes(recursive: true)
            cards.append(model)
        }
        
        for (index, card) in cards.enumerated() {
            let x = Float(index % 4) - 0.5 // Уменьшаем расстояние между картами
            let z = Float(index / 4) - 0.5 // Уменьшаем расстояние между картами
            card.position = [x * 0.25, 0, z * 0.25] // Уменьшаем расстояние между картами
            anchor.addChild(card)
            card.addChild(objects[index])
            card.transform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        }
        
        let boxSize: Float = 1.75 // Уменьшаем размер окклюзионной коробки
        let occlusionBoxMesh = MeshResource.generateBox(size: boxSize)
        let occlusionBox = ModelEntity(mesh: occlusionBoxMesh, materials: [OcclusionMaterial()])
        occlusionBox.position.y = -boxSize / 2
        anchor.addChild(occlusionBox)
    }

    
    func setupTimerLabel() {
        let timerLabelWidth: CGFloat = 100
        let timerLabelHeight: CGFloat = 30
        let timerLabelX = arView.frame.width - timerLabelWidth - 150
        let timerLabelY: CGFloat = 55
        
        let timerLabel = UILabel(frame: CGRect(x: timerLabelX, y: timerLabelY, width: timerLabelWidth, height: timerLabelHeight))
        timerLabel.textColor = .white
        timerLabel.font = UIFont.systemFont(ofSize: 30)
        arView.addSubview(timerLabel)
        updateTimerLabel(timerLabel)
    }
    
    func setupRestartButton() {
        let restartButton = UIButton(type: .system)
        restartButton.setTitle("Restart", for: .normal)
        restartButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        restartButton.frame = CGRect(x: arView.frame.width - 130, y: 55, width: 100, height: 30)
        restartButton.addTarget(self, action: #selector(restartTimer), for: .touchUpInside)
        arView.addSubview(restartButton)
    }
    
    func setupTapGestureRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    @objc func restartTimer() {
            // Reset timer
            timer?.invalidate()
            timer = nil
            timeRemaining = 60
            updateTimerLabel()
            
            // Remove all cards and objects
            for card in cards {
                card.removeFromParent()
            }
            cards.removeAll()
            matchedCards.removeAll()
            flippedCards.removeAll()
            
            // Remove the "time2" model if it exists
            timeModelAnchor?.removeFromParent()
            timeModelAnchor = nil
            
            winModelAnchor?.removeFromParent()
            winModelAnchor = nil
           
            
            // Restart game
            let anchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
            arView.scene.addAnchor(anchor)
            
            var cancellable: AnyCancellable? = nil
            cancellable = ModelEntity.loadModelAsync(named: "plane")
                .append(ModelEntity.loadModelAsync(named: "train"))
                .append(ModelEntity.loadModelAsync(named: "house"))
                .append(ModelEntity.loadModelAsync(named: "dog"))
                .append(ModelEntity.loadModelAsync(named: "plant2"))
                .append(ModelEntity.loadModelAsync(named: "plant"))
                .append(ModelEntity.loadModelAsync(named: "donut"))
                .append(ModelEntity.loadModelAsync(named: "cake"))
                .collect()
                .sink(receiveCompletion: { error in
                    print("Error: \(error)")
                    cancellable?.cancel()
                }, receiveValue: { entities in
                    self.setupGame(with: entities, anchor: anchor)
                    cancellable?.cancel()
                })
        }
    @objc func onTap(_ sender: UITapGestureRecognizer) {
        guard flippedCards.count < 2 else { return }
        
        let tapLocation = sender.location(in: arView)
        if let card = arView.entity(at: tapLocation), !matchedCards.contains(card) && !flippedCards.contains(card) {
            if card.transform.rotation.angle == .pi {
                flipCardUp(card)
                flippedCards.append(card)
                
                if flippedCards.count == 2 {
                    checkForMatch()
                }
                
                // Start the timer when the first card is flipped
                if matchedCards.isEmpty && flippedCards.count == 1 {
                    startTimerIfNeeded()
                }
            }
        }
    }
    
    func flipCardUp(_ card: Entity) {
        var flipUpTransform = card.transform
        flipUpTransform.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        card.move(to: flipUpTransform, relativeTo: card.parent, duration: 0.25, timingFunction: .easeInOut)
    }
    
    func flipCardDown(_ card: Entity) {
        var flipDownTransform = card.transform
        flipDownTransform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        card.move(to: flipDownTransform, relativeTo: card.parent, duration: 0.25, timingFunction: .easeInOut)
    }
    
    func checkForMatch() {
        guard flippedCards.count == 2 else { return }
        
        let firstCard = flippedCards[0]
        let secondCard = flippedCards[1]
        
        if let firstChild = firstCard.children.first as? ModelEntity, let secondChild = secondCard.children.first as? ModelEntity,
           firstChild.name == secondChild.name { // Compare custom names
            matchedCards.insert(firstCard)
            matchedCards.insert(secondCard)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.flipCardDown(firstCard)
                self.flipCardDown(secondCard)
            }
        }
        
        flippedCards.removeAll()
        
        // Check if all pairs are matched
        if matchedCards.count == cards.count {
            timer?.invalidate()
            timer = nil
        }
        if matchedCards.count == cards.count {
            // Stop the timer
            timer?.invalidate()
            timer = nil
            
            // Show winner model
            displayWinModel()
        }
    }
    
    func startTimerIfNeeded() {
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.timeRemaining -= 1
                if self.timeRemaining <= 0 {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.displayTimeModel()
                } else {
                    self.updateTimerLabel()
                }
            }
        }
    }
    
    func updateTimerLabel(_ label: UILabel? = nil) {
        let minutes = max(timeRemaining / 60, 0)
        let seconds = max(timeRemaining % 60, 0)
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        DispatchQueue.main.async {
            if let label = label {
                label.text = timeString
            } else {
                if let existingLabel = self.arView.subviews.first(where: { $0 is UILabel }) as? UILabel {
                    existingLabel.text = timeString
                }
            }
        }
    }
    
    func displayTimeModel() {
        timeModelAnchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
        arView.scene.addAnchor(timeModelAnchor!)
        let timeModel = ModelEntity.loadModelAsync(named: "time2")
        timeModel.sink(receiveCompletion: { error in
            print("Error loading time model: \(error)")
        }, receiveValue: { entity in
            entity.setScale(SIMD3<Float>(0.01, 0.01, 0.01), relativeTo: self.timeModelAnchor!)
            entity.generateCollisionShapes(recursive: true)
            entity.position = [0, 0, -0.5]
            self.timeModelAnchor?.addChild(entity)
        }).store(in: &cancellables)
    }
    
    func addMemoModel(anchor: AnchorEntity) {
            let memoModel = ModelEntity.loadModelAsync(named: "memo")
            memoModel.sink(receiveCompletion: { error in
                print("Error loading memo model: \(error)")
            }, receiveValue: { entity in
                // Увеличиваем размер модели
                entity.setScale(SIMD3<Float>(0.03, 0.03, 0.03), relativeTo: anchor)
                entity.generateCollisionShapes(recursive: true)
                entity.position = [0, 0.3, -2.0]
                anchor.addChild(entity)
            }).store(in: &cancellables)
        }


    func displayWinModel() {
        winModelAnchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
        arView.scene.addAnchor(winModelAnchor!)
        let timeModel = ModelEntity.loadModelAsync(named: "winner1")
        timeModel.sink(receiveCompletion: { error in
            print("Error loading time model: \(error)")
        }, receiveValue: { entity in
            entity.setScale(SIMD3<Float>(0.8, 0.8, 0.8), relativeTo: self.winModelAnchor!)
            entity.generateCollisionShapes(recursive: true)
            entity.position = [0, 0, 0]
            self.winModelAnchor?.addChild(entity)
        }).store(in: &cancellables)
    }



}
