//
//  ExtensionDelegate.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 19/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import WatchKit
import UserNotifications
import UIKit
import CoreMotion
import Foundation
import ClockKit

class airportClass : NSObject {
    var airportName : String
    var nearest : Bool
    var flightConditions : String
    var metar : String
    var metarTime : String
    var metarAge : String
    var windDirection : Double
    var windSpeed : Double
    var windSymbol : String
    var forecast : Any
    var numberOfForecasts : Int
    var forecastArray : [[String]]
    var nextFlightConditions : String
    var nextForecast : String
    var taf : String
    var tafTime : String
    var nextForecastHeader : String
    var nextWindSpeed : Int
    var nextWindSymbol : String
    var city: String
    var elevation: String
    var runwayList: [Double]
    var runwayLengthList: [Double]
    var location : String
    var sunrise : String
    var sunset : String
    init(ICAO : String) {
        airportName = ICAO
        nearest  = false
        flightConditions = " " ///VFR, MVFR, IFR or LIFR from the METAR
        metar = "missing" //sanitised METAR
        metarTime = "..." //time the METAR was published
        metarAge = "..." //how old the METAR is in minutes
        windDirection = 999 //windDirection from the METAR
        windSpeed = 0 //windSpeed from the METAR
        windSymbol = "" //emoji for the METAR wind
        forecast = [nil] // array containing the TAF json output of sequential forecasts
        numberOfForecasts = 0 // the number of forecasts in the TAF
        forecastArray = [[]] // array of taf headers, flight conditions and sanitized TAF in the shape ["PROB30 TEMPO 0123/0206","IFR", "35012KT 9999 SCT02"]
        tafTime = "" //time the TAF was published
        nextFlightConditions = " " ///VFR, MVFR, IFR or LIFR from the next TAF section
        nextForecast = "..." //sanitised next TAF section
        taf = "missing" //full taf
        nextForecastHeader = "missing TAF" //eg "PROB30 TEMPO 0123/0206" or "BCMG 0123/0206" from next TAF section
        nextWindSpeed = 0 //windSpeed from the next TAF section
        nextWindSymbol = "" //emoji for the next TAF section wind
        city = ""
        elevation = "0"
        runwayList = []
        runwayLengthList = []
        location = "50.47,-0.1" //latitude, longgitude. Used only if nearest = true
        sunrise = "NA"
        sunset = "NA"
    }
}

var airportsArray = [airportClass(ICAO : "EGLL"), airportClass(ICAO : "LFOV"), airportClass(ICAO : "EBFN"), airportClass(ICAO : "EBBR")]
var airportsList = ["EGLF", "EGBB", "LFTH", "LFPO"]
var runwayUnit = "feet"
var nearestList = [true, false, false, false]
var hasAirportChanged: Bool = false
var firstTimeUser: Bool = false
var lastPositionUpdate : Date = Date(timeIntervalSinceNow: -20*60)

func loadAirportsList(){
    let appGroupId = "group.com.nonneville.com.metarTaf"
    let defaults = UserDefaults(suiteName: appGroupId)
    if let airports = defaults?.object(forKey: "airports"){
        airportsList = airports as! [String]
    } else {
        firstTimeUser = true
        defaults?.register(defaults: ["airports" : airportsList])
    }
    if let nearest = defaults?.object(forKey: "nearest"){
        nearestList = nearest as! [Bool]
    } else {
        firstTimeUser = true
        defaults?.register(defaults: ["nearest" : nearestList])
    }
    if let runwayUnitSetting = defaults?.object(forKey: "runwayUnit"){
        runwayUnit = runwayUnitSetting as! String
    } else {
        firstTimeUser = true
        defaults?.register(defaults: ["runwayUnitSetting" : "feet"])
    }
}

func howOldIsMetar(metarDate : String!) -> String {
    if metarDate == "..." { ///still on initial value
        return("40")
    }
    else {
        let nowDate = Date.init().zeroSeconds as Date //UTC time to compare with the info on TAFS
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "dd"
        let nowDay = Int(dateFormatter.string(from: nowDate)) ?? 0
        dateFormatter.dateFormat = "HH"
        let nowHour = Int(dateFormatter.string(from: nowDate)) ?? 0
        dateFormatter.dateFormat = "mm"
        let nowMinute = Int(dateFormatter.string(from: nowDate)) ?? 0
        let metarDay = Int(metarDate[..<metarDate.index(metarDate.startIndex, offsetBy: 2)]) ?? 0//this is how you get the first 2 characters of a String in Swift 😱
        let metarHour = Int(metarDate[metarDate.index(metarDate.startIndex, offsetBy: 2)...metarDate.index(metarDate.startIndex, offsetBy: 3)]) ?? 0 //how to get the 3rd and 4th characters
        let metarMinute = Int(metarDate[metarDate.index(metarDate.startIndex, offsetBy: 4)...metarDate.index(metarDate.startIndex, offsetBy: 5)]) ?? 0
        var minutes = (nowMinute - metarMinute) + 60 * (nowHour - metarHour)
        if nowDay>metarDay {
            minutes = minutes + 24 * 60 //dealing with overnight
        }
        return String(minutes + 1)
    }
}

func updateComplications(){
    let complicationServer = CLKComplicationServer.sharedInstance()
    for complication in complicationServer.activeComplications! {
        complicationServer.reloadTimeline(for: complication)
    }
}

class Refresher {
    static func scheduleUpdate(scheduledCompletion: @escaping (Error?) -> Void) {
        let age: Double? = Double(howOldIsMetar(metarDate: airportsArray[0].metarTime))
        let minutesToRefresh = max(3, 42 - (age ?? 0))
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: Date().addingTimeInterval(minutesToRefresh * 60), userInfo: nil, scheduledCompletion: scheduledCompletion)
    }
}

class ExtensionDelegate: NSObject, WKExtensionDelegate, URLSessionDelegate {

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        // Example scheduling of background task a minute in the future
        Refresher.scheduleUpdate { (error) in
        }
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                NSLog("background refresh started")
                dataUpdater().updateMetarForRow(count: 0){(error) in
                    if error != nil {
                        print("error executing background refresh \(String(describing: error))")
                    }
                    else {
                        NSLog("background data received")
                    }
                    Refresher.scheduleUpdate { (error) in
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                    }
                }
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}

extension WKSnapshotReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .appBackgrounded: return "appBackgrounded"
        case .appScheduled: return "appScheduled"
        case .complicationUpdate: return "complicationUpdate"
        case .prelaunch: return "prelaunch"
        case .returnToDefaultState: return "returnToDefaultState"
        @unknown default:
            return "returnToDefaultState"
        }
    }
}

extension Date {
    var zeroSeconds: Date {//used to reset seconds to 0
        get {
            let calender = Calendar.current
            let dateComponents = calender.dateComponents([.year, .month, .day, .hour, .minute], from: self)
            return calender.date(from: dateComponents)!
        }
    }
    
}
// generated Json classes for Metar and TAF via https://app.quicktype.io
//
//   let metarDic = try metarData(json)
//  let tafDic = try tafData(json)

// To parse the JSON, add this file to your project and do:
//
//   let metarData = try MetarData(json)

import Foundation

class MetarData: Codable {
    let meta: Meta?
    let altimeter: Altimeter?
    let clouds: [JSONAny]?
    let flightRules: String?
    let other: [JSONAny]?
    let sanitized: String?
    let visibility, windDirection: Altimeter?
    let windGust: Altimeter?
    let windSpeed: Altimeter?
    let raw, station: String?
    let time: Time?
    let remarks: String?
    let dewpoint: Altimeter?
    let remarksInfo: RemarksInfo?
    let runwayVisibility: [JSONAny]?
    let temperature: Altimeter?
    let windVariableDirection: [Altimeter]?
    let units: Units?
    let info: Info?
    
    enum CodingKeys: String, CodingKey {
        case meta, altimeter, clouds
        case flightRules = "flight_rules"
        case other, sanitized, visibility
        case windDirection = "wind_direction"
        case windGust = "wind_gust"
        case windSpeed = "wind_speed"
        case raw, station, time, remarks, dewpoint
        case remarksInfo = "remarks_info"
        case runwayVisibility = "runway_visibility"
        case temperature
        case windVariableDirection = "wind_variable_direction"
        case units, info
    }
    
    init(meta: Meta?, altimeter: Altimeter?, clouds: [JSONAny]?, flightRules: String?, other: [JSONAny]?, sanitized: String?, visibility: Altimeter?, windDirection: Altimeter?, windGust: Altimeter?, windSpeed: Altimeter?, raw: String?, station: String?, time: Time?, remarks: String?, dewpoint: Altimeter?, remarksInfo: RemarksInfo?, runwayVisibility: [JSONAny]?, temperature: Altimeter?, windVariableDirection: [Altimeter]?, units: Units?, info: Info?) {
        self.meta = meta
        self.altimeter = altimeter
        self.clouds = clouds
        self.flightRules = flightRules
        self.other = other
        self.sanitized = sanitized
        self.visibility = visibility
        self.windDirection = windDirection
        self.windGust = windGust
        self.windSpeed = windSpeed
        self.raw = raw
        self.station = station
        self.time = time
        self.remarks = remarks
        self.dewpoint = dewpoint
        self.remarksInfo = remarksInfo
        self.runwayVisibility = runwayVisibility
        self.temperature = temperature
        self.windVariableDirection = windVariableDirection
        self.units = units
        self.info = info
    }
}

class TafData: Codable {
    let meta: Meta?
    let raw, station: String?
    let time: Time?
    let remarks: String?
    let forecast: [Forecast]?
    let startTime, endTime: Time?
    let maxTemp, minTemp: String?
    let alts, temps: JSONNull?
    let units: Units?
    let info: Info?
    
    enum CodingKeys: String, CodingKey {
        case meta, raw, station, time, remarks, forecast
        case startTime = "start_time"
        case endTime = "end_time"
        case maxTemp = "max_temp"
        case minTemp = "min_temp"
        case alts, temps, units, info
    }
    
    init(meta: Meta?, raw: String?, station: String?, time: Time?, remarks: String?, forecast: [Forecast]?, startTime: Time?, endTime: Time?, maxTemp: String?, minTemp: String?, alts: JSONNull?, temps: JSONNull?, units: Units?, info: Info?) {
        self.meta = meta
        self.raw = raw
        self.station = station
        self.time = time
        self.remarks = remarks
        self.forecast = forecast
        self.startTime = startTime
        self.endTime = endTime
        self.maxTemp = maxTemp
        self.minTemp = minTemp
        self.alts = alts
        self.temps = temps
        self.units = units
        self.info = info
    }
}

class Forecast: Codable {
    let altimeter: String?
    let clouds: [JSONAny]?
    let flightRules: String?
    let other: [String]?
    let sanitized: String?
    let visibility, windDirection: Probability?
    let windGust: Probability?
    let windSpeed: Probability?
    let endTime: Time?
    let icing: [JSONAny]?
    let probability: Probability?
    let raw: String?
    let startTime: Time?
    let turbulance: [JSONAny]?
    let type: String?
    let windShear: String?
    
    enum CodingKeys: String, CodingKey {
        case altimeter, clouds
        case flightRules = "flight_rules"
        case other, sanitized, visibility
        case windDirection = "wind_direction"
        case windGust = "wind_gust"
        case windSpeed = "wind_speed"
        case endTime = "end_time"
        case icing, probability, raw
        case startTime = "start_time"
        case turbulance, type
        case windShear = "wind_shear"
    }
    
    init(altimeter: String?, clouds: [JSONAny]?, flightRules: String?, other: [String]?, sanitized: String?, visibility: Probability?, windDirection: Probability?, windGust: Probability?, windSpeed: Probability?, endTime: Time?, icing: [JSONAny]?, probability: Probability?, raw: String?, startTime: Time?, turbulance: [JSONAny]?, type: String?, windShear: String?) {
        self.altimeter = altimeter
        self.clouds = clouds
        self.flightRules = flightRules
        self.other = other
        self.sanitized = sanitized
        self.visibility = visibility
        self.windDirection = windDirection
        self.windGust = windGust
        self.windSpeed = windSpeed
        self.endTime = endTime
        self.icing = icing
        self.probability = probability
        self.raw = raw
        self.startTime = startTime
        self.turbulance = turbulance
        self.type = type
        self.windShear = windShear
    }
}

class Probability: Codable {
    let repr: String?
    let value: Int?
    let spoken: String?
    
    init(repr: String?, value: Int?, spoken: String?) {
        self.repr = repr
        self.value = value
        self.spoken = spoken
    }
}

class Altimeter: Codable {
    let repr: String?
    let value: Double?
    let spoken: String?
    
    init(repr: String?, value: Double?, spoken: String?) {
        self.repr = repr
        self.value = value
        self.spoken = spoken
    }
}

class Info: Codable {
    let city, country: String?
    let elevation: Double?
    let iata, icao: String?
    let latitude, longitude: Double?
    let name: String?
    let priority: Int?
    let state: String?
    let runways: [Runway]?
    
    init(city: String?, country: String?, elevation: Double?, iata: String?, icao: String?, latitude: Double?, longitude: Double?, name: String?, priority: Int?, state: String?, runways: [Runway]?) {
        self.city = city
        self.country = country
        self.elevation = elevation
        self.iata = iata
        self.icao = icao
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.priority = priority
        self.state = state
        self.runways = runways
    }
}

class Runway: Codable {
    let length, width: Int?
    let ident1, ident2: String?
    
    init(length: Int?, width: Int?, ident1: String?, ident2: String?) {
        self.length = length
        self.width = width
        self.ident1 = ident1
        self.ident2 = ident2
    }
}

class Meta: Codable {
    let timestamp, cacheTimestamp: String?
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case cacheTimestamp = "cache-timestamp"
    }
    
    init(timestamp: String?, cacheTimestamp: String?) {
        self.timestamp = timestamp
        self.cacheTimestamp = cacheTimestamp
    }
}

class RemarksInfo: Codable {
    let dewpointDecimal, temperatureDecimal: Altimeter?
    
    enum CodingKeys: String, CodingKey {
        case dewpointDecimal = "dewpoint_decimal"
        case temperatureDecimal = "temperature_decimal"
    }
    
    init(dewpointDecimal: Altimeter?, temperatureDecimal: Altimeter?) {
        self.dewpointDecimal = dewpointDecimal
        self.temperatureDecimal = temperatureDecimal
    }
}

class Time: Codable {
    let repr: String?
    let dt: Date?
    
    init(repr: String?, dt: Date?) {
        self.repr = repr
        self.dt = dt
    }
}

class Units: Codable {
    let altimeter, altitude, temperature, visibility: String?
    let windSpeed: String?
    
    enum CodingKeys: String, CodingKey {
        case altimeter, altitude, temperature, visibility
        case windSpeed = "wind_speed"
    }
    
    init(altimeter: String?, altitude: String?, temperature: String?, visibility: String?, windSpeed: String?) {
        self.altimeter = altimeter
        self.altitude = altitude
        self.temperature = temperature
        self.visibility = visibility
        self.windSpeed = windSpeed
    }
}

// MARK: Convenience initializers and mutators

extension MetarData {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(MetarData.self, from: data)
        self.init(meta: me.meta, altimeter: me.altimeter, clouds: me.clouds, flightRules: me.flightRules, other: me.other, sanitized: me.sanitized, visibility: me.visibility, windDirection: me.windDirection, windGust: me.windGust, windSpeed: me.windSpeed, raw: me.raw, station: me.station, time: me.time, remarks: me.remarks, dewpoint: me.dewpoint, remarksInfo: me.remarksInfo, runwayVisibility: me.runwayVisibility, temperature: me.temperature, windVariableDirection: me.windVariableDirection, units: me.units, info: me.info)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        meta: Meta?? = nil,
        altimeter: Altimeter?? = nil,
        clouds: [JSONAny]?? = nil,
        flightRules: String?? = nil,
        other: [JSONAny]?? = nil,
        sanitized: String?? = nil,
        visibility: Altimeter?? = nil,
        windDirection: Altimeter?? = nil,
        windGust: Altimeter?? = nil,
        windSpeed: Altimeter?? = nil,
        raw: String?? = nil,
        station: String?? = nil,
        time: Time?? = nil,
        remarks: String?? = nil,
        dewpoint: Altimeter?? = nil,
        remarksInfo: RemarksInfo?? = nil,
        runwayVisibility: [JSONAny]?? = nil,
        temperature: Altimeter?? = nil,
        windVariableDirection: [Altimeter]?? = nil,
        units: Units?? = nil,
        info: Info?? = nil
        ) -> MetarData {
        return MetarData(
            meta: meta ?? self.meta,
            altimeter: altimeter ?? self.altimeter,
            clouds: clouds ?? self.clouds,
            flightRules: flightRules ?? self.flightRules,
            other: other ?? self.other,
            sanitized: sanitized ?? self.sanitized,
            visibility: visibility ?? self.visibility,
            windDirection: windDirection ?? self.windDirection,
            windGust: windGust ?? self.windGust,
            windSpeed: windSpeed ?? self.windSpeed,
            raw: raw ?? self.raw,
            station: station ?? self.station,
            time: time ?? self.time,
            remarks: remarks ?? self.remarks,
            dewpoint: dewpoint ?? self.dewpoint,
            remarksInfo: remarksInfo ?? self.remarksInfo,
            runwayVisibility: runwayVisibility ?? self.runwayVisibility,
            temperature: temperature ?? self.temperature,
            windVariableDirection: windVariableDirection ?? self.windVariableDirection,
            units: units ?? self.units,
            info: info ?? self.info
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension TafData {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(TafData.self, from: data)
        self.init(meta: me.meta, raw: me.raw, station: me.station, time: me.time, remarks: me.remarks, forecast: me.forecast, startTime: me.startTime, endTime: me.endTime, maxTemp: me.maxTemp, minTemp: me.minTemp, alts: me.alts, temps: me.temps, units: me.units, info: me.info)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        meta: Meta?? = nil,
        raw: String?? = nil,
        station: String?? = nil,
        time: Time?? = nil,
        remarks: String?? = nil,
        forecast: [Forecast]?? = nil,
        startTime: Time?? = nil,
        endTime: Time?? = nil,
        maxTemp: String?? = nil,
        minTemp: String?? = nil,
        alts: JSONNull?? = nil,
        temps: JSONNull?? = nil,
        units: Units?? = nil,
        info: Info?? = nil
        ) -> TafData {
        return TafData(
            meta: meta ?? self.meta,
            raw: raw ?? self.raw,
            station: station ?? self.station,
            time: time ?? self.time,
            remarks: remarks ?? self.remarks,
            forecast: forecast ?? self.forecast,
            startTime: startTime ?? self.startTime,
            endTime: endTime ?? self.endTime,
            maxTemp: maxTemp ?? self.maxTemp,
            minTemp: minTemp ?? self.minTemp,
            alts: alts ?? self.alts,
            temps: temps ?? self.temps,
            units: units ?? self.units,
            info: info ?? self.info
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Forecast {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Forecast.self, from: data)
        self.init(altimeter: me.altimeter, clouds: me.clouds, flightRules: me.flightRules, other: me.other, sanitized: me.sanitized, visibility: me.visibility, windDirection: me.windDirection, windGust: me.windGust, windSpeed: me.windSpeed, endTime: me.endTime, icing: me.icing, probability: me.probability, raw: me.raw, startTime: me.startTime, turbulance: me.turbulance, type: me.type, windShear: me.windShear)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        altimeter: String?? = nil,
        clouds: [JSONAny]?? = nil,
        flightRules: String?? = nil,
        other: [String]?? = nil,
        sanitized: String?? = nil,
        visibility: Probability?? = nil,
        windDirection: Probability?? = nil,
        windGust: Probability?? = nil,
        windSpeed: Probability?? = nil,
        endTime: Time?? = nil,
        icing: [JSONAny]?? = nil,
        probability: Probability?? = nil,
        raw: String?? = nil,
        startTime: Time?? = nil,
        turbulance: [JSONAny]?? = nil,
        type: String?? = nil,
        windShear: String?? = nil
        ) -> Forecast {
        return Forecast(
            altimeter: altimeter ?? self.altimeter,
            clouds: clouds ?? self.clouds,
            flightRules: flightRules ?? self.flightRules,
            other: other ?? self.other,
            sanitized: sanitized ?? self.sanitized,
            visibility: visibility ?? self.visibility,
            windDirection: windDirection ?? self.windDirection,
            windGust: windGust ?? self.windGust,
            windSpeed: windSpeed ?? self.windSpeed,
            endTime: endTime ?? self.endTime,
            icing: icing ?? self.icing,
            probability: probability ?? self.probability,
            raw: raw ?? self.raw,
            startTime: startTime ?? self.startTime,
            turbulance: turbulance ?? self.turbulance,
            type: type ?? self.type,
            windShear: windShear ?? self.windShear
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Probability {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Probability.self, from: data)
        self.init(repr: me.repr, value: me.value, spoken: me.spoken)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        repr: String?? = nil,
        value: Int?? = nil,
        spoken: String?? = nil
        ) -> Probability {
        return Probability(
            repr: repr ?? self.repr,
            value: value ?? self.value,
            spoken: spoken ?? self.spoken
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Altimeter {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Altimeter.self, from: data)
        self.init(repr: me.repr, value: me.value, spoken: me.spoken)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        repr: String?? = nil,
        value: Double?? = nil,
        spoken: String?? = nil
        ) -> Altimeter {
        return Altimeter(
            repr: repr ?? self.repr,
            value: value ?? self.value,
            spoken: spoken ?? self.spoken
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Info {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Info.self, from: data)
        self.init(city: me.city, country: me.country, elevation: me.elevation, iata: me.iata, icao: me.icao, latitude: me.latitude, longitude: me.longitude, name: me.name, priority: me.priority, state: me.state, runways: me.runways)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        city: String?? = nil,
        country: String?? = nil,
        elevation: Double?? = nil,
        iata: String?? = nil,
        icao: String?? = nil,
        latitude: Double?? = nil,
        longitude: Double?? = nil,
        name: String?? = nil,
        priority: Int?? = nil,
        state: String?? = nil,
        runways: [Runway]?? = nil
        ) -> Info {
        return Info(
            city: city ?? self.city,
            country: country ?? self.country,
            elevation: elevation ?? self.elevation,
            iata: iata ?? self.iata,
            icao: icao ?? self.icao,
            latitude: latitude ?? self.latitude,
            longitude: longitude ?? self.longitude,
            name: name ?? self.name,
            priority: priority ?? self.priority,
            state: state ?? self.state,
            runways: runways ?? self.runways
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Runway {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Runway.self, from: data)
        self.init(length: me.length, width: me.width, ident1: me.ident1, ident2: me.ident2)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        length: Int?? = nil,
        width: Int?? = nil,
        ident1: String?? = nil,
        ident2: String?? = nil
        ) -> Runway {
        return Runway(
            length: length ?? self.length,
            width: width ?? self.width,
            ident1: ident1 ?? self.ident1,
            ident2: ident2 ?? self.ident2
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Meta {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Meta.self, from: data)
        self.init(timestamp: me.timestamp, cacheTimestamp: me.cacheTimestamp)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        timestamp: String?? = nil,
        cacheTimestamp: String?? = nil
        ) -> Meta {
        return Meta(
            timestamp: timestamp ?? self.timestamp,
            cacheTimestamp: cacheTimestamp ?? self.cacheTimestamp
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension RemarksInfo {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(RemarksInfo.self, from: data)
        self.init(dewpointDecimal: me.dewpointDecimal, temperatureDecimal: me.temperatureDecimal)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        dewpointDecimal: Altimeter?? = nil,
        temperatureDecimal: Altimeter?? = nil
        ) -> RemarksInfo {
        return RemarksInfo(
            dewpointDecimal: dewpointDecimal ?? self.dewpointDecimal,
            temperatureDecimal: temperatureDecimal ?? self.temperatureDecimal
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Time {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Time.self, from: data)
        self.init(repr: me.repr, dt: me.dt)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        repr: String?? = nil,
        dt: Date?? = nil
        ) -> Time {
        return Time(
            repr: repr ?? self.repr,
            dt: dt ?? self.dt
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

extension Units {
    convenience init(data: Data) throws {
        let me = try newJSONDecoder().decode(Units.self, from: data)
        self.init(altimeter: me.altimeter, altitude: me.altitude, temperature: me.temperature, visibility: me.visibility, windSpeed: me.windSpeed)
    }
    
    convenience init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    convenience init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        altimeter: String?? = nil,
        altitude: String?? = nil,
        temperature: String?? = nil,
        visibility: String?? = nil,
        windSpeed: String?? = nil
        ) -> Units {
        return Units(
            altimeter: altimeter ?? self.altimeter,
            altitude: altitude ?? self.altitude,
            temperature: temperature ?? self.temperature,
            visibility: visibility ?? self.visibility,
            windSpeed: windSpeed ?? self.windSpeed
        )
    }
    
    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: Encode/decode helpers

class JSONNull: Codable, Hashable {
    
    public static func == (lhs: JSONNull, rhs: JSONNull) -> Bool {
        return true
    }
    
    func hash(into hasher: inout Hasher) {
        return hasher.combine(0)
    }
    
    public init() {}
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

class JSONCodingKey: CodingKey {
    let key: String
    
    required init?(intValue: Int) {
        return nil
    }
    
    required init?(stringValue: String) {
        key = stringValue
    }
    
    var intValue: Int? {
        return nil
    }
    
    var stringValue: String {
        return key
    }
}

class JSONAny: Codable {
    let value: Any
    
    static func decodingError(forCodingPath codingPath: [CodingKey]) -> DecodingError {
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode JSONAny")
        return DecodingError.typeMismatch(JSONAny.self, context)
    }
    
    static func encodingError(forValue value: Any, codingPath: [CodingKey]) -> EncodingError {
        let context = EncodingError.Context(codingPath: codingPath, debugDescription: "Cannot encode JSONAny")
        return EncodingError.invalidValue(value, context)
    }
    
    static func decode(from container: SingleValueDecodingContainer) throws -> Any {
        if let value = try? container.decode(Bool.self) {
            return value
        }
        if let value = try? container.decode(Int64.self) {
            return value
        }
        if let value = try? container.decode(Double.self) {
            return value
        }
        if let value = try? container.decode(String.self) {
            return value
        }
        if container.decodeNil() {
            return JSONNull()
        }
        throw decodingError(forCodingPath: container.codingPath)
    }
    
    static func decode(from container: inout UnkeyedDecodingContainer) throws -> Any {
        if let value = try? container.decode(Bool.self) {
            return value
        }
        if let value = try? container.decode(Int64.self) {
            return value
        }
        if let value = try? container.decode(Double.self) {
            return value
        }
        if let value = try? container.decode(String.self) {
            return value
        }
        if let value = try? container.decodeNil() {
            if value {
                return JSONNull()
            }
        }
        if var container = try? container.nestedUnkeyedContainer() {
            return try decodeArray(from: &container)
        }
        if var container = try? container.nestedContainer(keyedBy: JSONCodingKey.self) {
            return try decodeDictionary(from: &container)
        }
        throw decodingError(forCodingPath: container.codingPath)
    }
    
    static func decode(from container: inout KeyedDecodingContainer<JSONCodingKey>, forKey key: JSONCodingKey) throws -> Any {
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int64.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeNil(forKey: key) {
            if value {
                return JSONNull()
            }
        }
        if var container = try? container.nestedUnkeyedContainer(forKey: key) {
            return try decodeArray(from: &container)
        }
        if var container = try? container.nestedContainer(keyedBy: JSONCodingKey.self, forKey: key) {
            return try decodeDictionary(from: &container)
        }
        throw decodingError(forCodingPath: container.codingPath)
    }
    
    static func decodeArray(from container: inout UnkeyedDecodingContainer) throws -> [Any] {
        var arr: [Any] = []
        while !container.isAtEnd {
            let value = try decode(from: &container)
            arr.append(value)
        }
        return arr
    }
    
    static func decodeDictionary(from container: inout KeyedDecodingContainer<JSONCodingKey>) throws -> [String: Any] {
        var dict = [String: Any]()
        for key in container.allKeys {
            let value = try decode(from: &container, forKey: key)
            dict[key.stringValue] = value
        }
        return dict
    }
    
    static func encode(to container: inout UnkeyedEncodingContainer, array: [Any]) throws {
        for value in array {
            if let value = value as? Bool {
                try container.encode(value)
            } else if let value = value as? Int64 {
                try container.encode(value)
            } else if let value = value as? Double {
                try container.encode(value)
            } else if let value = value as? String {
                try container.encode(value)
            } else if value is JSONNull {
                try container.encodeNil()
            } else if let value = value as? [Any] {
                var container = container.nestedUnkeyedContainer()
                try encode(to: &container, array: value)
            } else if let value = value as? [String: Any] {
                var container = container.nestedContainer(keyedBy: JSONCodingKey.self)
                try encode(to: &container, dictionary: value)
            } else {
                throw encodingError(forValue: value, codingPath: container.codingPath)
            }
        }
    }
    
    static func encode(to container: inout KeyedEncodingContainer<JSONCodingKey>, dictionary: [String: Any]) throws {
        for (key, value) in dictionary {
            let key = JSONCodingKey(stringValue: key)!
            if let value = value as? Bool {
                try container.encode(value, forKey: key)
            } else if let value = value as? Int64 {
                try container.encode(value, forKey: key)
            } else if let value = value as? Double {
                try container.encode(value, forKey: key)
            } else if let value = value as? String {
                try container.encode(value, forKey: key)
            } else if value is JSONNull {
                try container.encodeNil(forKey: key)
            } else if let value = value as? [Any] {
                var container = container.nestedUnkeyedContainer(forKey: key)
                try encode(to: &container, array: value)
            } else if let value = value as? [String: Any] {
                var container = container.nestedContainer(keyedBy: JSONCodingKey.self, forKey: key)
                try encode(to: &container, dictionary: value)
            } else {
                throw encodingError(forValue: value, codingPath: container.codingPath)
            }
        }
    }
    
    static func encode(to container: inout SingleValueEncodingContainer, value: Any) throws {
        if let value = value as? Bool {
            try container.encode(value)
        } else if let value = value as? Int64 {
            try container.encode(value)
        } else if let value = value as? Double {
            try container.encode(value)
        } else if let value = value as? String {
            try container.encode(value)
        } else if value is JSONNull {
            try container.encodeNil()
        } else {
            throw encodingError(forValue: value, codingPath: container.codingPath)
        }
    }
    
    public required init(from decoder: Decoder) throws {
        if var arrayContainer = try? decoder.unkeyedContainer() {
            self.value = try JSONAny.decodeArray(from: &arrayContainer)
        } else if var container = try? decoder.container(keyedBy: JSONCodingKey.self) {
            self.value = try JSONAny.decodeDictionary(from: &container)
        } else {
            let container = try decoder.singleValueContainer()
            self.value = try JSONAny.decode(from: container)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        if let arr = self.value as? [Any] {
            var container = encoder.unkeyedContainer()
            try JSONAny.encode(to: &container, array: arr)
        } else if let dict = self.value as? [String: Any] {
            var container = encoder.container(keyedBy: JSONCodingKey.self)
            try JSONAny.encode(to: &container, dictionary: dict)
        } else {
            var container = encoder.singleValueContainer()
            try JSONAny.encode(to: &container, value: self.value)
        }
    }
}

fileprivate func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        decoder.dateDecodingStrategy = .iso8601
    }
    return decoder
}

fileprivate func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        encoder.dateEncodingStrategy = .iso8601
    }
    return encoder
}



