//
//  inputAirport.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 02/01/2019.
//  Copyright © 2019 Patrick de Nonneville. All rights reserved.
//

import UIKit
import WatchKit

class inputAirport: WKInterfaceController {
    
    var letterValue = ["E","G","L", "L"]
    var airportName = "EGLL"
    var airportIndex = 0
    
    @IBOutlet weak var setAirportLabelName: WKInterfaceLabel!
    
    @IBOutlet weak var letter1: WKInterfacePicker!
    @IBAction func letter1Changed(_ value: Int) {
        letterValue[0] = alphabet[value]
        print(combinedLetters())
    }
    
    @IBOutlet weak var letter2: WKInterfacePicker!
    @IBAction func letter2Changed(_ value: Int) {
        letterValue[1] = alphabet[value]
        print(combinedLetters())
    }
    
    @IBOutlet weak var letter3: WKInterfacePicker!
    @IBAction func letter3Changed(_ value: Int) {
        letterValue[2] = alphabet[value]
        print(combinedLetters())
    }
    
    @IBOutlet weak var letter4: WKInterfacePicker!
    @IBAction func letter4Changed(_ value: Int) {
        letterValue[3] = alphabet[value]
        print(combinedLetters())
    }
    
    @IBAction func acceptAirport() {
        saveAirports()
        self.popToRootController()
    }
    
    let alphabet : [String] = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        airportIndex = context as! Int
        self.airportName = airportsList[airportIndex]
        var airportCode = [0,0,0,0]
        for (i,l) in airportName.enumerated() {
            letterValue[i] = String(l)
            for c in 0..<alphabet.count {
                if letterValue[i] == alphabet[c] {
                    airportCode[i] = c
                }
            }
        }

        
        let pickerItems : [WKPickerItem] = alphabet.map {
            let pickerItem = WKPickerItem()
            pickerItem.title = $0
            return pickerItem
        }
        letter1.setItems(pickerItems)
        letter2.setItems(pickerItems)
        letter3.setItems(pickerItems)
        letter4.setItems(pickerItems)
        
        letter1.setSelectedItemIndex(airportCode[0])
        letter2.setSelectedItemIndex(airportCode[1])
        letter3.setSelectedItemIndex(airportCode[2])
        letter4.setSelectedItemIndex(airportCode[3])
        
        
    }
    
    func combinedLetters() -> String {
        var letters = letterValue[0]
        for i in 1...3 {
            letters += letterValue[i]
        }
        self.airportName = letters
        self.setAirportLabelName.setText(letters)
        return letters
    }
    
    func saveAirports(){
        let appGroupId = "group.com.nonneville.com.metarTaf"
        let defaults = UserDefaults(suiteName: appGroupId)
        airportsList[airportIndex] = airportName
        defaults?.set(airportsList, forKey: "airports")
        airportsArray[airportIndex] = airportClass(ICAO : airportName)
    }
}
