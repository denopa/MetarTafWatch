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
    
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        let weather = context as! [String]
        self.metarLabel.setText("METAR \(weather[0])")
        self.tafLabel.setText("TAF \(weather[1])")
        self.elevationLabel.setText("\(weather[2]) feet")
        self.runwaysLabel.setText("Runways: \(weather[3]), \(weather[4]) ")
        self.cityLabel.setText(weather[5])
    }
}
