//
//  SecondViewController.swift
//  KidBank
//
//  Created by A Arrow on 2/3/17.
//  Copyright © 2017 higher.team. All rights reserved.
//

import UIKit
import CoreLocation


class SecondViewController: ARViewController, ARDataSource {
    
    @IBAction func addAtmLocation(sender: UIButton) {
        let bodyData = "key1=value&key2=value&key3=value"
        //request.HTTPBody = bodyData.dataUsingEncoding(NSUTF8StringEncoding);
        NSLog("\(bodyData)")
    }
    
    fileprivate func getRandomLocation(centerLatitude: Double, centerLongitude: Double, delta: Double) -> CLLocation
    {
        var lat = centerLatitude
        var lon = centerLongitude
        
        let latDelta = -(delta / 2) + drand48() * delta
        let lonDelta = -(delta / 2) + drand48() * delta
        lat = lat + latDelta
        lon = lon + lonDelta
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    fileprivate func getDummyAnnotations(centerLatitude: Double, centerLongitude: Double, delta: Double, count: Int) -> Array<ARAnnotation>
    {
        var annotations: [ARAnnotation] = []
        
        srand48(3)
        for i in stride(from: 0, to: count, by: 1)
        {
            let annotation = ARAnnotation()
            annotation.location = self.getRandomLocation(centerLatitude: centerLatitude, centerLongitude: centerLongitude, delta: delta)
            annotation.title = "POI \(i)"
            annotations.append(annotation)
        }
        return annotations
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let lat:CLLocationDegrees = 33.988914
        
        let lon:CLLocationDegrees = -118.400969
        
        let delta = 0.05
        let count = 50
         let dummyAnnotations = self.getDummyAnnotations(centerLatitude: lat, centerLongitude: lon, delta: delta, count: count)
        
        
        self.dataSource = self
        self.maxDistance = 0
        self.maxVisibleAnnotations = 100
        self.maxVerticalLevel = 5
        self.headingSmoothingFactor = 0.05
        self.trackingManager.userDistanceFilter = 25
        self.trackingManager.reloadDistanceFilter = 75
        self.setAnnotations(dummyAnnotations)
        self.uiOptions.debugEnabled = true
        self.uiOptions.closeButtonEnabled = true
        
    }
    
    func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView
    {
        // Annotation views should be lightweight views, try to avoid xibs and autolayout all together.
        let annotationView = TestAnnotationView()
        annotationView.frame = CGRect(x: 0,y: 0,width: 150,height: 50)
        return annotationView;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

