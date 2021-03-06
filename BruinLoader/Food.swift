//
//  Food.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 3/25/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

var currCal = NSCalendar.currentCalendar()

func comparisonDate(date: NSDate = NSDate()) -> NSDate {
	return currCal.startOfDayForDate(date)
}

func comparisonDate(daysInFuture: Int) -> NSDate {
	return currCal.dateByAddingUnit(.CalendarUnitDay, value: daysInFuture, toDate: comparisonDate(), options: nil)!
}

class DiningDay: NSManagedObject {
	@NSManaged var day: NSDate
	@NSManaged var data: String
	@NSManaged var hours: String
	
	class func dataFromInfo(moc: NSManagedObjectContext, record: CKRecord) -> DiningDay {
		var request = NSFetchRequest(entityName: "DiningDay")
		
		let recordDay = comparisonDate(date: record.objectForKey("Day") as! NSDate)
		request.predicate = NSPredicate(format: "day == %@", recordDay)
		
		if let fetchResults = moc.executeFetchRequest(request, error: nil) as? [DiningDay] {
			for result in fetchResults {
				return result
			}
		}
		
		var newItem = NSEntityDescription.insertNewObjectForEntityForName("DiningDay", inManagedObjectContext: moc) as! DiningDay
		newItem.hours = NSString(data: record.objectForKey("Hours") as! NSData, encoding: NSUTF8StringEncoding) as! String
		newItem.data = NSString(data: record.objectForKey("Data") as! NSData, encoding: NSUTF8StringEncoding) as! String
		newItem.day = recordDay
		
		NSNotificationCenter.defaultCenter().postNotificationName("NewDayInfoAdded", object: nil, userInfo:["newItem":newItem])
		
		return newItem
	}
}

class Food: NSManagedObject {
	/// All the information for the entire food
	@NSManaged var foodString: String
	
	@NSManaged var favorite: Bool
	/// Notify at start of day if seen
		@NSManaged var notify: Bool
	
	@NSManaged var date: NSDate // for servings
	@NSManaged var servings: Int16
	
	class func foodFromInfo(moc: NSManagedObjectContext, food: FoodInfo) -> Food {
		var request = NSFetchRequest(entityName: "Food")
		
		if let fetchResults = moc.executeFetchRequest(request, error: nil) as? [Food] {
			for result in fetchResults {
				if result.info().recipe == food.recipe {
					result.checkDate()
					return result
				}
			}
		}
		
		var newItem = NSEntityDescription.insertNewObjectForEntityForName("Food", inManagedObjectContext: moc) as! Food
		newItem.foodString = food.foodString()
		
		newItem.favorite = false
		newItem.notify = false
		newItem.date = comparisonDate()
		newItem.servings = 0
		
		return newItem
	}
	
	func checkDate() {
		let compareDate = comparisonDate()
		
		let dateComponents = components(compareDate)
		let resultComponents = components(date)
		
		if !(dateComponents.weekOfYear == resultComponents.weekOfYear && dateComponents.weekday == resultComponents.weekday) {
			date = compareDate
			servings = 0
		}
	}
	
	private func components(date: NSDate) -> NSDateComponents {
		return NSCalendar.currentCalendar().components(.CalendarUnitWeekOfYear | .CalendarUnitWeekday, fromDate: date)
	}
	
	func info() -> FoodInfo {
		return MainFoodInfo.isMain(foodString) ? MainFoodInfo(formattedString: foodString) : FoodInfo(formattedString: foodString)
	}
}
