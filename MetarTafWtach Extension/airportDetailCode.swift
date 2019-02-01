//
//  airportDetailCode.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 22/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit

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
        self.elevationLabel.setText("Elevation: \(weather[2]) feet")
        self.runwaysLabel.setText("Runways: \(weather[3]), \(weather[4]) ")
        self.cityLabel.setText(weather[5])
    }
}
