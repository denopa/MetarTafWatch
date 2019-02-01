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
    
    var airportsList = ["EGLL", "EHAM", "LFLY", "LFTH"]
    
    func setTheTable(){
        self.setAirportTable.setNumberOfRows(self.airportsList.count, withRowType: "setAirportRowController")
        for count in 0...3 {
            let row = self.setAirportTable.rowController(at: count) as! setAirportRowController
            let airport = self.airportsList[count]
            row.setAirportLabel.setText("\(airport)")
        }
        print("setAirport Table set")
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        loadAirports()
        setTheTable()
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
