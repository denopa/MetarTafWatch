//
//  dataUpdater.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 22/01/2019.
//  Copyright © 2019 Patrick de Nonneville. All rights reserved.
//

import WatchKit
import Foundation

class dataUpdater {
    
    func getMetar(airport : String!, completionHandler: @escaping ([String?], Error?) -> Void) {
        // the getTaf method has more detailed comments. 'airport' can actually be a location in the format of a string "lat, lont"
        print("getmetar \(String(describing: airport!))")
        let urlString = "http://avwx.rest/api/legacy/metar/\(String(describing: airport!))?options=info&format=json&onfail=error"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if data != nil {
                if let metar = try? JSONSerialization.jsonObject(with: data!, options: []) {
                    let metarDic = metar as? [String: Any]
                    if (metarDic?["Flight-Rules"]) != nil {
                        let flightConditions = metarDic?["Flight-Rules"] as? String ?? " "
                        var metarText = metarDic?["Sanitized"] as? String ?? "missing"
                        let metarTime = metarDic?["Time"] as? String ?? "missing"
                        let windDirection = metarDic?["Wind-Direction"] as? String ?? "0"
                        let windSpeed = metarDic?["Wind-Speed"] as? String ?? "0"
                        let metarAge = howOldIsMetar(metarDate: metarTime)
                        let station = metarDic?["Station"] as? String ?? "missing"
                        metarText = metarText.replacingOccurrences(of: "\(String(describing: airport!)) \(metarTime) ", with: "")
                        completionHandler([flightConditions, metarText, metarTime, windDirection, windSpeed, metarAge, station], nil)
                    }
                }
            }
            else {
                completionHandler([], error)
            }
        }
        task.resume()
    }
    
    func updateMetarForRow(count: Int, completionHandler: @escaping (NSError?) -> Void){
        let oldMetarTime = airportsArray[0].metarTime
        var airport = airportsArray[count].airportName
        if airportsArray[count].nearest { //if using nearest, send location instead of ICAO
            airport = airportsArray[count].location
        }
        self.getMetar(airport: airport) { (metarArray, error) -> Void in
            if error != nil{
                print(error!)
            }
            else{
                if metarArray[0] != nil {//To get rid of optional
                    airportsArray[count].flightConditions = metarArray[0] ?? "missing"
                    airportsArray[count].metar = metarArray[1] ?? "missing"
                    airportsArray[count].metarTime = metarArray[2] ?? "missing"
                    airportsArray[count].windDirection = Double(metarArray[3] ?? "0") ?? 0
                    airportsArray[count].windSpeed = Double(metarArray[4] ?? "0") ?? 0
                    airportsArray[count].metarAge = metarArray[5] ?? "missing"
                    if airportsArray[count].windSpeed>15 {
                        airportsArray[count].windSymbol = "💨"
                    }
                    else {
                        airportsArray[count].windSymbol = ""
                    }
                    if (airportsArray[count].nearest)&&(airportsArray[count].airportName != "⊕\(String(describing: metarArray[6]))") {
                        hasAirportChanged = true
                        airportsArray[count].airportName = "⊕\(metarArray[6] ?? "missing")"
                        print("airport \(count) renamed to ⊕\(metarArray[6] ?? "missing")")
                        airportsList[count] = metarArray[6] ?? "missing"
                        dataUpdater().updateStationForRow(count: count) { (error) in
                            if error != nil{
                                print(error!)
                            }
                        }
                        self.saveAirports()
                    }
                    if count == 0 { //check if an update to the complication and the background refresh call is required
                        if (airportsArray[count].metarTime != oldMetarTime) || hasAirportChanged {
                            Refresher.scheduleUpdate(){(error) in}
                            updateComplications()
                            hasAirportChanged = false
                        }
                    }
                    NSLog("Metar for \(airportsArray[count].airportName) : \(airportsArray[count].flightConditions) \(airportsArray[count].metarTime) nearest: \(airportsArray[count].nearest)")
                    completionHandler(nil)
                }
            }
        }
    }
    
    func getTaf(airport : String!, completionHandler: @escaping ([Any?], NSError?) -> Void) {
        //using  completion handler to deal with asynchronous process
        var nextFlightConditions = ""
        let urlString = "http://avwx.rest/api/legacy/taf/\(String(describing: airport!))?format=json&onfail=error"
        let url = URL(string: urlString)!
        let date = NSDate.init() as Date //UTC time to compare with the info on TAFS
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let currentTime = 100 * day + hour //day+time in TAF format, e.g. 0123
        var nextForecastHeader = "" //eg "PROB30 TEMPO 0123/0206" or "BCMG 0123/0206"
        var nextWindSpeed = "0"
        var nextForecast = "..."
        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData //otherwise it just keeps loading the same data from the local cache
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if data != nil {
                if let taf = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) {
                    //if let is a failsafe, checking a json object was actually returned
                    let tafDic = taf as? [String: Any] //as? because the format of the json is not guaranteed
                    if (tafDic?["Station"]) != nil { //using tafDic? because not sure if there is a Station field, but this line allows us to check the tafDic has the right kind of data before loading everything
                        let forecast = tafDic?["Forecast"] as! [[String: Any]]
                        let tafTime = tafDic?["Time"] as! String
                        let (forecastArray, numberOfForecasts) = self.createForecastArray(forecast: forecast)
                        for i in forecast.indices {//running through all the forecasts to find the next one
                            let endTime = (forecast[i]["End-Time"] as! NSString).integerValue
                            if (nextForecast == "...") && (endTime > currentTime) && (i > 0){ //last condition avoids taking the first taf
                                    if forecast[i]["Flight-Rules"] != nil {
                                        nextFlightConditions = forecast[i]["Flight-Rules"] as! String
                                        nextWindSpeed = forecast[i]["Wind-Speed"] as! String
                                        nextForecast = forecast[i]["Sanitized"] as! String
                                        nextForecastHeader = self.createTafHeader(prob: (forecast[i]["Probability"] as! String), tafType: String(describing: forecast[i]["Type"] ?? ""), startTime: String(describing: forecast[i]["Start-Time"] ?? ""), endTime: String(describing: forecast[i]["End-Time"] ?? ""))
                                    }
                            }
                        }
                        let i = forecast.indices.last ?? 0 //if no next forecast, take the last available
                        if nextForecast == "..." {
                            if forecast[i]["Flight-Rules"] != nil {
                                nextFlightConditions = forecast[i]["Flight-Rules"] as! String
                                nextWindSpeed = forecast[i]["Wind-Speed"] as! String
                                nextForecast = forecast[i]["Sanitized"] as! String
                                nextForecastHeader = self.createTafHeader(prob: (forecast[i]["Probability"] as! String), tafType: String(describing: forecast[i]["Type"] ?? ""), startTime: String(describing: forecast[i]["Start-Time"] ?? ""), endTime: String(describing: forecast[i]["End-Time"] ?? ""))
                            }
                        }
                        let tafText = tafDic?["Raw-Report"] as? String ?? "missing"
                        completionHandler([nextFlightConditions, tafText, nextForecastHeader, nextWindSpeed, nextForecast, forecast, tafTime, forecastArray, numberOfForecasts], nil)
                        // a completion handler deals with asynchronous processes
                    }
                }
            }
        }
        task.resume()
    }
    
    func createTafHeader(prob : String!, tafType : String!, startTime : String!, endTime : String!) -> String {
        var tafHeader = (prob != "" ? "PROB" + prob + " " : "") // if prob not empty, return "PROBprob " otheriwse ""
        tafHeader = tafHeader + tafType + " " + startTime + "/" + endTime + " "
        return(tafHeader)
    }
    
    func cleanTaf(fullTaf : String!, prob: String!, tafType: String!) -> String {//aims to remove "FROM", "PROB" etc and date
        var taf : String = fullTaf.replacingOccurrences(of: "PROB\(String(describing: prob!)) ", with: "")
        taf = taf.replacingOccurrences(of: "\(String(describing: tafType!)) ", with: "")
        taf = String(taf[taf.index(taf.startIndex, offsetBy: 10)...])
        return(taf)
    }
    
    func createForecastArray(forecast: [[String: Any]]) -> ([[String]], Int) { //create an array with individual forecasts from TAF
        var forecastArray : [[String]] = []
        var counter : Int = 0
        for i in forecast.indices {
            counter += 1
            let forecastHeader = self.createTafHeader(prob: (forecast[i]["Probability"] as! String), tafType: String(describing: forecast[i]["Type"] ?? ""), startTime: String(describing: forecast[i]["Start-Time"] ?? ""), endTime: String(describing: forecast[i]["End-Time"] ?? ""))
            var flightConditions = String(describing: forecast[i]["Flight-Rules"] ?? "")
            let fullTaf = String(describing: forecast[i]["Sanitized"] ?? "")
            let taf = cleanTaf(fullTaf: fullTaf, prob: (forecast[i]["Probability"] as! String), tafType: String(describing: forecast[i]["Type"] ?? ""))
            if taf.range(of: "CAVOK") != nil {// if the TAF contains CAVOK
                flightConditions = "VFR"
            }
            if taf.range(of: "FG") != nil {// if the TAF contains Fog
                flightConditions = "LIFR"
            }
            forecastArray.append([forecastHeader, flightConditions, taf])
        }
        return(forecastArray, counter)
    }
    
    func airportsListToArray(airportsList : [String]) -> [airportClass] {// inits an array of airportClass from the list of airports
        var airportsArray : [airportClass] = []
        for i in 0...3 {
            airportsArray.append(airportClass(ICAO : airportsList[i]))
            airportsArray[i].nearest = nearestList[i]
        }
        return airportsArray
    }
    
    func getStation(airport : String!, completionHandler: @escaping (String?, String?, [Double?], NSError?) -> Void) {
        //get Station information
        let urlString = "http://avwx.rest/api/station/\(String(describing: airport!))"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if data != nil {
                if let station = try? JSONSerialization.jsonObject(with: data!, options: []) {
                    let stationDic = station as? [String: Any]
                    if (stationDic?["name"]) != nil {
                        let city = stationDic?["city"] as? String ?? " "
                        print("got station info for \(city)")
                        let elevation = stationDic?["elevation"] as? NSNumber ?? -999
                        let runways = stationDic?["runways"] as? [[String: Any]] ?? [["ident1":"37","ident2":"37"]]
                        var runwayList : [Double] = []
                        for i in runways.indices {
                            var runwayName = String(describing: runways[i]["ident1"] ?? "37")
                            var runway = Double(runwayName[..<runwayName.index(runwayName.startIndex, offsetBy: 2)]) //getting rid of the "R" or "L" designator if present
                            runwayList.append(runway ?? 0)
                            runwayName = String(describing: runways[i]["ident2"] ?? "37") //take the reciprocal
                            runway = Double(runwayName[..<runwayName.index(runwayName.startIndex, offsetBy: 2)]) //getting rid of the "R" or "L" designator if present
                            runwayList.append(runway ?? 0)
                        }
                        runwayList = Array(Set(runwayList)) //making it a set to remove duplicates, then back to array
                        completionHandler(city, NumberFormatter().string(from: elevation), runwayList, nil)
                    }
                }
            }
        }
        task.resume()
    }
    
    func updateStationForRow(count : Int!, completionHandler: @escaping (NSError?) -> Void){
        // puts in static airport data
        self.getStation(airport: airportsArray[count].airportName.replacingOccurrences(of: "⊕", with: "")) { (city, elevation, runwayList, error) -> Void in
            if error != nil{
                print(error!)
                completionHandler(error!)
            }
            else{
                airportsArray[count].city = city ?? "missing"
                airportsArray[count].elevation = elevation ?? "missing"
                airportsArray[count].runwayList = runwayList as! [Double]
                    completionHandler(nil)
            }
        }
    }
    
    func saveAirports(){
        let appGroupId = "group.com.nonneville.com.metarTaf"
        let defaults = UserDefaults(suiteName: appGroupId)
        defaults?.set(airportsList, forKey: "airports")
    }
}
