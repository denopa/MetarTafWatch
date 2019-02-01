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
    
    let flighConditionsColor = [" " : UIColor.init(white: 0.1, alpha: 1), "VFR" : UIColor(displayP3Red: 0, green: 1, blue: 1, alpha: 1), "MVFR" : UIColor.green.withAlphaComponent(1), "IFR" : UIColor.orange.withAlphaComponent(1), "LIFR": UIColor.red.withAlphaComponent(1)] //describes the color the lettering will take depending on weather conditions
    
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
        print("getting current timeline entry")
        getTimelineEntries(for: complication, after : NSDate() as Date, limit: 1) {(entries) -> Void in handler(entries?.first)}
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        var timelineEntries: [CLKComplicationTimelineEntry] = []
        let metarColor = self.flighConditionsColor[airportsArray[0].flightConditions]
        let largeText = airportsArray[0].airportName
                switch complication.family {
                    case .circularSmall:
                        let circularSmallTemplate = CLKComplicationTemplateCircularSmallSimpleText()
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude098")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .modularSmall:
                        let circularSmallTemplate = CLKComplicationTemplateModularSmallSimpleText()
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude3321")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .modularLarge:
                        let circularSmallTemplate = CLKComplicationTemplateModularLargeStandardBody()
                        circularSmallTemplate.body1TextProvider = CLKSimpleTextProvider(text: "Pressure Altitude1432")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .utilitarianSmall:
                        let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallRingText()
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude 421")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .utilitarianSmallFlat:
                        let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallRingText()
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude 143")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .utilitarianLarge:
                        let circularSmallTemplate = CLKComplicationTemplateUtilitarianLargeFlat()
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude 653")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .extraLarge:
                        let circularSmallTemplate = CLKComplicationTemplateExtraLargeSimpleText()
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude 656")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .graphicCorner:
                        let graphicCorner = CLKComplicationTemplateGraphicCornerStackText()
                        //let metarColor = self.flighConditionsColor[airportsArray[0].flightConditions]
                        graphicCorner.outerTextProvider = CLKSimpleTextProvider(text: largeText)
                        for minute in 0..<(limit-1) {
                            let age = minute + (Int(airportsArray[0].metarAge) ?? 0)
                            graphicCorner.innerTextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) \(age)' ago")
                            graphicCorner.innerTextProvider.tintColor = metarColor ?? UIColor.white //must be set after the text
                            let complicationDate = Date().addingTimeInterval(TimeInterval(minute * 60)).zeroSeconds
                            let entry = CLKComplicationTimelineEntry(date: complicationDate, complicationTemplate : graphicCorner)
                            timelineEntries.append(entry)
                        }
                        graphicCorner.innerTextProvider = CLKSimpleTextProvider(text: "\(airportsArray[0].flightConditions) old")
                        let entry = CLKComplicationTimelineEntry(date: NSDate().addingTimeInterval(TimeInterval((limit-1) * 60)) as Date, complicationTemplate : graphicCorner)
                        timelineEntries.append(entry)
                    case .graphicBezel:
                        let circularSmallTemplate = CLKComplicationTemplateGraphicBezelCircularText()
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude 3213")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .graphicCircular:
                        let circularSmallTemplate =  CLKComplicationTemplateGraphicCornerTextImage()
                        let cornerImage = UIImage(named: "Graphic Corner")
                        circularSmallTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: cornerImage!)
                        circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "1,556 ft", shortText: "1.5k ft")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                    case .graphicRectangular:
                        let circularSmallTemplate = CLKComplicationTemplateGraphicRectangularTextGauge()
                        circularSmallTemplate.body1TextProvider = CLKSimpleTextProvider(text: "Pressure Altitude 7645")
                        let entry = CLKComplicationTimelineEntry(date: NSDate() as Date, complicationTemplate : circularSmallTemplate)
                        timelineEntries.append(entry)
                }
                handler(timelineEntries)
            //}
        //}
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        //handler(nil)
        var template: CLKComplicationTemplate?
        switch complication.family {
            case .circularSmall:
                let circularSmallTemplate = CLKComplicationTemplateCircularSmallSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .modularSmall:
                let circularSmallTemplate = CLKComplicationTemplateModularSmallSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .modularLarge:
                let circularSmallTemplate = CLKComplicationTemplateModularLargeStandardBody()
                circularSmallTemplate.body1TextProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .utilitarianSmall:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallRingText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .utilitarianSmallFlat:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianSmallRingText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .utilitarianLarge:
                let circularSmallTemplate = CLKComplicationTemplateUtilitarianLargeFlat()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .extraLarge:
                let circularSmallTemplate = CLKComplicationTemplateExtraLargeSimpleText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .graphicCorner:
                let circularSmallTemplate = CLKComplicationTemplateGraphicCornerStackText()
                circularSmallTemplate.innerTextProvider = CLKSimpleTextProvider(text: "Weather")
                circularSmallTemplate.outerTextProvider = CLKSimpleTextProvider(text: "Airport")
                template = circularSmallTemplate
            case .graphicBezel:
                let circularSmallTemplate = CLKComplicationTemplateGraphicBezelCircularText()
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
            case .graphicCircular:
                let circularSmallTemplate = CLKComplicationTemplateGraphicCornerTextImage()
                let cornerImage = UIImage(named: "Graphic Corner")
                circularSmallTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: cornerImage!)
                circularSmallTemplate.textProvider = CLKSimpleTextProvider(text: "11,556 ft", shortText: "11.5k ft")
                template = circularSmallTemplate
            case .graphicRectangular:
                let circularSmallTemplate = CLKComplicationTemplateGraphicRectangularStandardBody()
                circularSmallTemplate.headerTextProvider = CLKSimpleTextProvider(text: "Header")
                circularSmallTemplate.body1TextProvider = CLKSimpleTextProvider(text: "Pressure Altitude")
                template = circularSmallTemplate
        }
        handler(template)
    }
}
