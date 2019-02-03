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
        // the getTaf method has more detailed comments
        let urlString = "http://avwx.rest/api/metar/\(String(describing: airport!))?format=json&onfail=cache"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        //let configuration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = TimeInterval(10)
        //configuration.timeoutIntervalForResource = TimeInterval(10)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if data != nil {
                if let metar = try? JSONSerialization.jsonObject(with: data!, options: []) {
                    let metarDic = metar as? [String: Any]
                    if (metarDic?["Flight-Rules"]) != nil {
                        let flightConditions = metarDic?["Flight-Rules"] as? String ?? " "
                        let metarText = metarDic?["Sanitized"] as? String ?? "missing"
                        let metarTime = metarDic?["Time"] as? String ?? "missing"
                        let windSpeed = metarDic?["Wind-Speed"] as? String ?? "0"
                        let metarAge = howOldIsMetar(metarDate: metarTime)
                        completionHandler([flightConditions, metarText, metarTime, windSpeed, metarAge], nil)
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
        if count == 0 {
        }
        self.getMetar(airport: airportsArray[count].airportName) { (metarArray, error) -> Void in
            if error != nil{
                print(error!)
            }
            else{
                if metarArray[0] != nil {//To get rid of optional
                    airportsArray[count].flightConditions = metarArray[0] ?? "missing"
                    airportsArray[count].metar = metarArray[1] ?? "missing"
                    airportsArray[count].metarTime = metarArray[2] ?? "missing"
                    airportsArray[count].windSpeed = Int(metarArray[3] ?? "0") ?? 0
                    airportsArray[count].metarAge = metarArray[4] ?? "missing"
                    if airportsArray[count].windSpeed>15 {
                        airportsArray[count].windSymbol = "💨"
                    }
                    else {
                        airportsArray[count].windSymbol = ""
                    }
                    if count == 0 { //check if an update to the complication and the background refresh call is required
                        if (airportsArray[count].metarTime != oldMetarTime) || hasAirportChanged {
                            Refresher.scheduleUpdate(){(error) in}
                            updateComplications()
                            hasAirportChanged = false
                        }
                    }
                    NSLog("Metar for \(airportsArray[count].airportName) : \(airportsArray[count].flightConditions) \(airportsArray[count].metarTime)")
                    completionHandler(nil)
                }
            }
        }
    }
    
    func getTaf(airport : String!, completionHandler: @escaping ([Any?], NSError?) -> Void) {
        //using  completion handler to deal with asynchronous process
        var nextFlightConditions = ""
        let urlString = "http://avwx.rest/api/taf/\(String(describing: airport!))?format=json&onfail=cache"
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
        tafHeader += tafType + " " + startTime + "/" + endTime + " "
        return(tafHeader)
    }
    
    func createForecastArray(forecast: [[String: Any]]) -> ([[String]], Int) {
        var forecastArray : [[String]] = []
        var counter : Int = 0
        for i in forecast.indices {
            counter += 1
            let nextForecastHeader = self.createTafHeader(prob: (forecast[i]["Probability"] as! String), tafType: String(describing: forecast[i]["Type"] ?? ""), startTime: String(describing: forecast[i]["Start-Time"] ?? ""), endTime: String(describing: forecast[i]["End-Time"] ?? ""))
            let flightConditions = String(describing: forecast[i]["Flight-Rules"] ?? "")
            let fullTaf = String(describing: forecast[i]["Sanitized"] ?? "")
            let taf = fullTaf.replacingOccurrences(of: nextForecastHeader, with: "")
            forecastArray.append([nextForecastHeader, flightConditions, taf])
        }
        return(forecastArray, counter)
    }
    
    func airportsListToArray(airportsList : [String]) -> [airportClass] {
        var airportsArray : [airportClass] = []
        for i in 0...3 {
            airportsArray.append(airportClass(ICAO : airportsList[i]))
        }
        return airportsArray
    }
    
    func getStation(airport : String!, completionHandler: @escaping ([String?], NSError?) -> Void) {
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
                        let elevation = stationDic?["elevation"] as? NSNumber ?? -999
                        let runways = stationDic?["runways"] as! [[String: Any]]
                        let runway1 = runways[0]["ident1"] as? String ?? "missing"
                        let runway2 = runways[0]["ident2"] as? String ?? "missing"
                        completionHandler([city, NumberFormatter().string(from: elevation), runway1, runway2], nil)
                    }
                }
            }
        }
        task.resume()
    }
    
    func updateStationForRow(count : Int!, completionHandler: @escaping (NSError?) -> Void){
        // initialises the airportArray for that row, and puts in airport data
        let airportName = airportsArray[count].airportName
        airportsArray[count] = airportClass(ICAO: airportName)
        self.getStation(airport: airportsArray[count].airportName) { (stationArray, error) -> Void in
            if error != nil{
                print(error!)
                completionHandler(error!)
            }
            else{
                if stationArray[0] != nil {//To get rid of optional
                    airportsArray[count].city = stationArray[0] ?? "missing"
                    airportsArray[count].elevation = stationArray[1] ?? "missing"
                    airportsArray[count].runway1 = stationArray[2] ?? "missing"
                    airportsArray[count].runway2 = stationArray[3] ?? "missing"
                    completionHandler(nil)
                }
            }
        }
    }
    
}
