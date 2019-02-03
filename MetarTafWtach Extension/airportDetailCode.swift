//
//  airportDetailCode.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 22/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit

let flightConditionsColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" : UIColor(displayP3Red: 0.09, green: 0.15, blue: 0.19, alpha: 1), "MVFR" : UIColor(displayP3Red: 0.06, green: 0.17, blue: 0.09, alpha: 1), "IFR" : UIColor(displayP3Red: 0.19, green: 0.12, blue: 0.02, alpha: 1), "LIFR": UIColor(displayP3Red: 0.18, green: 0.05, blue: 0.05, alpha: 1)] //alternative pastel scheme

class airportDetailCode: WKInterfaceController {
    @IBOutlet weak var metarLabel: WKInterfaceLabel!
    @IBOutlet weak var tafLabel: WKInterfaceLabel!
    @IBOutlet weak var elevationLabel: WKInterfaceLabel!
    @IBOutlet weak var runwaysLabel: WKInterfaceLabel!
    @IBOutlet weak var cityLabel: WKInterfaceLabel!
    @IBOutlet weak var metarGroup: WKInterfaceGroup!
    @IBOutlet weak var tafTable: WKInterfaceTable!
    
    func setTafRow(rowIndex: Int!, count : Int!){
        let row = self.tafTable.rowController(at: count) as! tafRowController
        let tafColor = flightConditionsColor[airportsArray[rowIndex].forecastArray[count][1]]
        row.tafRowGroup.setBackgroundColor(tafColor)
        row.tafRowHeader.setText(airportsArray[rowIndex].forecastArray[count][0])
        row.tafRowForecast.setText(airportsArray[rowIndex].forecastArray[count][2])
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        let rowIndex = context as! Int
        
        //airport section
        self.cityLabel.setText(airportsArray[rowIndex].city)
        self.elevationLabel.setText("\(airportsArray[rowIndex].elevation) feet")
        self.runwaysLabel.setText("Runways: \(airportsArray[rowIndex].runway1), \(airportsArray[rowIndex].runway2) ")
        
        //metar section
        self.metarLabel.setText("METAR \(airportsArray[rowIndex].metar)")
        let metarLabelColor = flightConditionsColor[airportsArray[rowIndex].flightConditions]
        self.metarGroup.setBackgroundColor(metarLabelColor)
        
        //taf section
        self.tafLabel.setText("TAF \(airportsArray[rowIndex].tafTime)")
        let rows : Int = airportsArray[rowIndex].numberOfForecasts
        self.tafTable.setNumberOfRows(rows, withRowType: "tafRowController")
        for count in 0..<airportsArray[rowIndex].numberOfForecasts {
            self.setTafRow(rowIndex: rowIndex, count : count)
        }
    }
    
}
