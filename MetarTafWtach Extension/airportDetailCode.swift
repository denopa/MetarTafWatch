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
    

    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        let rowIndex = context as! Int
        self.metarLabel.setText("METAR \(airportsArray[rowIndex].metar)")
        let metarLabelColor = flightConditionsColor[airportsArray[rowIndex].flightConditions]
        self.metarGroup.setBackgroundColor(metarLabelColor)
        self.tafLabel.setText("TAF \(airportsArray[rowIndex].taf)")
        self.elevationLabel.setText("\(airportsArray[rowIndex].elevation) feet")
        self.runwaysLabel.setText("Runways: \(airportsArray[rowIndex].runway1), \(airportsArray[rowIndex].runway2) ")
        self.cityLabel.setText(airportsArray[rowIndex].city)
    }
}
