//
//  airportRowController.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 19/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit

class airportRowController: NSObject {

    @IBOutlet weak var airportRowGroup: WKInterfaceGroup!
    @IBOutlet weak var airportLabel: WKInterfaceLabel!
    @IBOutlet weak var tafLabel: WKInterfaceLabel!
    @IBOutlet weak var metarTimeLabel: WKInterfaceLabel!
    @IBOutlet weak var windLabel: WKInterfaceLabel!
}
