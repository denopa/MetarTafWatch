//
//  InterfaceController.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 19/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import WatchKit
import Foundation
import CoreMotion
import UserNotifications
import CoreLocation

class MainInterfaceController: WKInterfaceController , URLSessionDelegate, CLLocationManagerDelegate {

    // todo: 
    
    @IBAction func Updatedisplay() {updateDataAndDisplay()}
    
    @IBAction func setAirports() {self.pushController(withName: "setAirports", context: Any?.self)}
    
    @IBAction func seeWeatherKey() {self.pushController(withName: "weatherLegend", context: Any?.self)}
    
    @IBAction func seeAltitude() {self.pushController(withName: "altitudeAlerter", context: Any?.self)}
    
    @IBOutlet weak var airportTable: WKInterfaceTable!
    
    //let flightConditionsColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" : UIColor(displayP3Red: 0.09, green: 0.15, blue: 0.19, alpha: 1), "MVFR" : UIColor(displayP3Red: 0.06, green: 0.17, blue: 0.09, alpha: 1), "IFR" : UIColor(displayP3Red: 0.19, green: 0.12, blue: 0.02, alpha: 1), "LIFR": UIColor(displayP3Red: 0.18, green: 0.05, blue: 0.05, alpha: 1)] //alternative pastel scheme
    let flightConditionsColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" :  UIColor.blue.withAlphaComponent(0.3), "MVFR" : UIColor.green.withAlphaComponent(0.3), "IFR" : UIColor.orange.withAlphaComponent(0.87), "LIFR": UIColor.red.withAlphaComponent(0.7)] //describes the color the row will take depending on weather conditions
    let nextFlightConditionsTextColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" : UIColor(displayP3Red: 0.44, green: 0.78, blue: 0.86, alpha: 1), "MVFR" : UIColor(displayP3Red: 0.4, green: 0.85, blue: 0.49, alpha: 1), "IFR" : UIColor(displayP3Red: 1, green: 0.58, blue: 0.25, alpha: 1), "LIFR": UIColor(displayP3Red: 0.92, green: 0.30, blue: 0.24, alpha: 1)] //describes the color the TAF lettering will take depending on weather conditions
    var timerSeconds = Timer() //used to refresh Zulu watch
    var timerMinutes = Timer() //used to refresh Metar age
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) { //pushes into the detail screen
        self.pushController(withName: "airportDetail", context: rowIndex)
    }
    
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        DispatchQueue.main.async { //starting the Zulu watch and the Metar age update timer
            self.startZuluWatch()
            self.startupdateAge()
        }
        if self.airportTable.numberOfRows == 0 {//if the table has not yet been set, set it
            loadAirportsList() //load defaults
            //print("first time user ? \(firstTimeUser)")
//            if firstTimeUser {
//                let h0 = { print("ok")}
//                let action1 = WKAlertAction(title: "Got it", style: .default, handler:h0)
//                self.presentAlert(withTitle: "", message: "Force touch to access the menu.", preferredStyle: WKAlertControllerStyle.alert, actions:[action1])
//                firstTimeUser = false
//            }
            airportsArray = dataUpdater().airportsListToArray(airportsList: airportsList) //take the new list of airports and populate airportsArray
            self.airportTable.setNumberOfRows(4, withRowType: "airportRowController")
        }
        updateDisplay()
        if WKExtension.shared().applicationState == WKApplicationState.active {//only update the data if app is active
            //dataUpdater().getLocation()
            updateDataAndDisplay()
        }
        
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        DispatchQueue.main.async {
            self.stopZuluWatch()
            self.stopUpdateAge()
        }
    }
    
    func updateRow(count: Int!){
        let row = self.airportTable.rowController(at: count) as! airportRowController
        let metarColor = flightConditionsColor[airportsArray[count].flightConditions]
        row.windLabel.setText(airportsArray[count].windSymbol)
        row.airportLabel.setText(airportsArray[count].airportName)
        row.self.tafLabel.setText("\(airportsArray[count].nextForecastHeader + airportsArray[count].nextFlightConditions)")
        row.metarTimeLabel.setText("\(airportsArray[count].metarAge)' ago")
        row.airportRowGroup.setBackgroundColor(metarColor)
    }
    
    func updateDisplay(){
        for count in 0...3 {
            self.updateRow(count: count)
        }
    }
    
    func updateDataAndDisplay(){
        self.getLocation()
        for count in 0...3 {
            let row = self.airportTable.rowController(at: count) as! airportRowController
            dataUpdater().updateMetarForRow(count: count) { (error) -> Void in
                if error != nil{
                    print(error!)
                }
                else{
                    self.updateRow(count: count)
                }
            }
            var airport = airportsArray[count].airportName
            if airportsArray[count].nearest { //if using nearest, send location instead of ICAO
                airport = airportsArray[count].location
            }
            dataUpdater().getTaf(airport: airport) { (tafArray, error) -> Void in
                if error != nil{
                    print(error!)
                }
                else{
                    //[nextFlightConditions, tafText, nextForecastHeader, nextWindSpeed, nextForecast, forecast, tafTime, forecastArray, numberOfForecasts]
                    if tafArray[0] != nil {
                        airportsArray[count].nextFlightConditions =  String(describing: tafArray[0] ?? "")
                        airportsArray[count].taf = String(describing: tafArray[1] ?? "missing")
                        airportsArray[count].nextForecastHeader = String(describing: tafArray[2] ?? "...")
                        airportsArray[count].nextWindSpeed = Int(String(describing: tafArray[3] ?? "0")) ?? 0
                        airportsArray[count].nextForecast = String(describing: tafArray[4] ?? "...")
                        airportsArray[count].tafTime = String(describing: tafArray[6] ?? "...")
                        airportsArray[count].forecast = tafArray[5] as! [Any]
                        airportsArray[count].forecastArray = tafArray[7] as! [[String]]
                        airportsArray[count].numberOfForecasts = tafArray[8] as! Int
                        if airportsArray[count].nextWindSpeed>15 {
                            airportsArray[count].nextWindSymbol = "💨"
                        }
                        row.self.tafLabel.setText("\(airportsArray[count].nextForecastHeader + airportsArray[count].nextFlightConditions)")
                        if airportsArray[count].nextFlightConditions != airportsArray[count].flightConditions {
                            let tafTextColor = self.nextFlightConditionsTextColor[airportsArray[count].nextFlightConditions]
                            row.self.tafLabel.setTextColor(tafTextColor)
                        }
                    }
                }
            }
            if airportsArray[count].city == "" {//if the static airport info is not present, load it up
                dataUpdater().updateStationForRow(count: count) { (error) in
                    if error != nil{
                        print(error!)
                    }
                }
            }
        }
        
    }
    
    func startupdateAge(){
        self.updateAge()
        timerMinutes = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.updateAge), userInfo: nil, repeats: true)
    }
    
    @objc func updateAge(){
        for count in 0...3 {
            if airportsArray[count].metarTime != "..." {
                airportsArray[count].metarAge = howOldIsMetar(metarDate: airportsArray[count].metarTime)
                let row = self.airportTable.rowController(at: count) as! airportRowController
                row.self.metarTimeLabel.setText("\(airportsArray[count].metarAge)' ago")
            }
        }
    }
    
    func stopUpdateAge(){
        timerMinutes.invalidate()
    }
    
    func startZuluWatch(){
        self.updateZuluWatch()
        timerSeconds = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateZuluWatch), userInfo: nil, repeats: true)
    }
    
    @objc func updateZuluWatch(){
        let nowDate = NSDate.init() as Date //UTC time to compare with the info on TAFS
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "HH:mm"
        self.setTitle("\(dateFormatter.string(from: nowDate))Z")
    }
    
    func stopZuluWatch(){
        timerSeconds.invalidate()
    }

    func lastUpdateTime() -> String {
        let nowDate = NSDate.init() as Date //UTC time to compare with the info on TAFS
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "HH:mm"
        return ("\(dateFormatter.string(from: nowDate))Z")
    }
    
    let locationManager = CLLocationManager()
    
    func getLocation(){
        let nowDate = Date()
        if nowDate.timeIntervalSince(lastPositionUpdate)/60 > 15 {
            if CLLocationManager.locationServicesEnabled() {
                self.locationManager.delegate = self
                locationManager.requestLocation()
            } else {
                locationManager.requestWhenInUseAuthorization()
                print("location not authorized")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        DispatchQueue.main.async {
            let location: CLLocation = locations.last! as CLLocation
            let loc = "\(String(describing: round(location.coordinate.latitude*100)/100)),\(String(describing: round(location.coordinate.longitude*100)/100))"
            print("current location \(loc)")
            for i in 0...3 {
                airportsArray[i].location = loc
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
    
}
