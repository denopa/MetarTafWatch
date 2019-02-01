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

class airportClass : NSObject {
    var airportName : String
    var flightConditions : String
    var metar : String
    var metarTime : String
    var metarAge : String
    var windSpeed : Int
    var windSymbol : String
    var nextFlightConditions : String
    var nextForecast : String
    var taf : String
    var tafTime : String
    var nextWindSpeed : Int
    var nextWindSymbol : String
    var city: String
    var elevation: String
    var runway1: String
    var runway2: String
    init(ICAO : String) {
        airportName = ICAO
        flightConditions = " "
        metar = "missing"
        metarTime = "..."
        metarAge = "..."
        windSpeed = 0
        windSymbol = ""
        nextFlightConditions = " "
        nextForecast = "..."
        taf = "missing"
        tafTime = "missing TAF"
        nextWindSpeed = 0
        nextWindSymbol = ""
        city = ""
        elevation = "0"
        runway1 = "00"
        runway2 = "00"
    }
}

var airportsArray = [airportClass(ICAO : "EGLL"), airportClass(ICAO : "LFOV"), airportClass(ICAO : "EBFN"), airportClass(ICAO : "EBBR")]
var airportsList = ["EGLF", "EGBB", "LFTH", "LFPO"]

func loadAirportsList(){
    let appGroupId = "group.com.nonneville.com.metarTaf"
    let defaults = UserDefaults(suiteName: appGroupId)
    if let airports = defaults?.object(forKey: "airports"){
        airportsList = airports as! [String]
    } else {
        defaults?.register(defaults: ["airports" : airportsList])
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
        let metarHour = Int(metarDate[metarDate.index(metarDate.startIndex, offsetBy: 2)...metarDate.index(metarDate.startIndex, offsetBy: 3)]) ?? 0
        let metarMinute = Int(metarDate[metarDate.index(metarDate.startIndex, offsetBy: 4)...metarDate.index(metarDate.startIndex, offsetBy: 5)]) ?? 0
        var minutes = (nowMinute - metarMinute) + 60 * (nowHour - metarHour)
        if nowDay>metarDay {
            minutes = minutes + 24 * 60 //dealing with overnight
        }
        return String(minutes + 1)
    }
}

class Refresher {
    static func scheduleUpdate(scheduledCompletion: @escaping (Error?) -> Void) {
        let age: Double? = Double(howOldIsMetar(metarDate: airportsArray[0].metarTime))
        let minutesToRefresh = max(3, 42 - (age ?? 0))
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: Date().addingTimeInterval(minutesToRefresh * 60), userInfo: nil, scheduledCompletion: scheduledCompletion)
        print("scheduled refresh for \(Date().addingTimeInterval(minutesToRefresh * 60))")
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
