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

class ViewController: UIViewController {

    let liveView = GPUImageView()
    let label = UILabel()
    
    var gpuCamera: GPUImageStillCamera!
    let gestureRecognizer = GPUImageGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(liveView)
        liveView.frame = view.bounds
        liveView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(label)
        label.font = UIFont.systemFont(ofSize: 99)
        label.textAlignment = .center
        label.frame = view.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        gpuCamera = GPUImageStillCamera(sessionPreset: AVCaptureSession.Preset.photo.rawValue, cameraPosition: .front)
        gpuCamera.addTarget(liveView)
        gpuCamera.outputImageOrientation = .portrait
        gpuCamera.horizontallyMirrorFrontFacingCamera = true
        
        self.show("⏳")
        
        gestureRecognizer.gpuCamera = gpuCamera
        gestureRecognizer.result = {
            gesture in
            
            switch gesture {
            case .empty:
                self.show("❎")
            case .hand:
                self.show("🖐")
            case .fist:
                self.show("👊")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        GPUImageContext.sharedContextQueue().async {
            self.gpuCamera.startCapture()
            self.gestureRecognizer.startProcessing()
        }
    }

    override var prefersStatusBarHidden : Bool { return true }
    
    func show(_ text: String) {
        self.label.text = text
    }
}
