//
//  ViewController.swift
//  MetarTaf
//
//  Created by Patrick de Nonneville on 15/01/2019.
//  Copyright © 2019 Patrick de Nonneville. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {

    let locationManager = CLLocationManager()

    @IBOutlet weak var altitudeLabel: UILabel!
    @IBAction func requestLocationServices(_ sender: Any) {
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        if CLLocationManager.locationServicesEnabled() {
            print("starting location updates")
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestLocation()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        DispatchQueue.main.async {
            let location: CLLocation = locations.last! as CLLocation
            print("this is the location :\(String(describing: location))")
            print("this is the altitude :\(String(describing: location.altitude))")
            self.altitudeLabel.text = ("GPS Altitude : \(String(format: "%.00f", location.altitude * 3.28084)) feet")
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Problem getting the location")
        print(error.localizedDescription)
    }
    
}
