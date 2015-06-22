//
//  Model.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 6/15/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import Foundation

// MARK: Protocols

protocol Displayable {
	func display() -> String
}

protocol EatingPlace: Displayable {
	func place() -> Places
}

protocol URLProvider {
	func url() -> String
}

// MARK: Enums

enum DiningHall: EatingPlace {
	case DeNeve, Covel, Hedrick, Rieber, Sproul
	
	var urlCode: String {
		get {
			switch self {
			case .DeNeve:
				return "01"
			case .Sproul:
				return "02"
			case .Rieber:
				return "04"
			case .Hedrick:
				return "06"
			case .Covel:
				return "07"
			default:
				return ""
			}
		}
	}
	
	static func hallForString(name: String) -> DiningHall? {
		switch name.lowercaseString {
		case "deneve", "de neve":
			return .DeNeve
		case "covel":
			return .Covel
		case "hedrick":
			return .Hedrick
		case "rieber", "feast", "feast at rieber":
			return .Rieber
		case "sproul", "bruin plate", "bruinplate", "bplate", "b plate":
			return .Sproul
		default:
			return nil
		}
	}
	
	// EatingPlace
	
	func display() -> String {
		switch self {
		case .DeNeve:
			return "DeNeve"
		case .Sproul:
			return "Bruin Plate"
		case .Rieber:
			return "Feast"
		case .Hedrick:
			return "Hedrick"
		case .Covel:
			return "Covel"
		default:
			return ""
		}
	}
	
	func place() -> Places {
		switch self {
		case .DeNeve:
			return .DeNeve
		case .Sproul:
			return .Sproul
		case .Rieber:
			return .Rieber
		case .Hedrick:
			return .Rendezvous
		case .Covel:
			return .BruinCafe
		default:
			return .DeNeve
		}
	}
}

enum QuickService: EatingPlace {
	case Cafe1919, Rendezvous, BruinCafe, LateNight
	
	var urlCode: String {
		get {
			switch self {
			case .Cafe1919:
				return "cafe1919"
			case .Rendezvous:
				return "rendezvous"
			case .BruinCafe:
				return "bruincafe"
			case .LateNight:
				return "denevelatenight"
			default:
				return ""
			}
		}
	}
	
	static func quickForString(name: String) -> QuickService? {
		switch name.lowercaseString {
		case "cafe1919", "cafe 1919", "1919":
			return .Cafe1919
		case "rendezvous", "rendezvous at hedrick":
			return .Rendezvous
		case "bruin cafe", "bruincafe", "bcafe", "b cafe":
			return .BruinCafe
		case "latenight", "late night", "denevelatenight", "deneve latenight", "de neve latenight", "deneve late night", "de neve late night":
			return .LateNight
		default:
			return nil
		}
	}
	
	// EatingPlace
	
	func display() -> String {
		switch self {
		case .LateNight:
			return "Late Night"
		case .Cafe1919:
			return "Cafe 1919"
		case .Rendezvous:
			return "Rendezvous"
		case .BruinCafe:
			return "Bruin Cafe"
		default:
			return ""
		}
	}
	
	func place() -> Places {
		switch self {
		case .LateNight:
			return .DeNeve
		case .Cafe1919:
			return .Cafe1919
		case .Rendezvous:
			return .Rendezvous
		case .BruinCafe:
			return .BruinCafe
		default:
			return .DeNeve
		}
	}
}

enum Places {
	case DeNeve, Covel, Hedrick, Rieber, Sproul
	case Cafe1919, Rendezvous, BruinCafe
}

enum Meal: Displayable, Equatable {
	case Breakfast, Brunch, Lunch, Dinner, LateNight
	
	func display() -> String {
		switch self {
		case .Breakfast:
			return "Breakfast"
		case .Brunch:
			return "Brunch"
		case .Lunch:
			return "Lunch"
		case .Dinner:
			return "Dinner"
		case .LateNight:
			return "Late Night"
		default:
			return ""
		}
	}
	
	var urlCode: String {
		get {
			switch self {
			case .Breakfast:
				return "1"
			case .Lunch, .Brunch:
				return "2"
			case .Dinner:
				return "3"
			default:
				return ""
			}
		}
	}
	
	static func meals(date: NSDate, includeLateNight: Bool = false) -> Array<MealType> {
		var results: Array<MealType> = NSCalendar.currentCalendar().isDateInWeekend(date) ? [.Brunch, .Dinner] : [.Breakfast, .Lunch, .Dinner]
		if includeLateNight && !contains(results, .LateNight) {
			results.append(.LateNight)
		}
		return results
	}
	
	static func mealFromString(name: String) -> Meal? {
		switch name.lowercaseString {
		case "breakfast":
			return .Breakfast
		case "brunch":
			return .Brunch
		case "lunch":
			return .Lunch
		case "dinner":
			return .Dinner
		case "latenight", "late night":
			return .LateNight
		default:
			return nil
		}
	}
}

func ==(lhs: Meal, rhs: Meal) -> Bool {
	return lhs == rhs || (lhs == .Breakfast && rhs == .Lunch) || (rhs == .Breakfast && lhs == .Lunch)
}


enum FoodKind: Displayable {
	case Regular, Vegetarian, Vegan
	
	func display() -> String {
		switch self {
		case .Vegan:
			return "Vegan"
		case .Vegetarian:
			return "Vegetarian"
		default:
			return ""
		}
	}
	
	static func kind(name: String) -> FoodKind {
		switch name {
		case "Vegan":
			return .Vegan
		case "Vegetarian":
			return .Vegetarian
		default:
			return .Regular
		}
	}
}


enum HallSectionType: Comparable {
	case Headliner, Noteworthy, Standard, Meh
	
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

func <=(lhs: HallSectionType, rhs: HallSectionType) -> Bool {
	return !(lhs > rhs)
}

func >=(lhs: HallSectionType, rhs: HallSectionType) -> Bool {
	return !(lhs < rhs)
}

func <(lhs: HallSectionType, rhs: HallSectionType) -> Bool {
	switch lhs {
	case .Headliner:
		return false
	case .Noteworthy:
		return rhs == .Headliner
	case .Standard:
		return rhs == .Headliner || rhs == .Noteworthy
	default:
		return rhs != .Meh
	}
}

func >(lhs: HallSectionType, rhs: HallSectionType) -> Bool {
	switch lhs {
	case .Headliner:
		return rhs != .Headliner
	case .Noteworthy:
		return rhs == .Standard || rhs == .Meh
	case .Standard:
		return rhs == .Meh
	default:
		return false
	}
}


// MARK: Structs

struct DayMealHall: URLProvider, Equatable {
	var day: NSDate
	var meal: Meal
	var hall: DiningHall
	
	func url() -> String {
		return "http://menu.ha.ucla.edu/foodpro/default.asp?location=\(hall.urlCode)&date=\(dateURL(day))&meal=\(meal.urlCode)"
	}
}

func ==(lhs: DayMealHall, rhs: DayMealHall) -> Bool {
	return lhs.day == rhs.day && lhs.meal == rhs.meal && lhs.hall == rhs.hall
}



struct Quick: URLProvider, Equatable {
	var quick: QuickService
	
	func url() -> String {
		return "http://menu.ha.ucla.edu/foodpro/\(quick.urlCode).asp"
	}
}

func ==(lhs: Quick, rhs: Quick) -> Bool {
	return lhs.quick == rhs.quick
}



struct QuickMealHours {
	var meal: MealType
	var quicks: Array<QuickHours>
}

struct DiningMealHours {
	var meal: MealType
	var diningHalls: Array<DiningHours>
}


struct QuickHours {
	var quick: QuickService
	var openToday: Bool {
		get {
			return openTime != nil && closeTime != nil
		}
	}
	var openTime, closeTime: Time?
}

struct DiningHours {
	var hall: DiningHall
	var openTime, closeTime: Time?
}

struct FoodNutrient {
	var measures: Array<String>
	
	func measure(nutrient: Nutrient) -> String? {
		if let index = find(Nutrient.allValues, nutrient) where index < Nutrient.allValues.count {
			return measures[index]
		}
		return nil
	}
	
	func dailyValue(nutrient: Nutrient) -> Int? {
		if let index = find(Nutrient.allValues, nutrient), dailyValue = Nutrient.allDailyValues[index] {
			return Int(100.0 * ((measures[index] as NSString).floatValue) / Float(dailyValue))
		}
		return nil
	}
	
	init(dict: Dictionary<String, AnyObject>) {
		var newMeasures: Array<String> = []
		for nutr in Nutrient.allValues {
			newMeasures.append((dict[nutr.rawValue] as? String) ?? "0")
		}
		self.measures = newMeasures
	}
}

struct FoodLocations: Serializable {
	var info: FoodFull
	var places: Dictionary<String, Dictionary<String, Bool>>
	
	init(dict: Dictionary<String, AnyObject>) {
		info = FoodFull(dict: dict["info"] as! Dictionary<String, AnyObject>)
		places = dict["places"] as! Dictionary<String, Dictionary<String, Bool>>
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		return ["info" : info.dictFromObject(), "places" : places]
	}
}

struct FoodFull: Serializable { // Serializable
	var name, recipe: String
	var kind: FoodKind
	var ingredients, description, country, details: String
	var nutrients: FoodNutrient
	
	init(dict: Dictionary<String, AnyObject>) {
		name = dict["name"] as? String ?? "No Name"
		recipe = dict["recipe"] as? String ?? "No Recipe"
		kind = FoodKind.kind(dict["type"] as? String ?? "")
		nutrients = FoodNutrient(dict: dict)
		ingredients = dict["ingredients"] as? String ?? ""
		description = dict["description"] as? String ?? ""
		country = dict["country"] as? String ?? ""
		details = dict["details"] as? String ?? ""
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var dict: Dictionary<String, AnyObject> = [:]
		
		dict["name"] = name
		dict["recipe"] = recipe
		dict["type"] = kind.display()
		for nutrient in Nutrient.allValues {
			dict[nutrient.rawValue] = nutrients.measure(nutrient) ?? "0"
		}
		dict["ingredients"] = ingredients
		dict["description"] = description
		dict["details"] = details
		dict["country"] = country
		dict["withFood"] = [:] // withFoodBrief?.dictFromObject() ?? [:]
		
		return dict
	}
}

struct FoodShort: Serializable {
	var name, recipe: String
	var kind: FoodKind
	var details: String
	
	init(dict: Dictionary<String, AnyObject>) {
		name = dict["name"] as? String ?? "No Name"
		recipe = dict["recipe"] as? String ?? "No Recipe"
		kind = FoodKind.kind(dict["type"] as? String ?? "")
		details = dict["details"] as? String ?? ""
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var dict: Dictionary<String, AnyObject> = [:]
		
		dict["name"] = name
		dict["recipe"] = recipe
		dict["type"] = kind.display()
		dict["details"] = details
		
		return dict
	}
}

struct SectionShort: Serializable {
	var name: String, foods: Array<FoodShort>
	
	init(dict: Dictionary<String, AnyObject>) {
		name = dict["name"] as? String ?? ""
		
		var newFoods = Array<FoodShort>()
		if let foodDicts = dict["foods"] as? Array<Dictionary<String, AnyObject>> {
			for foodDict in foodDicts { newFoods.append(FoodShort(dict: foodDict)) }
		}
		foods = newFoods
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var dict: Dictionary<String, AnyObject> = [:]
		
		dict["name"] = name
		var foodDicts: Array<Dictionary<String, AnyObject>> = []
		for food in foods {
			foodDicts.append(food.dictFromObject())
		}
		dict["foods"] = foodDicts
		
		return dict
	}
}

struct DiningPlaceShort: Serializable, Displayable {
	var hours: DiningHours
	var sections: Array<SectionShort>
	
	init(dict: Dictionary<String, AnyObject>) {
		if let hallName = dict["hall"] as? String, hall = DiningHall.hallForString(hallName), oH = dict["openHour"] as? Int, oM = dict["openMin"] as? Int, cH = dict["closeHour"] as? Int, cM = dict["closeMin"] as? Int {
			hours = DiningHours(hall: hall, openTime: Time(hour: oH, minute: oM), closeTime: Time(hour: cH, minute: cM))
		} else {
			hours = DiningHours(hall: .DeNeve, openTime: nil, closeTime: nil)
		}
		
		var newSections = Array<SectionShort>()
		var sectionDicts = dict["sections"] as? Array<Dictionary<String, AnyObject>> ?? []
		for sectionDict in sectionDicts {
			newSections.append(SectionShort(dict: sectionDict))
		}
		sections = newSections
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var dict: Dictionary<String, AnyObject> = [:]
		
		dict["hall"] = display()
		dict["openHour"] = hours.openTime?.hour ?? ""
		dict["openMin"] = hours.openTime?.minute ?? ""
		dict["closeHour"] = hours.closeTime?.hour ?? ""
		dict["closeMin"] = hours.closeTime?.minute ?? ""
		
		var sectionDicts = Array<Dictionary<String, AnyObject>>()
		for section in sections {
			sectionDicts.append(section.dictFromObject())
		}
		dict["sections"] = sectionDicts
		
		return dict
	}
	
	var hall: DiningHall {
		get {
			return hours.hall
		}
	}
	
	func display() -> String {
		return hall.display()
	}
}

struct QuickPlaceShort: Serializable, Displayable {
	var hours: QuickHours
	var sections: Array<SectionShort>
	
	init(dict: Dictionary<String, AnyObject>) {
		if let quickName = dict["hall"] as? String, quick = QuickService.quickForString(quickName), oH = dict["openHour"] as? Int, oM = dict["openMin"] as? Int, cH = dict["closeHour"] as? Int, cM = dict["closeMin"] as? Int {
			hours = QuickHours(quick: quick, openTime: Time(hour: oH, minute: oM), closeTime: Time(hour: cH, minute: cM))
		} else {
			hours = QuickHours(quick: .BruinCafe, openTime: nil, closeTime: nil)
		}
		
		var newSections = Array<SectionShort>()
		var sectionDicts = dict["sections"] as? Array<Dictionary<String, AnyObject>> ?? []
		for sectionDict in sectionDicts {
			newSections.append(SectionShort(dict: sectionDict))
		}
		sections = newSections
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var dict: Dictionary<String, AnyObject> = [:]
		
		dict["hall"] = display()
		dict["openHour"] = hours.openTime?.hour ?? ""
		dict["openMin"] = hours.openTime?.minute ?? ""
		dict["closeHour"] = hours.closeTime?.hour ?? ""
		dict["closeMin"] = hours.closeTime?.minute ?? ""
		
		var sectionDicts = Array<Dictionary<String, AnyObject>>()
		for section in sections {
			sectionDicts.append(section.dictFromObject())
		}
		dict["sections"] = sectionDicts
		
		return dict
	}
	
	var quick: QuickService {
		get {
			return hours.quick
		}
	}
	
	func display() -> String {
		return quick.display()
	}
}

struct DiningMealShort: Serializable {
	var halls: Array<DiningPlaceShort>
	
	init(dict: Dictionary<String, AnyObject>) {
		halls = []
		if let quickDicts = dict["halls"] as? Dictionary<String, Dictionary<String, AnyObject>> {
			for (quickKey, quickDict) in quickDicts {
				// verify input, but honestly it's useless cruft
				if let quickPlace = DiningHall.hallForString(quickKey) {
					halls.append(DiningPlaceShort(dict: quickDict))
				}
			}
		}
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var quicksDict = Dictionary<String, Dictionary<String, AnyObject>>()
		for (name, quickDict) in map(halls, { (quick: DiningPlaceShort) -> (name: String, dict: Dictionary<String, AnyObject>) in return (name: quick.display() , dict: quick.dictFromObject()) }) {
			quicksDict[name] = quickDict
		}
		
		return ["halls" : quicksDict]
	}
}

struct QuickMealShort: Serializable {
	var quicks: Array<QuickPlaceShort>
	
	init(dict: Dictionary<String, AnyObject>) {
		quicks = []
		if let quickDicts = dict["halls"] as? Dictionary<String, Dictionary<String, AnyObject>> {
			for (quickKey, quickDict) in quickDicts {
				if let quickPlace = QuickService.quickForString(quickKey) {
					quicks.append(QuickPlaceShort(dict: quickDict))
				}
			}
		}
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var quicksDict = Dictionary<String, Dictionary<String, AnyObject>>()
		for (name, quickDict) in map(quicks, { (quick: QuickPlaceShort) -> (name: String, dict: Dictionary<String, AnyObject>) in return (name: quick.display() , dict: quick.dictFromObject()) }) {
			quicksDict[name] = quickDict
		}
		
		return ["halls" : quicksDict]
	}
}

struct DiningDayShort: Serializable {
	var date: NSDate
	var meals: Dictionary<Meal, DiningMealShort>
	var foods: Dictionary<String, FoodLocations>
	
	init(dict: Dictionary<String, AnyObject>) {
		if let dateStr = dict["date"] as? String, mealsDict = dict["meals"] as? Dictionary<String, Dictionary<String, AnyObject>>, foodDict = dict["foods"] as? Dictionary<String, Dictionary<String, AnyObject>> {
			
			var form = NSDateFormatter()
			form.dateStyle = .ShortStyle
			if let theDate = form.dateFromString(dateStr) {
				date = theDate
			} else {
				// fail case
				date = NSDate(timeIntervalSince1970: 0)
			}
			
			var newMeals = Dictionary<Meal, DiningMealShort>()
			for (mealName, mealDict) in mealsDict {
				if let meal = Meal.mealFromString(mealName) {
					newMeals[meal] = DiningMealShort(dict: mealDict)
				}
			}
			meals = newMeals
			
			var newFoods = Dictionary<String, FoodLocations>()
			var foodsDict = dict["foods"] as! Dictionary<String, Dictionary<String, AnyObject>>
			for (recipe, foodDict) in foodsDict {
				newFoods[recipe] = FoodLocations(dict: foodDict)
			}
			foods = newFoods
		} else {
			// fail case
			date = NSDate(timeIntervalSince1970: 0)
			meals = [:]
			foods = [:]
		}
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var dict = Dictionary<String, AnyObject>()
		
		var form = NSDateFormatter()
		form.dateStyle = .ShortStyle
		dict["date"] = form.stringFromDate(date)
		
		var mealsDict = Dictionary<String, Dictionary<String, AnyObject>>()
		for (mealName, meal) in meals {
			mealsDict[mealName.display()] = meal.dictFromObject()
		}
		dict["meals"] = mealsDict
		
		var foodsDict: Dictionary<String, Dictionary<String, AnyObject>> = [:]
		for (recipe, food) in foods {
			foodsDict[recipe] = food.dictFromObject()
		}
		dict["foods"] = foodsDict
		
		return dict
	}
	
	static func isValid(dict: Dictionary<String, AnyObject>) -> Bool {
		if let dateStr = dict["date"] as? String, mealDict = dict["meals"] as? Dictionary<String, Dictionary<String, AnyObject>>, foodDict = dict["foods"] as? Dictionary<String, Dictionary<String, AnyObject>> {
			return true
		}
		return false
	}
}

struct QuickFullShort: Serializable {
	var meals: Dictionary<Meal, QuickMealShort>
	var foods: Dictionary<String, FoodLocations>
	
	init(dict: Dictionary<String, AnyObject>) {
		if let mealsDict = dict["meals"] as? Dictionary<String, Dictionary<String, AnyObject>>, foodDict = dict["foods"] as? Dictionary<String, Dictionary<String, AnyObject>> {
			
			var newMeals = Dictionary<Meal, QuickMealShort>()
			for (mealName, mealDict) in mealsDict {
				if let meal = Meal.mealFromString(mealName) {
					newMeals[meal] = QuickMealShort(dict: mealDict)
				}
			}
			meals = newMeals
			
			var newFoods = Dictionary<String, FoodLocations>()
			var foodsDict = dict["foods"] as! Dictionary<String, Dictionary<String, AnyObject>>
			for (recipe, foodDict) in foodsDict {
				newFoods[recipe] = FoodLocations(dict: foodDict)
			}
			foods = newFoods
		} else {
			// fail case
			meals = [:]
			foods = [:]
		}
	}
	
	func dictFromObject() -> Dictionary<String, AnyObject> {
		var dict = Dictionary<String, AnyObject>()
		
		var form = NSDateFormatter()
		form.dateStyle = .ShortStyle
		dict["date"] = form.stringFromDate(NSDate()) // don't care which day, legacy
		
		var mealsDict = Dictionary<String, Dictionary<String, AnyObject>>()
		for (mealName, meal) in meals {
			mealsDict[mealName.display()] = meal.dictFromObject()
		}
		dict["meals"] = mealsDict
		
		var foodsDict: Dictionary<String, Dictionary<String, AnyObject>> = [:]
		for (recipe, food) in foods {
			foodsDict[recipe] = food.dictFromObject()
		}
		dict["foods"] = foodsDict
		
		return dict
	}
	
	static func isValid(dict: Dictionary<String, AnyObject>) -> Bool {
		if let mealDict = dict["meals"] as? Dictionary<String, Dictionary<String, AnyObject>>, foodDict = dict["foods"] as? Dictionary<String, Dictionary<String, AnyObject>> {
			return true
		}
		return false
	}
}

// MARK: Helper Functions

