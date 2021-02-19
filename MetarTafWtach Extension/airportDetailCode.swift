//
//  airportDetailCode.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 22/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit

var rowIndex = 0

let flightConditionsColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" : UIColor(displayP3Red: 0.09, green: 0.15, blue: 0.19, alpha: 1), "MVFR" : UIColor(displayP3Red: 0.06, green: 0.17, blue: 0.09, alpha: 1), "IFR" : UIColor(displayP3Red: 0.19, green: 0.12, blue: 0.02, alpha: 1), "LIFR": UIColor(displayP3Red: 0.18, green: 0.05, blue: 0.05, alpha: 1)] //alternative pastel scheme

//let flightConditionsTextColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" :  UIColor.cyan, "MVFR" : UIColor.green, "IFR" : UIColor.orange, "LIFR": UIColor.red]

let flightConditionsTextColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" : UIColor(displayP3Red: 0.44, green: 0.78, blue: 0.86, alpha: 1), "MVFR" : UIColor(displayP3Red: 0.4, green: 0.85, blue: 0.49, alpha: 1), "IFR" : UIColor(displayP3Red: 1, green: 0.58, blue: 0.25, alpha: 1), "LIFR": UIColor(displayP3Red: 0.92, green: 0.30, blue: 0.24, alpha: 1)] //describes the color the lettering will take depending on weather conditions

class airportDetailCode: WKInterfaceController {
    @IBOutlet weak var metarHeader: WKInterfaceLabel!
    @IBOutlet weak var metarLabel: WKInterfaceLabel!
    @IBOutlet weak var tafHeader: WKInterfaceLabel!
    @IBOutlet weak var elevationLabel: WKInterfaceLabel!
    @IBOutlet weak var dayLabel: WKInterfaceLabel!
    @IBOutlet weak var runwaysLabel: WKInterfaceLabel!
    @IBOutlet weak var cityLabel: WKInterfaceLabel!
    @IBOutlet weak var metarGroup: WKInterfaceGroup!
    @IBOutlet weak var tafTable: WKInterfaceTable!
    
    @IBAction func changeAirport() {
        self.pushController(withName: "inputAirport", context: rowIndex)
    }
    
    
    func setTafRow(rowIndex: Int!, count : Int!){
        let row = self.tafTable.rowController(at: count) as! tafRowController
        let tafColor = flightConditionsColor[airportsArray[rowIndex].forecastArray[count][1]]
        let tafTextColor = flightConditionsTextColor[airportsArray[rowIndex].forecastArray[count][1]]
        row.tafForecastRowGroup.setBackgroundColor(tafColor)
        row.tafRowHeader.setText(airportsArray[rowIndex].forecastArray[count][0])
        row.tafRowForecast.setText(airportsArray[rowIndex].forecastArray[count][2])
        row.tafRowForecast.setTextColor(tafTextColor)
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        rowIndex = context as! Int
        
        //airport section
        self.cityLabel.setText(airportsArray[rowIndex].city)
        self.elevationLabel.setText("\(airportsArray[rowIndex].elevation) feet")
        print(airportsArray[rowIndex].sunset)
        self.dayLabel.setText("Day \(airportsArray[rowIndex].sunrise)/\(airportsArray[rowIndex].sunset)z")
        if (airportsArray[rowIndex].runwayList != [])&&(airportsArray[rowIndex].windDirection != 999){
            let bestRunwayArray : [String] = runwayCalculations().findBestRunway(runwayNames: airportsArray[rowIndex].runwayList, windDirection: airportsArray[rowIndex].windDirection, windSpeed: airportsArray[rowIndex].windSpeed)
            if bestRunwayArray[0] != "998" {
                let bestRunway = bestRunwayArray[0]
                let headwind = bestRunwayArray[1]
                let crosswind = bestRunwayArray[2]
                let indicator = bestRunwayArray[3]
                self.runwaysLabel.setText("RW\(bestRunway) 🔽\(headwind)kt \(indicator + crosswind)kt")
            }
        }
       
        //metar section
        self.metarHeader.setText("METAR \(airportsArray[rowIndex].metarTime)")
        self.metarLabel.setText("\(airportsArray[rowIndex].metar)")
        let metarLabelColor = flightConditionsColor[airportsArray[rowIndex].flightConditions]
        self.metarGroup.setBackgroundColor(metarLabelColor)
        let metarLabelTextColor = flightConditionsTextColor[airportsArray[rowIndex].flightConditions]
        self.metarLabel.setTextColor(metarLabelTextColor)
        
        //taf section
        self.tafHeader.setText("TAF \(airportsArray[rowIndex].tafTime)")
        let rows : Int = airportsArray[rowIndex].numberOfForecasts
        self.tafTable.setNumberOfRows(rows, withRowType: "tafRowController")
        for count in 0..<airportsArray[rowIndex].numberOfForecasts {
            self.setTafRow(rowIndex: rowIndex, count : count)
        }
        
    }
    
}
