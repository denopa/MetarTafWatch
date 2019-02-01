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
                        if airportsArray[count].metarTime != oldMetarTime {
                            Refresher.scheduleUpdate(){(error) in}
                            let complicationServer = CLKComplicationServer.sharedInstance()
                            for complication in complicationServer.activeComplications! {
                                complicationServer.reloadTimeline(for: complication)
                                NSLog("updating complication from updateMetarForRow()")
                            }
                        }
                    }
                    NSLog("Metar for \(airportsArray[count].airportName) : \(airportsArray[count].flightConditions) \(airportsArray[count].metarTime)")
                    completionHandler(nil)
                }
            }
        }
    }
    
    func getTaf(airport : String!, completionHandler: @escaping ([String?], NSError?) -> Void) {
        //using  completion handler to deal with asynchronous process
        let nextFlightConditionsSymbol = "" //actually not used anymore
        let urlString = "http://avwx.rest/api/taf/\(String(describing: airport!))?format=json&onfail=cache"
        let url = URL(string: urlString)!
        let date = NSDate.init() as Date //UTC time to compare with the info on TAFS
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let currentTime = 100 * day + hour
        var tafTime = String(currentTime) //datetime in the Metar format
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
                        for i in forecast.indices {//running through all the forecasts to find the next one
                            let startTime = (forecast[i]["Start-Time"] as! NSString).integerValue
                            if startTime > currentTime {
                                if nextForecast == "..." {
                                    if forecast[i]["Flight-Rules"] != nil {
                                        nextWindSpeed = forecast[i]["Wind-Speed"] as! String
                                        nextForecast = forecast[i]["Sanitized"] as! String
                                    }
                                    tafTime = String(startTime)
                                }
                            }
                        }
                        let i = forecast.indices.last ?? 0 //if no next forecast, take the last available
                        if nextForecast == "..." {
                            if forecast[i]["Flight-Rules"] != nil {
                                nextWindSpeed = forecast[i]["Wind-Speed"] as! String
                                nextForecast = forecast[i]["Sanitized"] as! String
                            }
                        }
                        let tafText = tafDic?["Raw-Report"] as? String ?? "missing"
                        completionHandler([nextFlightConditionsSymbol, tafText, tafTime, nextWindSpeed, nextForecast], nil)
                        // a completion handler deals with asynchronous processes
                    }
                }
            }
        }
        task.resume()
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
                        let elevation = round(stationDic?["elevation"] as? Double ?? -999)
                        let runways = stationDic?["runways"] as! [[String: Any]]
                        let runway1 = runways[0]["ident1"] as? String ?? "missing"
                        let runway2 = runways[0]["ident2"] as? String ?? "missing"
                        completionHandler([city, String(elevation), runway1, runway2], nil)
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
