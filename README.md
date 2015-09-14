# PSCamera
easy-to-use wrapper class around AVFoundation, to allow easy creation of custom cameras on iOS

# Usage
PSCamera is really easy to use. Start by declaring an instance of it to use throughout your app:

```Swift
let camera = PSCamera()
```

Then, call `loadCaptureSession()` on the instance you created. This will set up an AVCaptureSession, along with the appropriate inputs and outputs, to create a fully functional photo capture session. This isn't done in `init()` as it's a slightly expensive operation:

```Swift
camera.loadCaptureSession(quality: AVCaptureSessionPresetHigh, backCameraFocusMode: .AutoFocus) {(error) in
  //completion block
}
```

**You can omit the quality parameter, it defaults to AVCaptureSessionPresetHigh. You CANNOT, however, omit the back camera focus mode parameter. Choose whatever you'd like, but remember that continuous auto focus is only available on the iPhone 6 and later.**

To display a preview on a view inside your app, use `displayPreview()`:

```Swift
camera.displayPreviewOnView(myView)
```
This will add the AVCaptureVideoPreviewLayer to your view. For best results, use a UIImageView.
Finally, to capture an image, use `capture()`:

```Swift
camera.capture(shouldFlash: false) {(error, capturedImage) in 
  //completion block
}
```

PSCamera also gives you an easy way to switch cameras, using `switchCameras()`:

```Swift
camera.switchCameras {(error) in
  //completion block
}
=======
wrapper class around AVFoundation, to allow easy creation of custom cameras on iOS

# Usage
First, start by declaring an instance of PSCamera to use in your app:

```Swift
let camera = PSCamera
```
