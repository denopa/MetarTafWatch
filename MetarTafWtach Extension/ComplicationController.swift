//
//  ComplicationController.swift
//  MetarTafWtach Extension
//
//  Created by Patrick de Nonneville on 19/12/2018.
//  Copyright © 2018 Patrick de Nonneville. All rights reserved.
//

import ClockKit
import CoreFoundation
import CoreMotion

class ComplicationController: NSObject, CLKComplicationDataSource, URLSessionDelegate {
    
    let flightConditionsTextColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" : UIColor(displayP3Red: 0.44, green: 0.78, blue: 0.86, alpha: 1), "MVFR" : UIColor(displayP3Red: 0.4, green: 0.85, blue: 0.49, alpha: 1), "IFR" : UIColor(displayP3Red: 1, green: 0.58, blue: 0.25, alpha: 1), "LIFR": UIColor(displayP3Red: 0.92, green: 0.30, blue: 0.24, alpha: 1)] //describes the color the lettering will take depending on weather conditions
    let colorRange = [UIColor(displayP3Red: 0.44, green: 0.78, blue: 0.86, alpha: 1), UIColor(displayP3Red: 0.4, green: 0.85, blue: 0.49, alpha: 1), UIColor(displayP3Red: 1, green: 0.58, blue: 0.25, alpha: 1), UIColor(displayP3Red: 0.92, green: 0.30, blue: 0.24, alpha: 1)] //color range for the gauge
    let gaugeLocationDic = [" " : 0, "VFR" : 0.05, "MVFR" : 0.3, "IFR" : 0.65, "LIFR": 0.95]
    var altitudeText = "Altitude"
    var altitudeShortText = "Alt"
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        //handler([.forward, .backward])
        handler([])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(NSDate() as Date) //worked with nil
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(Date().addingTimeInterval(15 * 60)) //worked with nil
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        getTimelineEntries(for: complication, after : NSDate() as Date, limit: 1) {(entries) -> Void in handler(entries?.first)}
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        var timelineEntries: [CLKComplicationTimelineEntry] = []
        let metarColor = self.flightConditionsTextColor[airportsArray[0].flightConditions]
        let gaugeLocation = Float(self.gaugeLocationDic[airportsArray[0].flightConditions] ?? 0)
        let largeText = airportsArray[0].airportName
        var shortName = String(largeText[largeText.index(largeText.startIndex, offsetBy: 1)...largeText.index(largeText.startIndex, offsetBy: 3)]) //how to get the 2nd, 3rd and 4th characters
        if largeText.count == 5 {
            shortName = String(largeText[largeText.index(largeText.startIndex, offsetBy: 2)...largeText.index(largeText.startIndex, offsetBy: 4)]) //how to get the 3nd, 4rd and 5th characters
        }
        let veryLargeText = "\(airportsArray[0].airportName) - \(airportsArray[0].city)"
        let nextTaf = "\(airportsArray[0].nextForecastHeader + airportsArray[0].nextFlightConditions)"
        var runwayString = nextTaf
        if (airportsArray[0].runwayList != [])&&(airportsArray[0].windDirection != 999){
            let bestRunwayArray : [String] = runwayCalculations().findBestRunway(runwayNames: airportsArray[0].runwayList, windDirection: airportsArray[0].windDirection, windSpeed: airportsArray[0].windSpeed)
            if bestRunwayArray[0] != "998" {
                let bestRunway = bestRunwayArray[0]
                let headwind = bestRunwayArray[1]
                let crosswind = bestRunwayArray[2]
                let indicator = bestRunwayArray[3]
                runwayString = "RW\(bestRunway) 🔽\(headwind)kt \(indicator + crosswind)kt"
            }
        }
        switch complication.family {
            case .circularSmall:
                let circularSmallTemplate = CLKComplicationTemplateCircularSmallSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: largeText)
                circularSmallTemplate.textProvider.tintColor = metarColor ?? UIColor.white
                let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                timelineEntries.append(entry)
            case .modularSmall:
                let circularSmallTemplate = CLKComplicationTemplateModularSmallSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: largeText)
                circularSmallTemplate.textProvider.tintColor = metarColor ?? UIColor.white
                let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                timelineEntries.append(entry)
            case .modularLarge:
                let modularLargeTemplate = CLKComplicationTemplateModularLargeStandardBody()
                modularLargeTemplate.headerTextProvider = CLKSimpleTextProvider(text: veryLargeText)
                modularLargeTemplate.headerTextProvider.tintColor = metarColor ?? UIColor.white //must be set after the text
                for minute in 0..<(limit - ((limit > 1) ? 1 : 0)) { // the last bit takes off 1 if limit>1
                    let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                    modularLargeTemplate.body1TextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) \(age)' ago" )
                     modularLargeTemplate.body2TextProvider = CLKSimpleTextProvider(text: runwayString )
                    let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                    let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : modularLargeTemplate)
                    timelineEntries.append(entry)
                }
                if (limit > 1) { //add "old" at the end but only if limit>1
                    modularLargeTemplate.body1TextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) old")
                    let entry = CLKComplicationTimelineEntry(date: NSDate().addingTimeInterval(TimeInterval((limit-1) * 60)) as Date, complicationTemplate : modularLargeTemplate)
                    timelineEntries.append(entry)
                }
            case .utilitarianSmall:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallRingText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: largeText)
                circularSmallTemplate.textProvider.tintColor = metarColor ?? UIColor.white
                let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                timelineEntries.append(entry)
            case .utilitarianSmallFlat:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallFlat()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: largeText)
                circularSmallTemplate.textProvider.tintColor = metarColor ?? UIColor.white
                let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                timelineEntries.append(entry)
            case .utilitarianLarge:
                let utilitarianLargeTemplate = CLKComplicationTemplateUtilitarianLargeFlat()
                for minute in 0..<(limit - ((limit > 1) ? 1 : 0)) { // the last bit takes off 1 if limit>1
                    let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                    utilitarianLargeTemplate.textProvider = CLKSimpleTextProvider(text: "\(largeText) \(airportsArray[0].flightConditions) \(age)' ago" )
                    utilitarianLargeTemplate.textProvider.tintColor = metarColor ?? UIColor.white //must be set after the text
                    let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                    let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : utilitarianLargeTemplate)
                    timelineEntries.append(entry)
                }
                if (limit > 1) { //add "old" at the end but only if limit>1
                    utilitarianLargeTemplate.textProvider = CLKSimpleTextProvider(text: "\(largeText) \(airportsArray[0].flightConditions) old")
                    let entry = CLKComplicationTimelineEntry(date: NSDate().addingTimeInterval(TimeInterval((limit-1) * 60)) as Date, complicationTemplate : utilitarianLargeTemplate)
                    timelineEntries.append(entry)
            }
            case .extraLarge:
                let extraLargeTemplate = CLKComplicationTemplateExtraLargeStackText()
                extraLargeTemplate.line1TextProvider = CLKSimpleTextProvider(text: largeText)
                for minute in 0..<(limit - ((limit > 1) ? 1 : 0)) { // the last bit takes off 1 if limit>1
                    let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                    extraLargeTemplate.line2TextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) \(age)' ago" )
                    extraLargeTemplate.line2TextProvider.tintColor = metarColor ?? UIColor.white //must be set after the text
                    let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                    let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : extraLargeTemplate)
                    timelineEntries.append(entry)
                }
                if (limit > 1) { //add "old" at the end but only if limit>1
                    extraLargeTemplate.line2TextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) old")
                    let entry = CLKComplicationTimelineEntry(date: NSDate().addingTimeInterval(TimeInterval((limit-1) * 60)) as Date, complicationTemplate : extraLargeTemplate)
                    timelineEntries.append(entry)
                }
            case .graphicCorner:
                let graphicCorner = CLKComplicationTemplateGraphicCornerStackText()
                graphicCorner.outerTextProvider = CLKSimpleTextProvider(text: largeText)
                for minute in 0..<(limit - ((limit > 1) ? 1 : 0)) { // the last bit takes off 1 if limit>1
                    let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                    graphicCorner.innerTextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) \(age)' ago")
                    graphicCorner.innerTextProvider.tintColor = metarColor ?? UIColor.white //must be set after the text
                    let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                    let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : graphicCorner)
                    timelineEntries.append(entry)
                }
                if (limit > 1) { //add "old" at the end but only if limit>1
                    graphicCorner.innerTextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) old")
                    let entry = CLKComplicationTimelineEntry(date: NSDate().addingTimeInterval(TimeInterval((limit-1) * 60)) as Date, complicationTemplate : graphicCorner)
                    timelineEntries.append(entry)
                }
            case .graphicBezel:
                let graphicBezelTemplate = CLKComplicationTemplateGraphicBezelCircularText()
                for minute in 0..<(limit - ((limit > 1) ? 1 : 0)) { // the last bit takes off 1 if limit>1
                    let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                    graphicBezelTemplate.textProvider = CLKSimpleTextProvider(text: "\(largeText) \(airportsArray[0].flightConditions) \(age)' ago" )
                    graphicBezelTemplate.textProvider?.tintColor = metarColor ?? UIColor.white //must be set after the text
                    let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                    let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : graphicBezelTemplate)
                    timelineEntries.append(entry)
                }
                if (limit > 1) { //add "old" at the end but only if limit>1
                    graphicBezelTemplate.textProvider = CLKSimpleTextProvider(text: "\(largeText) \(airportsArray[0].flightConditions) old")
                    let entry = CLKComplicationTimelineEntry(date: NSDate().addingTimeInterval(TimeInterval((limit-1) * 60)) as Date, complicationTemplate : graphicBezelTemplate)
                    timelineEntries.append(entry)
            }
            case .graphicCircular: 
                let circularSmallTemplate = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
                circularSmallTemplate.centerTextProvider = CLKSimpleTextProvider(text : shortName)
                for minute in 0..<(limit - ((limit > 1) ? 1 : 0)) { // the last bit takes off 1 if limit>1
                    let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                    circularSmallTemplate.gaugeProvider = CLKSimpleGaugeProvider(style: .ring, gaugeColors: colorRange, gaugeColorLocations: [0,0.30,0.55,0.85], fillFraction: gaugeLocation)
                    circularSmallTemplate.leadingTextProvider = CLKSimpleTextProvider(text: "\(age)'")
                    circularSmallTemplate.leadingTextProvider.tintColor = metarColor ?? UIColor.white
                    circularSmallTemplate.trailingTextProvider = CLKSimpleTextProvider(text: "ago")
                    circularSmallTemplate.trailingTextProvider.tintColor = metarColor ?? UIColor.white
                    let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                    let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : circularSmallTemplate)
                    timelineEntries.append(entry)
                }
            case .graphicRectangular:
                let graphicRectangularTemplate = CLKComplicationTemplateGraphicRectangularStandardBody()
                graphicRectangularTemplate.headerTextProvider = CLKSimpleTextProvider(text: veryLargeText)
                graphicRectangularTemplate.headerTextProvider.tintColor = metarColor ?? UIColor.white //must be set after the text
                graphicRectangularTemplate.body2TextProvider = CLKSimpleTextProvider(text: runwayString)
                for minute in 0..<(limit - ((limit > 1) ? 1 : 0)) { // the last bit takes off 1 if limit>1
                    let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                    graphicRectangularTemplate.body1TextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) \(age)' ago" )
                    
                    let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                    let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : graphicRectangularTemplate)
                    timelineEntries.append(entry)
                }
                if (limit > 1) { //add "old" at the end but only if limit>1
                    graphicRectangularTemplate.body1TextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) old")
                    let entry = CLKComplicationTimelineEntry(date: NSDate().addingTimeInterval(TimeInterval((limit-1) * 60)) as Date, complicationTemplate : graphicRectangularTemplate)
                    timelineEntries.append(entry)
                }
        default :
            preconditionFailure("Complication family not supported")
        }
        handler(timelineEntries)
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        //handler(nil)
        var template: CLKComplicationTemplate?
        switch complication.family {
            case .circularSmall:
                let circularSmallTemplate = CLKComplicationTemplateCircularSmallSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
            case .modularSmall:
                let circularSmallTemplate = CLKComplicationTemplateModularSmallSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
            case .modularLarge:
                let circularSmallTemplate = CLKComplicationTemplateModularLargeStandardBody()
                circularSmallTemplate.headerTextProvider = CLKSimpleTextProvider(text: "AIRPORT")
                circularSmallTemplate.body1TextProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
            case .utilitarianSmall:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallRingText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
            case .utilitarianSmallFlat:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallFlat()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
            case .utilitarianLarge:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianLargeFlat()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
            case .extraLarge:
                let circularSmallTemplate = CLKComplicationTemplateExtraLargeSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
            case .graphicCorner:
                let circularSmallTemplate = CLKComplicationTemplateGraphicCornerStackText()
                circularSmallTemplate.innerTextProvider = CLKSimpleTextProvider(text: "Weather")
                circularSmallTemplate.outerTextProvider = CLKSimpleTextProvider(text: "Airport")
                template = circularSmallTemplate
            case .graphicBezel:
                /*let circularSmallTemplate = CLKComplicationTemplateGraphicBezelCircularText()
                let innerCircleTemplate = CLKComplicationTemplateGraphicCircular()
                innerCircleTemplate.bottomTextProvider = CLKSimpleTextProvider(text: "WEATHER", shortText: "WEATHER")
                innerCircleTemplate.centerTextProvider = CLKSimpleTextProvider(text : "AIRPORT")
                innerCircleTemplate.gaugeProvider = CLKGaugeProvider()
                circularSmallTemplate.circularTemplate = innerCircleTemplate
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate*/
                break
            case .graphicCircular: //not used
                let circularSmallTemplate = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText()
                circularSmallTemplate.bottomTextProvider = CLKSimpleTextProvider(text: "WEATHER", shortText: "WEATHER")
                circularSmallTemplate.centerTextProvider = CLKSimpleTextProvider(text : "AIRPORT")
                circularSmallTemplate.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: UIColor.cyan, fillFraction: 1.0)
                template = circularSmallTemplate 
            case .graphicRectangular:
                let circularSmallTemplate = CLKComplicationTemplateGraphicRectangularStandardBody()
                circularSmallTemplate.headerTextProvider = CLKSimpleTextProvider(text: "AIRPORT")
                circularSmallTemplate.body1TextProvider = CLKSimpleTextProvider(text: "WEATHER")
                template = circularSmallTemplate
        @unknown default:
                print("unknown complication")
        }
        handler(template)
    }
    
}
