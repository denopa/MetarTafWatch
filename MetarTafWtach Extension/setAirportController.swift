//
//  setAirportController.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 02/01/2019.
//  Copyright © 2019 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit
import Foundation

class setAirportController: WKInterfaceController {

    @IBOutlet weak var setAirportTable: WKInterfaceTable!
    @IBOutlet weak var runwayUnitSelector: WKInterfaceSwitch!
    @IBOutlet weak var altitudeUnitSelector: WKInterfaceSwitch!
    
    @IBAction func runwayUnitSwitch(_ value: Bool) {
        let appGroupId = "group.com.nonneville.com.metarTaf"
        let defaults = UserDefaults(suiteName: appGroupId)
        if value {
            defaults?.register(defaults: ["runwayUnit" : "feet"])
            runwayUnit = "feet"
        }
        else {
            defaults?.register(defaults: ["runwayUnit" : "m"])
            runwayUnit = "m"
        }
    }
    
    @IBAction func altitudeUnitSwitch(_ value: Bool) {
        let appGroupId = "group.com.nonneville.com.metarTaf"
        let defaults = UserDefaults(suiteName: appGroupId)
        if value {
            defaults?.register(defaults: ["pressureUnit" : "InHg"])
            pressureUnit = "InHg"
        }
        else {
            defaults?.register(defaults: ["pressureUnit" : "hPa"])
            pressureUnit = "hPa"
        }
        print("pressure unit \(pressureUnit)")
    }
    
    
    var airportsList = ["EGLL", "EHAM", "LFLY", "LFTH"]
    
    func setTheTable(){
        self.setAirportTable.setNumberOfRows(self.airportsList.count, withRowType: "setAirportRowController")
        for count in 0...3 {
            let row = self.setAirportTable.rowController(at: count) as! setAirportRowController
            let airport = self.airportsList[count]
            row.setAirportLabel.setText("change \(airport)")
        }
        print("setAirport Table set")
    }
    
    func setRunwaySwitch(){
        self.runwayUnitSelector.setOn(runwayUnit == "feet")
    }
    
    func setAltitudeSwitch(){
        self.altitudeUnitSelector.setOn(pressureUnit == "InHg")
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        loadAirports()
        setTheTable()
        setRunwaySwitch()
        setAltitudeSwitch()
        // Configure interface objects here.
    }
    
    override func willActivate() {
        super.willActivate()
        loadAirports()
        setTheTable()
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) { //pushes into the input screen
        self.pushController(withName: "inputAirport", context: rowIndex)
    }
    
    func loadAirports(){
        let appGroupId = "group.com.nonneville.com.metarTaf"
        let defaults = UserDefaults(suiteName: appGroupId)
        if let airports = defaults?.object(forKey: "airports"){
            print("loading defaults to airportsList")
            self.airportsList = airports as! [String]
        } else {
            print("init defaults")
            defaults?.register(defaults: ["airports" : self.airportsList])
        }
    }
}
