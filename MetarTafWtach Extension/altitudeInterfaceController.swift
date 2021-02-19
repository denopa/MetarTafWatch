//
//  altitudeInterfaceController.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 26/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit
import CoreMotion
import UserNotifications

class altitudeInterfaceController: WKInterfaceController, CLLocationManagerDelegate {

    @IBOutlet weak var altitudeLabel: WKInterfaceLabel!
    @IBOutlet weak var gpsAltitudeLabel: WKInterfaceLabel!
    @IBOutlet weak var pressureLabel: WKInterfaceLabel!
    @IBOutlet weak var qnhOrDeltaP: WKInterfaceLabel!
    @IBOutlet weak var qnhLabel: WKInterfaceLabel!
    
    lazy var altimeter = CMAltimeter()
    let locationManager = CLLocationManager()
    var altitude : Double = -3000
    var gpsAltitude : Double = -3000
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        /*let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .criticalAlert]
        center.requestAuthorization(options: options) {
            (granted, error) in
            if !granted {
                print("You will not get altitude alerts")
            }
        }*/
        self.qnhOrDeltaP.setText("GPS derived QNH")
        self.altitudeLabel.setText("...")
        self.pressureLabel.setText("...")
        self.gpsAltitudeLabel.setText("...")
        self.qnhLabel.setText("...")
        locationManager.delegate = self
        if CLLocationManager.locationServicesEnabled() {
            self.gpsAltitudeLabel.setText("updating...")
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        } else {
            self.gpsAltitudeLabel.setText("open the iPhone app to grant location")
            let h0 = { print("ok")}
            let action1 = WKAlertAction(title: "Got it", style: .default, handler:h0)
            self.presentAlert(withTitle: "", message: "To get GPS altitude readings, you need to open the iPhone app and press 'Request Location Services'. You only need to do that once.", preferredStyle: WKAlertControllerStyle.alert, actions:[action1])
        }
       
        startAltimeter()

    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        self.locationManager.stopUpdatingLocation()
        self.stopAltimeter()
    }
    
    func startAltimeter() {
        print("Started relative altitude updates.")
        // Check if altimeter feature is available
        if (CMAltimeter.isRelativeAltitudeAvailable()) {
            // Start altimeter updates, add it to the main queue
            self.altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main, withHandler: { (altitudeData:CMAltitudeData?, error:Error?) in
                if (error != nil) {
                    // If there's an error, stop updating and alert the user
                    //self.altimeterSwitch.isOn = false
                    self.stopAltimeter()
                    let h0 = { print("ok")}
                    let action1 = WKAlertAction(title: "Accept", style: .default, handler:h0)
                    self.presentAlert(withTitle: "Error", message: "Barometer not available on this device.", preferredStyle: WKAlertControllerStyle.alert, actions:[action1])
                    // Reset labels
                    self.altitudeLabel.setText("-")
                    self.pressureLabel.setText("-")
                } else {
                    //let altitude = altitudeData!.relativeAltitude.floatValue
                    self.altitude = Double((1013-altitudeData!.pressure.floatValue*10)*25.879322442072244)    // Relative altitude in feet
                    let pressure = altitudeData!.pressure.floatValue            // Pressure in kilopascals
                    // Update labels, truncate float to 0 decimal points
                    self.altitudeLabel.setText("\(String(format: "%.00f", self.altitude)) ft")
                    self.pressureLabel.setText("\(String(format: "%.00f", pressure*10)) hPa")
                    if self.gpsAltitude > -1000 {
                        if abs(self.altitude - self.gpsAltitude) < 1999 { //estimate QNH if gps and pressure altitudes are close enough
                            let qnh = (1013 + (self.gpsAltitude - self.altitude) * 0.036622931)
                            self.qnhOrDeltaP.setText("GPS derived QNH")
                            self.qnhLabel.setText("\(String(format: "%.00f", qnh)) hPa")
                        }
                        else { //calculate DeltaP
                            self.qnhOrDeltaP.setText("GPS derived DeltaP")
                            let deltaP = 0.01450377 * (self.gpsAltitude - self.altitude) * 0.036622931
                            self.qnhLabel.setText("\(String(format: "%.1f", deltaP)) Psi")
                        }
                    }

                    if self.altitude < 10000 {
                            //in-app warning
    /*                      let h1 = { print("ok")}
                            let action2 = WKAlertAction(title: "Accept", style: .default, handler:h1)
                            self.presentAlert(withTitle: "Warning", message: "Cabin altitude exceeds 10,000 feet.", preferredStyle: WKAlertControllerStyle.alert, actions:[action2])
     */
                    }
                }
            })
        } else {
            let h0 = { print("ok")}
            let action1 = WKAlertAction(title: "Accept", style: .default, handler:h0)
            self.presentAlert(withTitle: "Error", message: "Barometer not available on this device.", preferredStyle: WKAlertControllerStyle.alert, actions:[action1])
            // Reset labels
            self.altitudeLabel.setText("-")
            self.pressureLabel.setText("-")
        }
    }
    
    func stopAltimeter() {
        
        self.altimeter.stopRelativeAltitudeUpdates() // Stop updates
        print("Stopped relative altitude updates.")
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        DispatchQueue.main.async {
            let location: CLLocation = locations.last! as CLLocation
            let verticalAccuracy = location.verticalAccuracy
            if verticalAccuracy < 100 {
                self.gpsAltitude = location.altitude * 3.28084
                self.gpsAltitudeLabel.setText("\(String(format: "%.00f", self.gpsAltitude)) ±\(String(format: "%.00f", verticalAccuracy)) ft")
                if self.altitude > -1000 {
                    if abs(self.altitude - self.gpsAltitude) < 1999 { //estimate QNH if gps and pressure altitudes are close enough
                        let qnh = (1013 + (self.gpsAltitude - self.altitude) * 0.036622931)
                        let qnhAccuracy = verticalAccuracy * 0.036622931
                        self.qnhOrDeltaP.setText("GPS derived QNH")
                        self.qnhLabel.setText("\(String(format: "%.00f", qnh)) ±\(String(format: "%.00f", qnhAccuracy)) hPa")
                    }
                    else { //calculate DeltaP
                        self.qnhOrDeltaP.setText("GPS derived DeltaP")
                        let deltaP = 0.01450377 * (self.gpsAltitude - self.altitude) * 0.036622931
                        self.qnhLabel.setText("\(String(format: "%.1f", deltaP)) Psi")
                    }
                }

                print("sufficient precision achieved")
            }
            else {
                self.gpsAltitudeLabel.setText("accuracy \(String(format: "%.00f", verticalAccuracy * 3.28084)) ft")
                self.qnhOrDeltaP.setText("GPS derived QNH")
                self.qnhLabel.setText("insufficient accuracy")
            }
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Prblem getting the location")
        print(error.localizedDescription)
    }

}
