//
//  weatherSymbolKeyCode.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 24/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit

class weatherSymbolKeyCode: WKInterfaceController {
    
    @IBOutlet weak var weatherLegendTable: WKInterfaceTable!
    
    let flightConditionsColor = [["VFR" , UIColor.blue.withAlphaComponent(0.3)], ["MVFR" , UIColor.green.withAlphaComponent(0.3)], ["IFR" , UIColor.orange.withAlphaComponent(0.87)], ["LIFR", UIColor.red.withAlphaComponent(0.7)]]
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        setTheLegend()
        // Configure interface objects here.
    }
    
    func setTheLegend(){
        self.weatherLegendTable.setNumberOfRows(4, withRowType: "weatherLegendRowController")
        for count in 0...3 {
            let row = self.weatherLegendTable.rowController(at: count) as! weatherLegendRowController
            let rowLegend = flightConditionsColor[count].first as! String
            let rowColor = flightConditionsColor[count].last as! UIColor
            row.weatherLegendLabel.setText(rowLegend)
            row.weatherLegendGroup.setBackgroundColor(rowColor)
        }
    }
}
