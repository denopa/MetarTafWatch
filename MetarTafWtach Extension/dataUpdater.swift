//
//  dataUpdater.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 22/01/2019.
//  Copyright © 2019 Patrick de Nonneville. All rights reserved.
//

import WatchKit
import Foundation
import Solar

class dataUpdater {
    //
    let AVWX_API_KEY = Bundle.main.infoDictionary?["AVWX_API_KEY"] as? String
    
    func getMetar(airport : String!, completionHandler: @escaping ([String?], Error?) -> Void) {
        // the getTaf method has more detailed comments. 'airport' can actually be a location in the format of a string "lat, lont"
        let urlString = "http://avwx.rest/api/metar/\(String(describing: airport!))?options=info&format=json&onfail=error&token=\(AVWX_API_KEY!)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        print("getting METAR for \(String(describing: airport!))")
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if data != nil {
                print("got METAR for \(String(describing: airport!))")
                if let metarDic = try? MetarData(String(data :data!, encoding: .utf8)!) {
                    if (metarDic.flightRules) != nil {
                        print("inside metarDic for \(String(describing: airport!)), conditions \(String(describing: metarDic.flightRules!))")
                        let flightConditions = metarDic.flightRules ?? " "
                        var metarText = metarDic.sanitized ?? "missing sanitized"
                        let metarTime = metarDic.time?.repr ?? "missing time"
                        let windDirection = metarDic.windDirection?.repr ?? "0"
                        let windSpeed = metarDic.windSpeed?.repr ?? "0"
                        let metarAge = howOldIsMetar(metarDate: metarTime)
                        let station = metarDic.station ?? "missing station"
                        metarText = metarText.replacingOccurrences(of: "\(String(describing: airport!)) \(metarTime) ", with: "")
                        completionHandler([flightConditions, metarText, metarTime, windDirection, windSpeed, metarAge, station], nil)
                    }
                    else {
                        print("metar data could not be jsonified")
                    }
                }
            }
            else {
                print("metar data was nil")
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
                    airportsArray[count].flightConditions = metarArray[0] ?? "missing flight conditions"
                    airportsArray[count].metar = metarArray[1] ?? "missing metar"
                    airportsArray[count].metarTime = metarArray[2] ?? "missing time"
                    airportsArray[count].windDirection = Double(metarArray[3] ?? "0") ?? 0
                    airportsArray[count].windSpeed = Double(metarArray[4] ?? "0") ?? 0
                    airportsArray[count].metarAge = metarArray[5] ?? "missing age"
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
                    completionHandler(nil)
                }
            }
        }
    }
    
    func getTaf(airport : String!, completionHandler: @escaping ([Any?], NSError?) -> Void) {
        //using  completion handler to deal with asynchronous process
        var nextFlightConditions = ""
        let urlString = "http://avwx.rest/api/taf/\(String(describing: airport!))?options=info&format=json&onfail=error&token=\(AVWX_API_KEY!)"
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
        //request.addValue(AVWX_API_KEY!, forHTTPHeaderField: "Authorization")
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData //otherwise it just keeps loading the same data from the local cache
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if data != nil {
                if let tafDic = try? TafData(String(data :data!, encoding: .utf8)!) {
                    //if let is a failsafe, checking a json object was actually returned
                    if (tafDic.station) != nil { //using tafDic? because not sure if there is a Station field, but this line allows us to check the tafDic has the right kind of data before loading everything
                        let forecast = tafDic.forecast
                        let tafTime = tafDic.time?.repr ?? ""
                        let (forecastArray, numberOfForecasts) = self.createForecastArray(forecast: forecast!)
                        for i in forecast!.indices {//running through all the forecasts to find the next one
                            let endTime = ((forecast![i].endTime?.repr ?? "0000") as NSString).integerValue
                            if (nextForecast == "...") && (endTime > currentTime) && (i > 0){ //last condition avoids taking the first taf
                                if forecast![i].flightRules != nil {
                                    nextFlightConditions = forecast![i].flightRules ?? ""
                                    nextWindSpeed = forecast![i].windSpeed?.repr ?? ""
                                    nextForecast = forecast![i].sanitized ?? ""
                                    nextForecastHeader = self.createTafHeader(prob: String(describing:(forecast?[i].probability?.repr ?? "")), tafType: String(describing: forecast?[i].type ?? ""), startTime: String(describing: forecast?[i].startTime?.repr ?? ""), endTime: String(describing: forecast?[i].endTime?.repr ?? ""))
                                    }
                            }
                        }
                        let i = forecast?.indices.last ?? 0 //if no next forecast, take the last available
                        if nextForecast == "..." {
                            if forecast![i].flightRules != nil {
                                nextFlightConditions = forecast![i].flightRules ?? ""
                                nextWindSpeed = forecast![i].windSpeed?.repr ?? ""
                                nextForecast = forecast![i].sanitized ?? ""
                                nextForecastHeader = self.createTafHeader(prob: String(describing:(forecast?[i].probability?.repr ?? "")), tafType: String(describing: forecast?[i].type ?? ""), startTime: String(describing: forecast?[i].startTime?.repr ?? ""), endTime: String(describing: forecast?[i].endTime?.repr ?? ""))
                            }
                        }
                        let tafText = tafDic.raw ?? "missing"
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
        if taf.count>9 {
            taf = String(taf[taf.index(taf.startIndex, offsetBy: 10)...])
        }
        return(taf)
    }
    
    func createForecastArray(forecast: [MetarTafWtach_Extension.Forecast]) -> ([[String]], Int) { //create an array with individual forecasts from TAF
        var forecastArray : [[String]] = []
        var counter : Int = 0
        for i in forecast.indices {
            counter += 1
            let forecastHeader = self.createTafHeader(prob:  String(describing:(forecast[i].probability?.repr ?? "")), tafType: String(describing: forecast[i].type ?? ""), startTime: String(describing: forecast[i].startTime?.repr ?? ""), endTime: String(describing: forecast[i].endTime?.repr ?? ""))
            var flightConditions = String(describing: forecast[i].flightRules ?? "")
            let fullTaf = String(describing: forecast[i].sanitized ?? "")
            let taf = cleanTaf(fullTaf: fullTaf, prob: String(describing:(forecast[i].probability?.repr ?? "")), tafType: String(describing: forecast[i].type ?? ""))
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
    
    func getStation(airport : String!, completionHandler: @escaping (String?, String?, [Double?], [Double?], String?, String?, NSError?) -> Void) {
        //get Station information
        let urlString = "http://avwx.rest/api/station/\(String(describing: airport!))?token=\(AVWX_API_KEY!)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        //request.addValue(AVWX_API_KEY!, forHTTPHeaderField: "Authorization")
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if data != nil {
                if let station = try? JSONSerialization.jsonObject(with: data!, options: []) {
                    let stationDic = station as? [String: Any]
                    if (stationDic?["name"]) != nil {
                        let city = stationDic?["city"] as? String ?? " "
                        let elevation = stationDic?["elevation_ft"] as? NSNumber ?? -999
                        let runways = stationDic?["runways"] as? [[String: Any]] ?? [["ident1":"37","ident2":"37"]]
                        let lat = stationDic?["latitude"] as? Double ?? 0
                        let long = stationDic?["longitude"] as? Double ?? 0
                        let solar = Solar(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))
                        let dateFormatter = DateFormatter()
                        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                        dateFormatter.dateFormat = "HHmm"
                        let sunrise = dateFormatter.string(from: solar?.sunrise ?? Date.init())
                        let sunset = dateFormatter.string(from: solar?.sunset ?? Date.init())
                        var runwayList : [Double] = []
                        var runwayLengthList : [Double] = []
                        for i in runways.indices {
                            var runwayName = String(describing: runways[i]["ident1"] ?? "37")
                            let runwayLength = runways[i]["length_ft"] as? Double ?? 0
                            var runway = Double(runwayName[..<runwayName.index(runwayName.startIndex, offsetBy: 2)]) //getting rid of the "R" or "L" designator if present
                            runwayList.append(runway ?? 0)
                            runwayLengthList.append(runwayLength)
                            runwayName = String(describing: runways[i]["ident2"] ?? "37") //take the reciprocal
                            runway = Double(runwayName[..<runwayName.index(runwayName.startIndex, offsetBy: 2)]) //getting rid of the "R" or "L" designator if present
                            runwayList.append(runway ?? 0)
                            runwayLengthList.append(runwayLength)
                        }
                        //runwayList = Array(Set(runwayList)) //making it a set to remove duplicates, then back to array
                        completionHandler(city, NumberFormatter().string(from: elevation), runwayList, runwayLengthList, sunrise, sunset, nil)
                    }
                }
            }
        }
        task.resume()
    }
    
    func updateStationForRow(count : Int!, completionHandler: @escaping (NSError?) -> Void){
        // puts in static airport data
        self.getStation(airport: airportsArray[count].airportName.replacingOccurrences(of: "⊕", with: "")) { (city, elevation, runwayList, runwayLengthList, sunrise, sunset, error) -> Void in
            if error != nil{
                print(error!)
                completionHandler(error!)
            }
            else{
                airportsArray[count].city = city ?? "missing"
                airportsArray[count].elevation = elevation ?? "missing"
                airportsArray[count].runwayList = runwayList as! [Double]
                    completionHandler(nil)
                airportsArray[count].runwayLengthList = runwayLengthList as! [Double]
                    completionHandler(nil)
                airportsArray[count].sunrise = sunrise ?? "missing"
                airportsArray[count].sunset = sunset ?? "missing"
            }
        }
    }
    
    func saveAirports(){
        let appGroupId = "group.com.nonneville.com.metarTaf"
        let defaults = UserDefaults(suiteName: appGroupId)
        defaults?.set(airportsList, forKey: "airports")
    }
}
