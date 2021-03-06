//
//  SecondViewController.swift
//  KidBank
//
//  Created by A Arrow on 2/3/17.
//  Copyright © 2017 higher.team. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class SecondViewController: ARViewController, ARDataSource {
    
    @IBOutlet var addNewButton: UIButton!
    
    func checkSession(_ sender: UITapGestureRecognizer) {

        
        if let username = UserDefaults.standard.value(forKey: "kb_username")
        {
          print("\(nearestAtm) username is: " + (username as! String))
            
            if atmIsNear {
                let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
                
                let ac = mainStoryboard.instantiateViewController(withIdentifier: "atm") as! AtmController
                ac.nearestAtm = nearestAtm
                
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.window?.rootViewController?.present(ac, animated: true, completion: {})
            } else {
                self.addAtmLocation()
            }
        } else {
            let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
            
            let vc = mainStoryboard.instantiateViewController(withIdentifier: "test123") as! CreateViewController
            
            vc.view.backgroundColor = UIColor.white
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.window?.rootViewController?.present(vc, animated: true, completion: {})
        }
        

    }
    
    func addAtmLocation() {
        //NSLog("addAtmLocation \(sender)")
        //locationManager.startUpdatingLocation()
        let ul = self.trackingManager.userLocation
        
        if ul == nil {
            return
        }
        
        let lat = self.trackingManager.userLocation?.coordinate.latitude
        let lon = self.trackingManager.userLocation?.coordinate.longitude
        let lats:String = String(format:"%.\(15)f", lat!)
        let lons:String = String(format:"%.\(15)f", lon!)
    
        saveStillImage(lats: lats, lons: lons)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let tbc = appDelegate.window?.rootViewController as! UITabBarController
        
        let rc = appDelegate.window?.rootViewController?.childViewControllers[2] as! ReviewController
        
        let dict : NSDictionary = [ "lat" : lats, "lon" : lons]
        rc.list.append(dict)
        tbc.selectedIndex = 2
        rc.tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dataSource = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.checkSession(_:)))
        self.view.addGestureRecognizer(tapGesture)
    }
    
    func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView
    {
        let annotationView = TestAnnotationView()
        annotationView.frame = CGRect(x: 100,y: 100,width: 150,height: 50)
        return annotationView;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


}

