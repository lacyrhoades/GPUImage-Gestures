//
//  ViewController.swift
//  Demo
//
//  Created by Lacy Rhoades on 6/22/18.
//  Copyright © 2018 Lacy Rhoades. All rights reserved.
//

import UIKit
import AVFoundation
import GPUImage
import Vision

class ViewController: UIViewController {

    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml")
    var visionRequests = [VNRequest]()
    
    let liveView = GPUImageView()
    var gpuCamera: GPUImageStillCamera!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let selectedModel = try? VNCoreMLModel(for: example_5s0_hand_model().model) else {
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project. Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
        }
        
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        
        view.addSubview(liveView)
        liveView.frame = view.bounds
        liveView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        gpuCamera = GPUImageStillCamera(sessionPreset: AVCaptureSession.Preset.photo.rawValue, cameraPosition: .front)
        gpuCamera.addTarget(liveView)
        gpuCamera.outputImageOrientation = .portrait
        gpuCamera.horizontallyMirrorFrontFacingCamera = true
        GPUImageContext.sharedContextQueue().async {
            self.gpuCamera.startCapture()
        }
        
        GPUImageContext.sharedContextQueue().asyncAfter(deadline: DispatchTime.seconds(2)) {
            self.loopCoreMLUpdate()
        }
    }
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.asyncAfter(deadline: DispatchTime.seconds(1)) {
            // 1. Run Update.
            self.updateCoreML() { image in
                self.dispatchQueueML.async {
                    let imageRequestHandler = VNImageRequestHandler(ciImage: image, options: [:])
                    
                    // Run Vision Image Request
                    do {
                        try imageRequestHandler.perform(self.visionRequests)
                    } catch {
                        print(error)
                    }
                    
                    self.loopCoreMLUpdate()
                }
            }
        }
    }
    
    func updateCoreML(andThen: @escaping (CIImage) -> ()) {
        GPUImageContext.sharedContextQueue().async {
            // Get Camera Image as RGB
            let filter = GPUImageSaturationFilter()
            self.gpuCamera.addTarget(filter)
        
            self.gpuCamera.capturePhotoAsImageProcessedUp(toFilter: filter, with: .up, withCompletionHandler: { (image, error) in
                
                guard error == nil,
                    let image = image,
                    let cgImage = image.cgImage else {
                    return
                }
                
                let ciImage = CIImage.init(cgImage: cgImage)
                
                andThen(ciImage)
            })
        }
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...2] // top 3 results
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        DispatchQueue.main.async {
            print( "TOP 3 PROBABILITIES: \n" + classifications )
            
            // Display Top Symbol
            var symbol = "❎"
            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            // Only display a prediction if confidence is above 1%
            let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
            if (topPredictionScore != nil && topPredictionScore! > 0.01) {
                if (topPredictionName == "fist-UB-RHand") { symbol = "👊" }
                if (topPredictionName == "FIVE-UB-RHand") { symbol = "🖐" }
            }
            
            print(symbol)
        }
    }
    
    // MARK: - HIDE STATUS BAR
    override var prefersStatusBarHidden : Bool { return true }

}

extension DispatchTime {
    static func seconds(_ secs: TimeInterval) -> DispatchTime {
        return DispatchTime.now() + secs
    }
}
