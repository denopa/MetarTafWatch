//
//  runwayCalculations.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 03/02/2019.
//  Copyright © 2019 Patrick de Nonneville. All rights reserved.
//

import Foundation

class runwayCalculations {
    
    func sind(degrees: Double!) -> Double {
        return(sin(degrees * .pi / 180.0))
    }
    
    func cosd(degrees: Double!) -> Double {
        return(cos(degrees * .pi / 180.0))
    }
    
    func headwind(runwayHeading : Double!, windDirection: Double!, windSpeed: Double!) -> Double {
        let component : Double = windSpeed * cosd(degrees : windDirection - 10 * runwayHeading)
        return(component)
    }
    
    func crosswind(runwayHeading : Double!, windDirection: Double!, windSpeed: Double!) -> Double {
        let component : Double = windSpeed * sind(degrees : windDirection - 10 * runwayHeading)
        return(abs(component))
    }
    
    
    func findBestRunway(runwayNames :[Double]!, windDirection: Double!, windSpeed: Double!) -> [String] {
        var headwindRunways :[Double] = []
        for i in runwayNames.indices { //find runways with a headwind
            if headwind(runwayHeading: runwayNames[i], windDirection: windDirection, windSpeed: windSpeed) > 0 {
                headwindRunways.append(runwayNames[i])
            }
        }
        if headwindRunways != [] {
            var bestRunway = headwindRunways[0]
            var minCrosswind = crosswind(runwayHeading: bestRunway, windDirection: windDirection, windSpeed: windSpeed)
            var crosswindIndicator = ((windDirection - 10 * bestRunway) > 0 ? "◀️" : "▶️")
            for i in headwindRunways.indices {
                let runwayCrosswind = crosswind(runwayHeading: headwindRunways[i], windDirection: windDirection, windSpeed: windSpeed)
                if  runwayCrosswind < minCrosswind {
                    minCrosswind = runwayCrosswind
                    bestRunway = headwindRunways[i]
                    crosswindIndicator = ((windDirection - 10 * bestRunway) > 0 ? "◀️" : "▶️")
                }
            }
            let bestRunwayString = String(format: "%.00f", (bestRunway))
            let minCrosswindString = String(format: "%.00f", (minCrosswind))
            return [bestRunwayString, String(format: "%.00f", (headwind(runwayHeading: bestRunway, windDirection: windDirection, windSpeed: windSpeed))), minCrosswindString, crosswindIndicator]
        }
        return ["998"]
    }
}


