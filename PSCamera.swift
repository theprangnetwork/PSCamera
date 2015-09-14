//
//  PSCamera.swift
//  ephemera
//
//  Created by Pranjal Satija on 9/9/15.
//  Copyright © 2015 Pranjal Satija. All rights reserved.
//

import AVFoundation
import UIKit

enum PSCameraType {
    case Front, Back
}

class PSCamera {
    var captureSession: AVCaptureSession?
    var output: AVCaptureStillImageOutput?
    var preview: AVCaptureVideoPreviewLayer?
    
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: PSCameraType?
    
    ///sets up an AVCaptureSession with the given preset, and calls a completion block when done
    func loadCaptureSessionWithQuality(quality: String = AVCaptureSessionPresetHigh, backCameraFocusMode: AVCaptureFocusMode, completion: ((error: NSError?) -> ())?) {
        //move everything off the main thread to avoid lag
        NSOperationQueue().addOperationWithBlock {
            if let _ = self.captureSession {
                NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: nil)}
                return //early exit if capture session is already active
            }
                
            else {
                self.captureSession = AVCaptureSession()
                self.captureSession!.sessionPreset = quality
                
                
                let availableDevices = AVCaptureDevice.devices()
                
                //sets frontCamera and backCamera to appropriate devices (when available)
                for device in availableDevices {
                    if device.hasMediaType(AVMediaTypeVideo) {
                        if device.position == .Front {
                            self.frontCamera = device as? AVCaptureDevice
                        }
                        
                        if device.position == .Back {
                            self.backCamera = device as? AVCaptureDevice
                        }
                    }
                }
                
                //early exit if no cameras are available
                if availableDevices.count == 0 {
                    NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 100, userInfo: nil))}
                    return
                }
            
                
                do {
                    try self.backCamera?.lockForConfiguration()
                }
                
                //early exit if we can't get a lock on configuring the back camera
                catch {
                    NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 101, userInfo: nil))}
                    return
                }
                
                self.backCamera?.focusMode = backCameraFocusMode
                self.backCamera?.unlockForConfiguration()
                
                
                var input: AVCaptureDeviceInput?
                
                //sets up the input with the back camera
                if let backCamera = self.backCamera {
                    self.currentCamera = .Back
                    
                    do {
                        try input = AVCaptureDeviceInput(device: backCamera)
                    }
                        
                    catch {
                        NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 102, userInfo: nil))}
                        return
                    }
                }
                
                //if setting up input with the back camera fails, we use the front
                else if let frontCamera = self.frontCamera {
                    self.currentCamera = .Front
                    
                    do {
                        try input = AVCaptureDeviceInput(device: frontCamera)
                    }
                        
                    catch {
                        NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 102, userInfo: nil))}
                        return
                    }
                }
                
                //adds the input to the capture session, and calls the completion handler
                if self.captureSession!.canAddInput(input) {
                    self.captureSession!.addInput(input)
                    self.output = AVCaptureStillImageOutput()
                    self.output?.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
                    
                    if self.captureSession!.canAddOutput(self.output) {
                        self.captureSession!.addOutput(self.output)
                        self.preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                        self.preview!.videoGravity = AVLayerVideoGravityResizeAspectFill;
                        self.preview!.connection!.videoOrientation = .Portrait;
                        
                        self.captureSession?.startRunning()
                        NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: nil)}
                    }
                        
                    else {
                        NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 103, userInfo: nil))}
                    }
                }
                    
                else {
                    NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 103, userInfo: nil))}
                }
            }
        }
    }
    
    ///adds the preview layer to a view parameter
    func displayPreviewOnView(view: UIView) {
        if let preview = preview {
            view.layer.addSublayer(preview)
            preview.frame = view.frame
        }
    }
    
    ///handles asynchronous capture of an image, and calls a completion block when done
    func capture(shouldFlash shouldFlash: Bool, completion: ((error: NSError?, image: UIImage?) -> ())?) {
        guard let currentCameraDevice = (self.captureSession?.inputs[0] as? AVCaptureDeviceInput)?.device, connection = self.output?.connectionWithMediaType(AVMediaTypeVideo) else {
            completion?(error: NSError(domain: "PSCameraError", code: 105, userInfo: nil), image: nil)
            return
        }
        
        NSOperationQueue().addOperationWithBlock {
            //enables flash (if necessary)
            if currentCameraDevice.flashAvailable && shouldFlash {
                do {
                    try currentCameraDevice.lockForConfiguration()
                }
                
                catch {
                    NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 100, userInfo: nil), image: nil)}
                    return
                }
                
                currentCameraDevice.flashMode = .On
                currentCameraDevice.unlockForConfiguration()
            }
            
            //captures the image into a CMSampleBuffer
            self.output?.captureStillImageAsynchronouslyFromConnection(connection) {(buffer, error) in
                if let _ = error {
                    NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 100, userInfo: nil), image: nil)}
                    return
                }
                
                //converts the captured CMSampleBuffer into a UIImage
                else {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                    let dataProvider = CGDataProviderCreateWithCFData(imageData)
                    var image: UIImage?
                    
                    if let coreGraphicsImage = CGImageCreateWithJPEGDataProvider(dataProvider, nil, true, .RenderingIntentDefault) {
                        if self.currentCamera == .Back {
                            image = UIImage(CGImage: coreGraphicsImage, scale: 1, orientation: .Right)
                        }
                        
                        if self.currentCamera == .Front {
                            image = UIImage(CGImage: coreGraphicsImage, scale: 1, orientation: .LeftMirrored)
                        }
                    }
                        
                    else {
                        NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 100, userInfo: nil), image: nil)}
                    }
                    
                    //turns off the flash
                    do {
                        try currentCameraDevice.lockForConfiguration()
                    }
                    
                    catch {
                        NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 100, userInfo: nil), image: nil)}
                        return
                    }
                    
                    if currentCameraDevice.flashMode == .On {
                        currentCameraDevice.flashMode = .Off
                    }
                    
                    currentCameraDevice.unlockForConfiguration()
                    
                    NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: nil, image: image)}
                }
            }
        }
    }
    
    //handles switching cameras, and calls a completion block when done
    func switchCameras(completion completion: ((error: NSError?) -> ())?) {
        if let currentInput = self.captureSession?.inputs.first as? AVCaptureDeviceInput {
            captureSession?.beginConfiguration()
            captureSession?.removeInput(currentInput) //removes the current camera
            
            var newCamera: AVCaptureDevice?
            var switchedTo: PSCameraType!
            
            //determines which camera was active, and creates a new input based on that
            if self.currentCamera == .Back {
                if let frontCamera = frontCamera {
                    newCamera = frontCamera
                    switchedTo = .Front
                    
                    print("new cam is front")
                }
            }
            
            if self.currentCamera == .Front {
                if let backCamera = backCamera {
                    newCamera = backCamera
                    switchedTo = .Back
                    print("new cam is back")
                }
            }
            
            var newCameraInput: AVCaptureDeviceInput!
            
            do {
                newCameraInput = try AVCaptureDeviceInput(device: newCamera)
            }
            
            catch {
                NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: NSError(domain: "PSCameraError", code: 100, userInfo: nil))}
                return
            }
            
            
            //adds the new input to the capture session, updates the currentCamera variable, and commits the changes
            captureSession?.addInput(newCameraInput)
            currentCamera = switchedTo
            
            captureSession?.commitConfiguration()
            
            NSOperationQueue.mainQueue().addOperationWithBlock {completion?(error: nil)}
        }
    }
}