//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.

import UIKit
import AVFoundation
import CoreLocation

struct Platform {
    static let isSimulator: Bool = {
        var isSim = false
        #if arch(i386) || arch(x86_64)
            isSim = true
        #endif
        return isSim
    }()
}

open class ARViewController: UIViewController, ARTrackingManagerDelegate, AVCapturePhotoCaptureDelegate
{
    open weak var dataSource: ARDataSource?
    open var headingSmoothingFactor: Double = 1
    fileprivate(set) open var trackingManager: ARTrackingManager = ARTrackingManager()
    
    fileprivate var initialized: Bool = false
    fileprivate var cameraSession: AVCaptureSession = AVCaptureSession()
    fileprivate var araview: ARAnnotationView?
    fileprivate var overlayView: OverlayView = OverlayView()
    fileprivate var displayTimer: CADisplayLink?
    fileprivate var cameraLayer: AVCaptureVideoPreviewLayer?    // Will be set in init
    //fileprivate var stillImageOutput = AVCaptureStillImageOutput()
    fileprivate var stillImageOutput = AVCapturePhotoOutput()
    fileprivate var annotationViews: [ARAnnotationView] = []
    var listOfAtms: [NSDictionary] = []
    fileprivate var didLayoutSubviews: Bool = false
    var atmIsNear: Bool = false
    var nearestAtm: NSDictionary = NSDictionary()
    
    var lastLat: String?
    var lastLon: String?
    
    var currentHeading: Double = 0
    
    init()
    {
        super.init(nibName: nil, bundle: nil)
        self.initializeInternal()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initializeInternal()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.initializeInternal()
    }
    
    internal func locationNotification(_ sender: Notification)
    {
        
    }
    
    internal func appWillEnterForeground(_ notification: Notification)
    {
        if(self.view.window != nil)
        {
            self.trackingManager.stopTracking()
            self.trackingManager.startTracking(notifyLocationFailure: true)
        }
    }
    
    internal func appDidEnterBackground(_ notification: Notification)
    {
        if(self.view.window != nil)
        {
            self.trackingManager.stopTracking()
        }
    }
    
    internal func initializeInternal()
    {
        if self.initialized
        {
            return
        }
        self.initialized = true;
        self.trackingManager.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.locationNotification(_:)), name: NSNotification.Name(rawValue: "kNotificationLocationSet"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.appWillEnterForeground(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.appDidEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
        self.stopCamera()
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    open class func createCaptureSession(vc: ARViewController!) -> (session: AVCaptureSession?, error: NSError?)
    {
        var error: NSError?
        var captureSession: AVCaptureSession?
        var backVideoDevice: AVCaptureDevice?
        
        backVideoDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back)
        
        if backVideoDevice != nil
        {
            var videoInput: AVCaptureDeviceInput!
            
            do {
                videoInput = try AVCaptureDeviceInput(device: backVideoDevice)
            
            } catch let error1 as NSError {
                error = error1
                videoInput = nil
            }
            if error == nil
            {
                captureSession = AVCaptureSession()
                
                if captureSession!.canAddInput(videoInput)
                {
                    captureSession!.addInput(videoInput)
                    //vc.stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
                    if captureSession!.canAddOutput(vc.stillImageOutput) {
                        captureSession!.addOutput(vc.stillImageOutput)
                    }
                }
                else
                {
                    error = NSError(domain: "HDAugmentedReality", code: 10002, userInfo: ["description": "Error adding video input."])
                }
            }
            else
            {
                error = NSError(domain: "HDAugmentedReality", code: 10001, userInfo: ["description": "Error creating capture device input."])
            }
        }
        else
        {
            error = NSError(domain: "HDAugmentedReality", code: 10000, userInfo: ["description": "Back video device not found."])
        }
        
        return (session: captureSession, error: error)
    }

    
    fileprivate func loadCamera()
    {
      
        if Platform.isSimulator {
           return
        }

        NSLog("loadCamera");
        self.cameraLayer?.removeFromSuperlayer()
        self.cameraLayer = nil
        
        let captureSessionResult = ARViewController.createCaptureSession(vc: self)
        guard captureSessionResult.error == nil, let session = captureSessionResult.session else
        {
            print("HDAugmentedReality: Cannot create capture session, use createCaptureSession method to check if device is capable for augmented reality.")
            return
        }
        
        self.cameraSession = session
        
        if let cameraLayer = AVCaptureVideoPreviewLayer(session: self.cameraSession)
        {
            cameraLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            self.view.layer.insertSublayer(cameraLayer, at: 0)
            self.cameraLayer = cameraLayer
        }
    }
    
    fileprivate func layoutUi()
    {
        self.cameraLayer?.frame = self.view.bounds
        self.overlayView.frame = self.overlayFrame()
    }
    
    fileprivate func loadOverlay()
    {
        //NSLog("loadOverlay")
        self.overlayView.removeFromSuperview()
        self.overlayView = OverlayView()
        self.view.addSubview(self.overlayView)
    }
    
    fileprivate func overlayFrame() -> CGRect
    {
        //NSLog("loadOverlay[\(currentHeading)]")
        var x: CGFloat = self.view.bounds.size.width / 2 - (CGFloat(currentHeading) * H_PIXELS_PER_DEGREE)
        var y: CGFloat = (CGFloat(self.trackingManager.pitch) * VERTICAL_SENS) + 60.0
        
        x = 100
        y = 100
        
        let newFrame = CGRect(x: x, y: y, width: OVERLAY_VIEW_WIDTH, height: self.view.bounds.size.height)
        //NSLog("frame [\(newFrame)]")
        return newFrame
    }
    
    fileprivate func stopCamera()
    {
        self.trackingManager.stopTracking()
        self.displayTimer?.invalidate()
        self.displayTimer = nil

        if Platform.isSimulator {
            return
        }
        self.cameraSession.stopRunning()
    }
    
    open override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        onViewWillAppear()  // Doing like this to prevent subclassing problems
    }
    
    open override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        onViewDidAppear()   // Doing like this to prevent subclassing problems
    }
    
    open override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        onViewDidDisappear()    // Doing like this to prevent subclassing problems
    }
    
    fileprivate func onViewDidAppear()
    {
        
    }
    
    fileprivate func onViewDidDisappear()
    {
        stopCamera()
    }
    
    open override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        onViewDidLayoutSubviews()
    }
    
    fileprivate func setOrientation(_ orientation: UIInterfaceOrientation)
    {
        NSLog("setOrientation[\(orientation.rawValue)]");
        if self.cameraLayer?.connection?.isVideoOrientationSupported != nil
        {
            if let videoOrientation = AVCaptureVideoOrientation(rawValue: Int(orientation.rawValue))
            {
                self.cameraLayer?.connection?.videoOrientation = videoOrientation
            }
        }
        
        if let deviceOrientation = CLDeviceOrientation(rawValue: Int32(orientation.rawValue))
        {
            self.trackingManager.orientation = deviceOrientation
        }
    }
    
    fileprivate func onViewWillAppear()
    {
        if self.cameraLayer?.superlayer == nil { self.loadCamera() }
        if self.overlayView.superview == nil { self.loadOverlay() }
        self.setOrientation(UIApplication.shared.statusBarOrientation)
        self.layoutUi();
        self.startCamera(notifyLocationFailure: true)
        
        // {"result":[{"lat":33.9888683986235,"lon":-118.403090257308,"h":76.0}]}
        
        let annotation = ARAnnotation()
        annotation.location = CLLocation(latitude: 34, longitude: -118.3)
        annotation.title = "ATM"
        
        
        self.araview = (self.dataSource?.ar(self, viewForAnnotation: annotation))!
        annotation.annotationView = self.araview
        self.araview?.annotation = annotation
        
        self.overlayView.addSubview(self.araview!)
    }
    
    fileprivate func onViewDidLayoutSubviews()
    {
        if !self.didLayoutSubviews
        {
            self.didLayoutSubviews = true
            self.layoutUi()
            self.view.layoutIfNeeded()
        }
        
        //self.degreesPerScreen = (self.view.bounds.size.width / OVERLAY_VIEW_WIDTH) * 360.0
        
    }
    
    fileprivate func updateAnnotationsForCurrentHeading()
    {
        //let annotation = ARAnnotation()
        //annotation.location = CLLocation(latitude: 34, longitude: -118.3)
        //annotation.title = "ATM"
        
        //var av: ARAnnotationView? = nil
        //av = self.dataSource?.ar(self, viewForAnnotation: annotation)
        
        //annotation.annotationView = av
        //av!.annotation = annotation
        
        //av!.bindUi()
        
        //self.overlayView.addSubview(annotation.annotationView!)
    }
    
    public func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let photoSampleBuffer = photoSampleBuffer {
            
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
         
            let latlon:String = "\(self.lastLat!)_\(self.lastLon!)"
         
            let filename = self.getDocumentsDirectory().appendingPathComponent("kb_\(latlon).jpg")
            
            try? photoData?.write(to: filename)
            
        }
        else {
            print("Error capturing photo: \(error)")
            return
        }
    }
    
    func saveStillImage(lats: String, lons: String) {
        if let videoConnection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
            
            let settings = AVCapturePhotoSettings()
            
            self.lastLat = lats
            self.lastLon = lons
            stillImageOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    internal func displayTimerTick()
    {
        let filterFactor: Double = headingSmoothingFactor
        let newHeading = self.trackingManager.heading
        
        if(self.headingSmoothingFactor == 1 || fabs(currentHeading - self.trackingManager.heading) > 50)
        {
            currentHeading = self.trackingManager.heading
        }
        else
        {
            currentHeading = (newHeading * filterFactor) + (currentHeading  * (1.0 - filterFactor))
        }
        
        //self.overlayView.frame = self.overlayFrame()
        self.updateAnnotationsForCurrentHeading()
        //logText("Heading: \(self.trackingManager.heading)")
        
        //NSLog("A \(trackingManager.userLocation?.coordinate.latitude)")
        //NSLog("B \(trackingManager.userLocation?.coordinate.longitude)")
        //NSLog("C \(self.trackingManager.heading) \(currentHeading)")
        
        self.araview!.removeFromSuperview()
        
        if atmIsNear
        {
          self.overlayView.addSubview(self.araview!)
        }
        
    }
    
    func findCloseATMS() {
        atmIsNear = false
        for (thing) in self.listOfAtms {
          let lat = thing["lat"]
          let lon = thing["lon"]
          let loc = CLLocation(latitude: lat as! CLLocationDegrees, longitude: lon as! CLLocationDegrees)
          let d = loc.distance(from: trackingManager.userLocation!)
            
          if d < 10
          {
            atmIsNear = true
            nearestAtm = thing
          }            
        }
    }
    
    func loadAtms(lat: Double, lon: Double) {
        let URL: NSURL = NSURL(string: "https://kidbank.team/api/v1/atms?lat=\(lat)&lon=\(lon)")!
        let request:NSMutableURLRequest = NSMutableURLRequest(url:URL as URL)
        request.httpMethod = "GET"
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: {(data, response, error) in
            
            do {
                
                let parsedData = try JSONSerialization.jsonObject(with: data!, options: []) as! [String:Any]
                let list = parsedData["result"] as! NSArray
              
                for (thing) in list {
                  self.listOfAtms.append(thing as! NSDictionary)
                }
                self.findCloseATMS()
            } catch let error as NSError {
                print(error)
            }
        });
        
        task.resume()
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateUserLocation: CLLocation?)
    {
        NSLog("didUpdateUserLocation \(trackingManager.userLocation)");
        
        let foo = trackingManager.userLocation
        
        if foo == nil {
          return
        }
        if listOfAtms.count == 0 {
            loadAtms(lat: (trackingManager.userLocation?.coordinate.latitude)!, lon: (trackingManager.userLocation?.coordinate.longitude)!)
        } else {
            findCloseATMS()
        }
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateReloadLocation: CLLocation?)
    {
        NSLog("didUpdateReloadLocation \(trackingManager.userLocation)");
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didFailToFindLocationAfter elapsedSeconds: TimeInterval)
    {
        NSLog("didFailToFindLocationAfter");
    }
    
    fileprivate func startCamera(notifyLocationFailure: Bool)
    {
        self.cameraSession.startRunning()
        self.trackingManager.startTracking(notifyLocationFailure: notifyLocationFailure)
        self.displayTimer = CADisplayLink(target: self, selector: #selector(ARViewController.displayTimerTick))
        self.displayTimer?.add(to: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
    }
    
    
    fileprivate class OverlayView: UIView
    {
       
    }
    
}



