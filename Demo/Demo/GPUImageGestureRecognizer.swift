//
//  GPUImageGestureRecognizer.swift
//  Demo
//
//  Created by Lacy Rhoades on 6/22/18.
//  Copyright © 2018 Lacy Rhoades. All rights reserved.
//

import Foundation
import GPUImage
import Vision

class GPUImageGestureRecognizer {
    var gpuCamera: GPUImageStillCamera?
    var result: ((Gesture) -> ())?
    
    fileprivate var jobs: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    fileprivate let waitGroup = DispatchGroup()
    fileprivate let notificationQueue = DispatchQueue.main
    
    fileprivate var visionRequests = [VNRequest]()
    
    init() {
        guard let selectedModel = try? VNCoreMLModel(for: example_5s0_hand_model().model) else {
            precondition(false, "Could not load model. Ensure model has been copied to XCode project.")
        }
        
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        visionRequests = [classificationRequest]
    }
    
    func startProcessing() {
        let processOperation = BlockOperation {
            self.processImage()
        }
        let repeatOperation = BlockOperation {
            self.notificationQueue.asyncAfter(deadline: DispatchTime.seconds(0.1)) {
                self.startProcessing()
            }
        }
        repeatOperation.addDependency(processOperation)
        self.jobs.addOperation(processOperation)
        self.jobs.addOperation(repeatOperation)
    }
    
    func stopProcessing() {
        self.jobs.cancelAllOperations()
    }
    
    func processImage() {
        let image = self.getImage()
        
        guard let cgImage = image?.cgImage else {
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(ciImage: CIImage.init(cgImage: cgImage), options: [:])
        
        waitGroup.enter()
        
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print("Error: ", error)
            waitGroup.leave()
        }
        
        let _ = waitGroup.wait(timeout: DispatchTime.seconds(2))
    }
    
    func getImage() -> UIImage? {
        var result: UIImage? = nil
        
        let filter = GPUImageSaturationFilter()
        self.gpuCamera?.addTarget(filter)
        
        let wait = DispatchGroup()
        wait.enter()
        
        self.gpuCamera?.capturePhotoAsImageProcessedUp(toFilter: filter, with: .up) { (image, error) in
            result = image
            wait.leave()
        }
        
        let _ = wait.wait(timeout: DispatchTime.seconds(2))
        
        self.gpuCamera?.removeTarget(filter)

        return result
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            waitGroup.leave()
            return
        }
        
        guard let observations = request.results else {
            print("Error: No results")
            waitGroup.leave()
            return
        }
        
        // Top 3 results
        let classifications = observations[0...2]
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        var gesture = Gesture.empty
        
        let topPrediction = classifications.components(separatedBy: "\n")[0]
        let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
        
        // Only display a prediction if confidence is above 1%
        let topPredictionScore: Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
        
        if (topPredictionScore != nil && topPredictionScore! > 0.01) {
            switch topPredictionName {
            case "fist-UB-RHand":
                gesture = .fist
            case "FIVE-UB-RHand":
                gesture = .hand
            case "no-hand":
                gesture = .empty
            default:
                print("Error: Unrecognized prediction: ", topPrediction)
            }
        }
        
        self.notificationQueue.async {
            self.result?(gesture)
            self.waitGroup.leave()
        }
    }
}

func currentQueueName() -> String {
    let name = __dispatch_queue_get_label(nil)
    return String(cString: name, encoding: .utf8) ?? "nil"
}
