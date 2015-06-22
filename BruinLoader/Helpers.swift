//
//  Helpers.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 6/11/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import Foundation

protocol Serializable {
	func dictFromObject() -> Dictionary<String, AnyObject>
	init(dict: Dictionary<String, AnyObject>)
}

enum Progress: String {
	case Waiting = "StartedWaiting", Loading = "StartedLoading"
	case Error = "EncounteredError", Loaded = "FinishedLoading"
	case Uploaded = "FinishedUpload"
}

func postProgressNotification(date: NSDate?, progress: Progress) {
	
}

func errorOccuredInLoad(date: NSDate?, error: NSError) {
	postProgressNotification(date, .Error)
}

func deserialized(data: NSData) -> Dictionary<String, AnyObject> {
	return deserializedOpt(data) ?? [:]
}

func deserializedOpt(data: NSData) -> Dictionary<String, AnyObject>? {
	return NSJSONSerialization.JSONObjectWithData(data, options: .allZeros, error: nil) as? Dictionary<String, AnyObject>
}

func serialize(object: Serializable) -> NSData {
	return NSJSONSerialization.dataWithJSONObject(object.dictFromObject(), options: .allZeros, error: nil) ?? NSData()
}

func representsToday(date: NSDate) -> Bool {
	return daysInFuture(date) == 0
}

func daysInFuture(date: NSDate) -> Int {
	return NSCalendar.currentCalendar().components(.CalendarUnitDay, fromDate: comparisonDate(), toDate: comparisonDate(date: date), options: .allZeros).day
}

class Time {
	var hour: Int
	var minute: Int
	
	/// give hour in 24 hour notation (can be more than 24 hours if past midnight)
	init(hour: Int, minute: Int) {
		self.hour = hour
		self.minute = minute
	}
	
	init(hoursString: String) {
		var formatter = NSDateFormatter()
		formatter.dateFormat = "h:mma"
		let comps = NSCalendar.currentCalendar().components(.CalendarUnitHour | .CalendarUnitMinute, fromDate: formatter.dateFromString(hoursString)!)
		var increase = (comps.hour < 7) ? 24 : 0
		self.hour = comps.hour + increase
		self.minute = comps.minute
	}
	
	init(hoursString: String, date: NSDate) {
		var formatter = NSDateFormatter()
		formatter.dateFormat = "h:mma"
		let interval = formatter.dateFromString(hoursString)!.timeIntervalSinceDate(date)
		
		self.hour = Int(interval) / 3600
		self.minute = Int(interval % 3600) / 60
	}
	
	func timeDateForDate(dayDate: NSDate?) -> NSDate? {
		var interval = 3600.0 * Double(hour) + 60 * Double(minute)
		return NSCalendar.currentCalendar().dateBySettingHour(0, minute: 0, second: 0, ofDate: dayDate!, options: NSCalendarOptions())?.dateByAddingTimeInterval(interval)
	}
	
	func displayString() -> String {
		var formatter = NSDateFormatter()
		formatter.dateFormat = "h:mm a"
		return formatter.stringFromDate(timeDateForDate(NSDate())!)
	}
}