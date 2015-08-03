//
//  StartTableViewController.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 2/6/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import UIKit

var backgroundQueue = dispatch_queue_create("Bruin Loader Mac Background", nil)

class StartTableViewController: UITableViewController {
	var cells: Array<(name: String, value: Bool)> = [("Update Hall Menus", true), ("How Many Days Ahead?", false), ("Update Quick", false)]
	var hallRow: Int = 0
	var quickRow: Int = 1
	let cellID = "Cell", progressID = "Progress"
	
	var isLoading = false
	var numLoading = 8
	var numLoaded: Int {
		get {
			return responses.count
		}
	}
	
	var responses: Array<(date: NSDate, progress: Progress)> = []
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellID)
		tableView.registerClass(ProgressTableViewCell.self, forCellReuseIdentifier: progressID)
		
		navigationItem.title = "Menu Loader"
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Go!", style: .Plain, target: self, action: "load")
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "dayFinished:", name: "ProgressChanged", object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return isLoading ? 2 : 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			return cells.count
		case 1:
			return isLoading ? numLoading : 0
		default:
			return 0
		}
    }

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		switch indexPath.section {
		case 0:
			return optionsCell(indexPath.row)
		default:
			return progressCell(indexPath.row)
		}
	}
	
	func optionsCell(row: Int) -> UITableViewCell {
		var cell = tableView.dequeueReusableCellWithIdentifier(cellID, forIndexPath: NSIndexPath(forRow: row, inSection: 0)) as! UITableViewCell
		let info = cells[row]
		
		cell.textLabel?.text = info.name
		
		if row == 1 {
			cell.textLabel?.text = "Days in Advance: \(numLoading)"
			
			var stepper = UIStepper()
			stepper.value = Double(numLoading)
			stepper.maximumValue = 21
			stepper.addTarget(self, action: "dayChange:", forControlEvents: .ValueChanged)
			cell.accessoryView = stepper
			cell.accessoryType = .None
			cell.selectionStyle = .None
		} else {
			cell.accessoryView = nil
			cell.accessoryType = info.value ? .Checkmark : .None
			cell.selectionStyle = .Default
		}
		
		return cell
	}
	
	func progressCell(row: Int) -> UITableViewCell {
		var cell = tableView.dequeueReusableCellWithIdentifier(progressID) as! ProgressTableViewCell
		cell.date = comparisonDate(row)
		if responses.count > row {
			cell.progress = responses[row].progress
		}
		
		return cell
	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		switch indexPath.section {
		case 0:
			cells[indexPath.row].value = !cells[indexPath.row].value
			tableView.cellForRowAtIndexPath(indexPath)?.accessoryType = cells[indexPath.row].value ? .Checkmark : .None
			tableView.deselectRowAtIndexPath(indexPath, animated: true)
		default:
			return
			
		}
	}
	
	func dayChange(sender: UIStepper) {
		numLoading = Int(sender.value)
		tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 1, inSection: 0))!.textLabel?.text = "Days in Advance: \(numLoading)"
	}
	
	func load() {
		responses = map(0..<numLoading, { (days) -> (date: NSDate, progress: Progress) in
			return (date: comparisonDate(days), progress: .Waiting)
		})
		
		isLoading = cells[hallRow].value || cells[quickRow].value
		
		if isLoading {
			tableView.reloadData()
		}
		
		if cells[hallRow].value {
			dispatch_async(backgroundQueue, { () -> Void in
				preload(daysAhead: self.numLoading - 1)
			})
		}
		
		if cells[quickRow].value {
			dispatch_async(backgroundQueue, { () -> Void in
				loadAndSaveQuick()
			})
		}
	}
	
	func dayFinished(notification: NSNotification) {
		if let date = notification.object as? NSDate, progStr = notification.userInfo?["progress"] as? String, prog = Progress(rawValue: progStr) {
			let days = daysInFuture(date)
			responses[days].progress = prog
			println("\(date)\t\t\(prog.rawValue)\t\t\(days)\t\t\(responses[days].progress.rawValue)")
			
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: days, inSection: 1)], withRowAnimation: .None)
			})
		}
	}
}

class ProgressTableViewCell: UITableViewCell {
	var date: NSDate = NSDate() {
		didSet {
			let form = NSDateFormatter()
			form.dateStyle = .MediumStyle
			textLabel?.text = form.stringFromDate(date)
		}
	}
	
	var progress: Progress = .Waiting {
		didSet {
			detailTextLabel?.text = progress.rawValue
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		// Initialization code
	}
	
	override func setSelected(selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		
		// Configure the view for the selected state
	}
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: .Value1, reuseIdentifier: reuseIdentifier)
	}
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
}
