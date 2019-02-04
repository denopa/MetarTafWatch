//
//  runwayCalculations.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 03/02/2019.
//  Copyright © 2019 Patrick de Nonneville. All rights reserved.
//

import Foundation

class wind : NSObject {
    
    var direction : Double!
    var speed : Double!
    override init(){
        direction = 0
        speed = 0
    }
    
    func sind(degrees: Double!) -> Double {
        return(sin(degrees * .pi / 180.0))
    }
    
    func cosd(degrees: Double!) -> Double {
        return(cos(degrees * .pi / 180.0))
    }
    
    func headwind(runway : String!) -> Double {
        let runwayHeading : Double = Double(runway) ?? 00
        let component : Double = cosd(degrees : direction - runwayHeading)
        return(component)
    }
    
    func crosswind(runway : String!) -> Double {
        let runwayHeading : Double = Double(runway) ?? 00
        let component : Double = sind(degrees : direction - runwayHeading)
        return(component)
    }
}

func windFromMetar(metarWind : String!) -> wind {
    let windReturn = wind()
    windReturn.direction = Double(metarWind[..<metarWind.index(metarWind.startIndex, offsetBy: 3)])
    windReturn.speed = Double(metarWind[metarWind.index(metarWind.startIndex, offsetBy: 3)..<metarWind.index(metarWind.startIndex, offsetBy: 5)])
    return(windReturn)
}
