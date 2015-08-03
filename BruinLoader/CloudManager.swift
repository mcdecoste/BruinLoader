//
//  CloudManager.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 3/25/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import UIKit
import Foundation
import CloudKit

import CoreData

private let _CloudManagerSharedInstance = CloudManager()

class CloudManager: NSObject {
	let HallRecordType = "DiningDay", QuickRecordType = "QuickMenu"
	let CKDateField = "Day", CKDataField = "Data"
	let CDDateField = "day"
	
	private var container: CKContainer
	private var publicDB: CKDatabase
	
	lazy var managedObjectContext : NSManagedObjectContext? = {
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		if let moc = appDelegate.managedObjectContext { return moc }
		else { return nil }
		}()
	
	class var sharedInstance: CloudManager {
		get {
			return _CloudManagerSharedInstance
		}
	}
	
	override init() {
		container = CKContainer(identifier: "iCloud.BruinLife.MatthewDeCoste")
		publicDB = container.publicCloudDatabase
	}
	
	func fetchNewRecords(type: String = "DiningDay", completion: (error: NSError!) -> Void) {
		fetchRecords(type, startDaysInAdvance: findFirstGap(), completion: completion)
	}
	
	func findFirstGap(daysInAdvance: Int = 13) -> Int {
		var fetchRequest = NSFetchRequest(entityName: "DiningDay")
		fetchRequest.predicate = NSPredicate(format: "\(CDDateField) >= %@", comparisonDate())
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: CDDateField, ascending: false)] // DateField
		
		if let fetchResults = managedObjectContext!.executeFetchRequest(fetchRequest, error: nil) as? [DiningDay] where fetchResults.count != 0 {
			return daysInFuture(fetchResults[0].day)
		}
		return 0
	}
	
	private func fetchRecords(type: String, startDaysInAdvance: Int = 0, completion: (error: NSError!) -> Void) {
		if startDaysInAdvance == 13 {
			completion(error: NSError())
			return // don't bother loading further
		}
		
		let startDate = comparisonDate(startDaysInAdvance)
		let endDate = comparisonDate(min(13, max(startDaysInAdvance + 3, 6)))
		
		var query = CKQuery(recordType: type, predicate: NSPredicate(format: "(\(CKDateField) >= %@) AND (\(CKDateField) <= %@)", startDate, endDate))
		query.sortDescriptors = [NSSortDescriptor(key: CKDateField, ascending: true)] // important?
		
		var numResults = 0
		
		let operation = CKQueryOperation(query: query)
		operation.recordFetchedBlock = { (record) -> Void in
			numResults++
			self.newDiningDay(record)
		}
		operation.queryCompletionBlock = { (cursor, error) in
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				self.save()
				completion(error: numResults == 0 ? NSError() : error)
			})
		}
		
		publicDB.addOperation(operation)
	}
	
	//	private func idsForDate(date: NSDate) -> [String] {
	//		var query = CKQuery(recordType: HallRecordType, predicate: NSPredicate(format: "(\(CKDateField) == %@)", startDate))
	//
	//		var results = [String]()
	//
	//		let operation = CKQueryOperation(query: query)
	//		operation.recordFetchedBlock = { (record) -> Void in
	//			record.
	//			numResults++
	//			self.newDiningDay(record)
	//		}
	//		operation.queryCompletionBlock = { (cursor, error) in
	//			dispatch_async(dispatch_get_main_queue(), { () -> Void in
	//				self.save()
	//				completion(error: numResults == 0 ? NSError() : error)
	//			})
	//		}
	//
	//		publicDB.addOperation(operation)
	//	}
	
	// MARK: - Core Data
	private func newDiningDay(record: CKRecord) {
		if let moc = managedObjectContext {
			DiningDay.dataFromInfo(moc, record: record)
		}
	}
	
	/// Can either grab the food or delete something
	func fetchDiningDay(date: NSDate) -> String {
		var fetchRequest = NSFetchRequest(entityName: "DiningDay")
		fetchRequest.predicate = NSPredicate(format: "\(CDDateField) == %@", comparisonDate(date: date))
		
		if let fetchResults = managedObjectContext!.executeFetchRequest(fetchRequest, error: nil) as? [DiningDay] {
			for result in fetchResults {
				if count(result.data) > 0 {
					return result.data
				}
			}
		}
		
		return ""
	}
	
	func save() {
		var error: NSError?
		if managedObjectContext!.save(&error) {
			if error != nil { println(error?.localizedDescription) }
		}
	}
	
	//	func uploadAsset(assetURL: NSURL, completion: (record: CKRecord) -> Void) {
	//		var assetRecord = CKRecord(recordType: HallRecordType)
	//		assetRecord.setObject(comparisonDate(NSDate()), forKey: DateField)
	//		assetRecord.setObject(CKAsset(fileURL: assetURL), forKey: DataField)
	//
	//		publicDB.saveRecord(assetRecord, completionHandler: { (record: CKRecord!, error: NSError!) -> Void in
	//			if error != nil {
	//				println("Error with uploading an asset")
	//				abort()
	//			} else {
	//				dispatch_async(dispatch_get_main_queue(), { () -> Void in
	//					completion(record: record)
	//				})
	//			}
	//		})
	//	}
	
	private func idFromDate(date: NSDate) -> CKRecordID {
		var form = NSDateFormatter()
		form.dateStyle = .ShortStyle
		return CKRecordID(recordName: form.stringFromDate(date))
	}
	
	func addRecord(date: NSDate, data: NSData, completion: (record: CKRecord) -> Void, halted: () -> Void) {
		if let dict = deserializedOpt(data) where DayBrief.isValid(dict) {
			let dateID = idFromDate(date)
			
			// download the current record (if it exists) and compare
			publicDB.fetchRecordWithID(dateID, completionHandler: { (fetched, error) -> Void in
				if let err = error {
					println(err)
					// check for the error type
				}
				
				if let record = fetched, recData = record.objectForKey(self.CKDataField) as? NSData where recData != data {
					self.addDayRecord(date, data: data, completion: completion)
				} else {
					if fetched == nil {
						self.addDayRecord(date, data: data, completion: completion)
					} else {
						// Nothing has changed for this date
						halted()
					}
				}
			})
		}
	}
	
	func addDayRecord(date: NSDate, data: NSData, completion: (record: CKRecord) -> Void) {
		var record = CKRecord(recordType: HallRecordType, recordID: idFromDate(date))
		record.setObject(comparisonDate(date: date), forKey: CKDateField)
		record.setObject(data, forKey: CKDataField)
		let dateID = idFromDate(date)
		
		let saveOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [])
		saveOp.savePolicy = .ChangedKeys
		saveOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
			if let hasError = error {
				println("Error!: \(hasError.description)")
			} else {
				if let firstSaved = savedRecords.first as? CKRecord {
					completion(record: firstSaved)
				}
				println("Upload complete for \(dateID.recordName)")
			}
		}
		publicDB.addOperation(saveOp)
	}
	
	func addQuickRecord(data: NSData, completion: (record: CKRecord) -> Void) {
		var record = CKRecord(recordType: QuickRecordType, recordID: CKRecordID(recordName: "quick"))
		record.setObject(data, forKey: CKDataField)
		
		let saveOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [])
		saveOp.savePolicy = CKRecordSavePolicy.ChangedKeys
		saveOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
			if let hasError = error {
				println("Error!: \(hasError.description)")
			} else {
				println("Upload complete!")
			}
		}
		publicDB.addOperation(saveOp)
	}
}
