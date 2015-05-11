//
//  HallModel.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 5/10/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import Foundation

enum HallSectionType {
	case Headliner
	case Noteworthy
	case Standard
	case Meh
	
	static func typeFromString(str: String) -> HallSectionType {
		switch str {
		case "Exhibition Kitchen", "Euro Kitchen", "The Front Burner", "The Kitchen", "Freshly Bowled", "Harvest", "Bruin Wok", "Spice Kitchen":
			return Headliner
		case "Pizza Oven", "The Pizzeria", "Stone Oven", "Simply Grilled", "Iron Grill":
			return Noteworthy
		case "Grill", "The Grill", "Soups":
			return Standard
		default:
			return Meh
		}
	}
	
	// The order here is important. Sets display order
	static let allValues: Array<HallSectionType> = [Headliner, Noteworthy, Standard, Meh]
}

func sortSections(sections: Array<SectionBrief>) -> Array<SectionBrief> {
	var conversion: Dictionary<HallSectionType, Int> = [:]
	for (index, type) in enumerate(HallSectionType.allValues) {
		conversion[type] = index
	}
	
	var categories: Array<Array<SectionBrief>> = map(HallSectionType.allValues, { (type: HallSectionType) -> Array<SectionBrief> in
		return []
	})
	
	for section in sections {
		let catIndex = conversion[HallSectionType.typeFromString(section.name)]!
		categories[catIndex].append(section)
	}
	
	var sorted: Array<SectionBrief> = []
	for (index, type) in enumerate(HallSectionType.allValues) {
		sorted.extend(categories[index])
	}
	
	// printouts
//	for entry in sorted {
//		println(entry.name)
//	}
	
	return sorted
}