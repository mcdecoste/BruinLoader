//
//  StartTableViewController.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 2/6/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import UIKit

class StartTableViewController: UITableViewController {
	var cells: Array<(name: String, value: Bool)> = [("Update Hall Menus", true), ("Update Quick", false)]
	var hallRow: Int = 0
	var quickRow: Int = 1
	let cellID = "Cell"
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellID)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			return cells.count
		case 1:
			return 1
		default:
			return 0
		}
    }

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		switch indexPath.section {
		case 0:
			return optionsCell(indexPath.row)
		default:
			var cell = tableView.dequeueReusableCellWithIdentifier(cellID, forIndexPath: indexPath) as! UITableViewCell
			cell.textLabel?.text = "Go!"
			
			return cell
		}
	}
	
	func optionsCell(row: Int) -> UITableViewCell {
		var cell = tableView.dequeueReusableCellWithIdentifier(cellID, forIndexPath: NSIndexPath(forRow: row, inSection: 0)) as! UITableViewCell
		let info = cells[row]
		
		cell.textLabel?.text = info.name
		cell.accessoryType = info.value ? .Checkmark : .None
		
		return cell
	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		switch indexPath.section {
		case 0:
			cells[indexPath.row].value = !cells[indexPath.row].value
			tableView.cellForRowAtIndexPath(indexPath)?.accessoryType = cells[indexPath.row].value ? .Checkmark : .None
			tableView.deselectRowAtIndexPath(indexPath, animated: true)
		default:
			var loadingView = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
			loadingView.startAnimating()
			tableView.cellForRowAtIndexPath(indexPath)?.accessoryView = loadingView
			
			tableView.deselectRowAtIndexPath(indexPath, animated: true)
			
			load()
			(tableView.cellForRowAtIndexPath(indexPath)?.accessoryView as! UIActivityIndicatorView).stopAnimating()
			tableView.cellForRowAtIndexPath(indexPath)?.accessoryView = nil
		}
	}
	
	private func load() {
		if cells[hallRow].value {
			preload()
		}
		
		if cells[quickRow].value {
			loadAndSaveQuick()
		}
	}
}