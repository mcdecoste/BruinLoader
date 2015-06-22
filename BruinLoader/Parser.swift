//
//  Parser.swift
//  BruinLoader
//
//  Created by Matthew DeCoste on 3/26/15.
//  Copyright (c) 2015 Matthew DeCoste. All rights reserved.
//

import UIKit

func preload(daysAhead: Int = 7) {
	preload(map(0...daysAhead, { $0 }))
}

func preload(days: Array<Int>) {
	let cal = NSCalendar.currentCalendar()
	let today = cal.startOfDayForDate(NSDate())
	let daysToLoad = map(days, { return cal.dateByAddingUnit(.CalendarUnitDay, value: $0, toDate: today, options: nil)! })
	
	for day in daysToLoad {
		loadAllBrief(day)
	}
}

func uploadDay(brief: DayBrief) {
	CloudManager.sharedInstance.addRecord(brief.date, data: serialize(brief)) { (record) -> Void in
		postProgressNotification(brief.date, .Uploaded)
	}
}

func loadAllBrief(date: NSDate) {
	postProgressNotification(date, .Loading)
	
	let hours = loadHours(date), day = DayBrief(date: date, meals: [:])
	for meal in MealType.allMeals(date, includeLateNight: true) {
		if let mealHours = hours[meal] {
			var mealBrief = MealBrief(halls: [:])
			
			if meal.urlCode() != nil { // basically if it's not late night
				for hall in Halls.allDiningHalls {
					let (open, hallBrief, foods) = loadMealBrief(hall, meal, date)
					if open && hallBrief.sections.count > 0 {
						if let hallHours = mealHours[hall] where hallHours.open {
							hallBrief.openTime = (hallHours.openTime)!
							hallBrief.closeTime = (hallHours.closeTime)!
							
							mealBrief.halls[hall] = hallBrief
							for (recipe, food) in foods {
								// if first time, create food collection
								if day.foods[recipe] == nil {
									day.foods[recipe] = FoodCollection(info: food)
								}
								
								// make a list of where it's from
								if let mealColl = day.foods[recipe]!.places[meal.rawValue] {
									day.foods[recipe]!.places[meal.rawValue]![hall.rawValue] = true
								} else {
									day.foods[recipe]!.places[meal.rawValue] = [hall.rawValue : true]
								}
							}
						}
					}
				}
			}
			
			for quick in Halls.allQuickServices {
				if let quickHours = mealHours[quick] {
					if quickHours.open && (quick != .DeNeve || meal == .LateNight) {
						// add empty listing in mealInfo for the hall (with open / close times)
						var hallBrief = RestaurantBrief(hall: quick)
						(hallBrief.openTime, hallBrief.closeTime) = (quickHours.openTime!, quickHours.closeTime!)
						mealBrief.halls[quick] = hallBrief
					}
				}
			}
			day.meals[meal] = mealBrief
		}
	}
	
	postProgressNotification(date, .Loaded)
	uploadDay(day)
}

// MARK: Quick Service Parsers

func loadAndSaveQuick() {
	let quickData = serialize(loadQuick())
	CloudManager.sharedInstance.addQuickRecord(quickData, completion: { (record) -> Void in
		postProgressNotification(nil, .Uploaded)
	})
}

func loadQuick() -> DayBrief {
	postProgressNotification(nil, .Loading)
	
	// Bruin Cafe
	println("Bruin Cafe")
	let bcBrief = loadBruinCafe()
	
	// 1919
	println("Cafe 1919")
	let c1919Brief = loadCafe1919()
	
	// Rendezvous
	println("Rendezvous")
	let rBrief = loadRendezvous()
	
	// Late Night
	println("Late Night")
	let lnBrief = loadLateNight()
	
	// merge them all together into one day
	let allInfo: Array<DayBrief> = [bcBrief, c1919Brief, rBrief, lnBrief]
	
	var quickBrief = DayBrief(date: NSDate(), meals: [:])
	for meal in [.Breakfast, .Lunch, .Dinner, .LateNight] as Array<MealType> {
		var mealBrief = MealBrief(halls: [:])
		for info in allInfo {
			if let halls = info.meals[meal]?.halls {
				for hall in halls.keys.array {
					mealBrief.halls[hall] = halls[hall]!
				}
			}
		}
		quickBrief.meals[meal] = mealBrief
	}
	
	for partBrief in allInfo {
		for (recipe, collection) in partBrief.foods {
			if quickBrief.foods[recipe] == nil {
				quickBrief.foods[recipe] = collection
			} else {
				for (meal, halls) in collection.places {
					for (hall, involved) in halls {
						quickBrief.foods[recipe]!.places[meal]![hall] = involved
					}
				}
			}
		}
	}
	
	for (meal, mBrief) in quickBrief.meals {
		for (hall, hBrief) in mBrief.halls {
			quickBrief.meals[meal]!.halls[hall]!.openTime = Time(hour: 8, minute: 0)
			quickBrief.meals[meal]!.halls[hall]!.closeTime = Time(hour: 8, minute: 0)
			// this guarantees that it won't be shown as open unless it is actually open that day
		}
	}
	
	postProgressNotification(nil, .Loaded)
	return quickBrief
}

func loadBruinCafe() -> DayBrief {
	let currHall = Halls.BruinCafe
	var foods: Dictionary<String, FoodCollection> = [:]
	
	let url = "http://menu.ha.ucla.edu/foodpro/bruincafe.asp"
	let subsectClass = "subsectiontop"
	
	var bruinErr: NSError? = nil
	let bruinURL = NSURL(string: url)!
	var bruinHTML = NSString(contentsOfURL: bruinURL, encoding: NSASCIIStringEncoding, error: &bruinErr) as! String
	
	var bruinDescriptions = foodDescriptions(bruinHTML)
	let hpple = Hpple(HTMLData: bruinHTML)
	
	var menuParts = hpple.searchWithXPathQuery("//div[@id='menuwrapper']/div[@class='section']")! // div[@class='subsection'
	var restBrief = RestaurantBrief(hall: currHall)
	
	for menu in menuParts {
		let sectionID = menu.attributes["id"] as! String
		var foodSections = hpple.searchWithXPathQuery("//div[@id='\(sectionID)' and @class='section']//div[@class='subsection']")!
		
		for (index, section) in enumerate(foodSections) {
			if section.children![1].attributes["class"] as! String == subsectClass {
				var sectionBrief = SectionBrief(name: section.children![1].children![0].text!)
				
				for i in stride(from: 3, to: section.children!.count - 1, by: 2) {
					var child = section.children![i]
					
					if let childClass = (child.attributes["class"] as? String) {
						// TODO: B, L, D, and PM tell you which meals each applies to. Use it?
						let validChars = NSCharacterSet(charactersInString: "BLDP")
						if String(childClass[childClass.startIndex]).stringByTrimmingCharactersInSet(validChars) == "" {
							// it's a food, process it
							var valid = true
							
							var food: FoodInfo = FoodInfo(name: "", recipe: "", type: .Regular)
							var price: String = ""
							var descr: String = ""
							
							for foodChildren in child.children! {
								if let spanClass = foodChildren.attributes["class"] as? String {
									if spanClass.rangeOfString("name") != nil {
										if foodChildren.text != nil && foodChildren.text! == "Soup of the Day:" {
											valid = false
										} else {
											food = processFoodPart(foodChildren, bruinDescriptions)
										}
									}
									if spanClass.rangeOfString("price") != nil {
										price = foodChildren.text!.stringByTrimmingCharactersInSet(.whitespaceCharacterSet())
									}
									if spanClass.rangeOfString("desc") != nil {
										descr = foodChildren.text!
									}
								}
							}
							
							if valid {
								food.description = descr == "" ? price : "\(descr) (\(price))"
								foods[food.recipe] = FoodCollection(info: food)
								sectionBrief.foods.append(FoodBrief(food: food))
							}
						}
					}
				}
				restBrief.sections.append(sectionBrief)
			}
		}
	}
	
	var breakfastBrief = RestaurantBrief(hall: currHall)
	var lunchBrief = RestaurantBrief(hall: currHall)
	var dinnerBrief = RestaurantBrief(hall: currHall)
	var lateNightBrief = RestaurantBrief(hall: currHall)
	
	// let's move things around for different meals
	for (index, section) in enumerate(restBrief.sections) {
		switch index {
		case 0...1: // Breakfast Only
			breakfastBrief.sections.append(section)
		case 8: // it's chips!
			section.name = "Chips"
			fallthrough
		case 2...7:
			lunchBrief.sections.append(section)
			dinnerBrief.sections.append(section)
			lateNightBrief.sections.append(section)
		case 10...13:
			section.name = "On the Go: " + section.name
			lunchBrief.sections.append(section)
		case 14...16:
			section.name = "On the Go: " + section.name
			dinnerBrief.sections.append(section)
			lateNightBrief.sections.append(section)
		default:
			// no one gets it
			section.name = "sad trombones"
		}
	}
	
	var dayBrief = DayBrief()
	dayBrief.foods = foods
	
	let mealsForDay: Array<(meal: MealType, info: RestaurantBrief)> = [(.Breakfast, breakfastBrief), (.Lunch, lunchBrief), (.Dinner, dinnerBrief), (.LateNight, lateNightBrief)]
	for (meal, info) in mealsForDay {
		dayBrief.meals[meal] = MealBrief(halls: [currHall : info])
	}
	
	return dayBrief
}

func loadCafe1919() -> DayBrief {
	let currHall = Halls.Cafe1919
	var foods: Dictionary<String, FoodCollection> = [:]
	
	var error: NSError? = nil
	let url = NSURL(string: "http://menu.ha.ucla.edu/foodpro/cafe1919.asp")!
	var html = NSString(contentsOfURL: url, encoding: NSASCIIStringEncoding, error: &error) as! String
	
	var descriptions = foodDescriptions(html)
	let hpple = Hpple(HTMLData: html)
	
	var menuSections = hpple.searchWithXPathQuery("//div[@id='menuwrapper']/div[@class='menucontainer']/div[@class='section']")!
	var restBrief = RestaurantBrief(hall: currHall)
	
	for (index, menu) in enumerate(menuSections[1...7]) { // TODO: remove this hardcoding
		if index == 5 {
			continue // skip bibite entirely
		}
		
		let sectionID = menu.attributes["id"] as! String
		let classID = "section_menu" + (sectionID == "s7" ? "" : " hascombo")
		
		let sectionTitle = hpple.searchWithXPathQuery("//div[@id='\(sectionID)' and @class='section']//div[@class='section_banner']/img")![0].attributes["alt"] as! String
		var sectionBrief = SectionBrief(name: sectionTitle)
		
		let foodsQuery = sectionTitle != "Bibite" ? "//div[@id='\(sectionID)' and @class='section']//td[@class='\(classID)']/div" : "//td[@id='coffeetablecell_left']"
		var foodsRaw = hpple.searchWithXPathQuery(foodsQuery)!
		
		for foodRaw in foodsRaw {
			var valid = false
			
			var food: FoodInfo = FoodInfo(name: "", recipe: "", type: .Regular)
			var price: String = ""
			var subtitle: String = ""
			var descr: String = ""
			
			if let chilrenRaw = foodRaw.children {
				for aspect in chilrenRaw {
					if let spanClass = aspect.attributes["class"] as? String {
						if spanClass.rangeOfString("name") != nil {
							food = processFoodPart(aspect, descriptions)
							valid = true
						}
						if spanClass.rangeOfString("price") != nil {
							price = aspect.text!.stringByTrimmingCharactersInSet(.whitespaceCharacterSet())
						}
						if spanClass.rangeOfString("desc1") != nil {
							switch sectionTitle {
							case "Lasagna", "Bibite", "Dolci":
								descr = aspect.text!
							default:
								subtitle = aspect.text!
							}
						}
						if spanClass.rangeOfString("desc2") != nil {
							descr = aspect.text!
						}
					}
				}
			}
			
			if valid {
				var foodBrief = FoodBrief(food: food)
				
				food.description = descr == "" ? price : "\(descr) (\(price))"
				
				if subtitle != "" {
					foodBrief.sideBrief = FoodBrief(food: FoodInfo(name: subtitle, recipe: "", type: .Regular))
				}
				
				sectionBrief.foods.append(foodBrief)
				foods[food.recipe] = FoodCollection(info: food)
			}
		}
		restBrief.sections.append(sectionBrief)
	}
	
	var lunchBrief = RestaurantBrief(hall: currHall)
	var dinnerBrief = RestaurantBrief(hall: currHall)
	var lateNightBrief = RestaurantBrief(hall: currHall)
	
	for (index, section) in enumerate(restBrief.sections) {
		switch index {
		case 3: // no late night!
			lunchBrief.sections.append(section)
			dinnerBrief.sections.append(section)
		default:
			lunchBrief.sections.append(section)
			dinnerBrief.sections.append(section)
			lateNightBrief.sections.append(section)
		}
	}
	
	var dayBrief = DayBrief()
	dayBrief.date = NSDate()
	
	let mealsForDay: Array<(meal: MealType, info: RestaurantBrief)> = [(.Lunch, lunchBrief), (.Dinner, dinnerBrief), (.LateNight, lateNightBrief)]
	for (meal, brief) in mealsForDay {
		dayBrief.meals.updateValue(MealBrief(halls: [currHall : brief]), forKey: meal)
	}
	dayBrief.foods = foods
	
	return dayBrief
}

func loadRendezvous() -> DayBrief {
	let currHall = Halls.Rendezvous
	var foods: Dictionary<String, FoodCollection> = [:]
	
	var error: NSError? = nil
	let url = NSURL(string: "http://menu.ha.ucla.edu/foodpro/rendezvous.asp")!
	let html = NSString(contentsOfURL: url, encoding: NSASCIIStringEncoding, error: &error) as! String
	let descriptions = foodDescriptions(html)
	let hpple = Hpple(HTMLData: html)
	
	var menuSections = hpple.searchWithXPathQuery("//div[@id='menuwrapper']/div[@class='menucontainer']/div[@class='section']")!
	var restBrief = RestaurantBrief(hall: currHall)
	
	for menuSection in menuSections[0...3] {
		let sectionID = menuSection.attributes["id"] as! String
		let sectionsQuery = "//div[@id='\(sectionID)' and @class='section']/div"
		var sectionsRaw = hpple.searchWithXPathQuery(sectionsQuery)!
		
		for sectionRaw in sectionsRaw {
			var sectionExists = false
			var currSectionName = ""
			var currSectionFoods: Array<FoodBrief> = []
			
			for line in sectionRaw.children! {
				if let raw = line.raw {
					switch line.tagName! {
					case "h1":
						if sectionExists {
							var nextSection = SectionBrief(name: currSectionName)
							for food in currSectionFoods {
								nextSection.foods.append(food)
							}
							restBrief.sections.append(nextSection)
							sectionExists = false
						}
						if line.text! != "" {
							currSectionName = line.text!
						}
						currSectionFoods = []
					case "div":
						let lineClass = line.attributes["class"] as! String
						if lineClass.rangeOfString("item") != nil {
							sectionExists = true
							
							var valid = false
							var food: FoodInfo = FoodInfo(name: "", recipe: "", type: .Regular)
							var price: String = ""
							var subtitle: String = ""
							
							for span in line.children! {
								if let spanClass = span.attributes["class"] as? String {
									if spanClass.rangeOfString("name") != nil {
										if span.raw?.rangeOfString("Coffee") != nil {
											var foodName = ""
											var recipe = ""
											var type: FoodType = span.raw?.rangeOfString("Boba") == nil ? .Vegan : .Vegetarian
											for coffeeChild in span.children! {
												if coffeeChild.tagName! == "a" {
													foodName = coffeeChild.text!
													var recipeArea = coffeeChild.attributes["href"] as! String
													var recipeRange = recipeArea.rangeOfString("=")!
													recipeRange.startIndex = recipeRange.startIndex.successor()
													recipeRange.endIndex = recipeArea.rangeOfString("&")!.startIndex
													recipe = recipeArea.substringWithRange(recipeRange)
												}
											}
											food = FoodInfo(name: foodName, recipe: recipe, type: type)
											
											valid = true
										} else if span.raw?.rangeOfString("Fountain Beverage") == nil {
											var foodInfo = processFoodPart(span, descriptions)
											food = FoodInfo(formattedString: foodInfo.foodString())
											valid = true
										}
									}
									if spanClass.rangeOfString("price") != nil {
										price = span.text!.stringByTrimmingCharactersInSet(.whitespaceCharacterSet())
									}
									if spanClass.rangeOfString("desc") != nil {
										subtitle = span.text!
									}
								}
							}
							
							if valid {
								if let descr = descriptions[food.recipe] {
									food.description = descr
								}
								
								var foodBrief = FoodBrief(food: food)
								
								if subtitle != "" {
									food.description = subtitle
								}
								foodBrief.sideBrief = FoodBrief(food: FoodInfo(name: price, recipe: "", type: .Regular))
								
								foods[food.recipe] = FoodCollection(info: food)
								currSectionFoods.append(foodBrief)
							}
						}
					default:
						continue
					}
				}
			}
			
			if sectionExists {
				var nextSection = SectionBrief(name: currSectionName)
				for food in currSectionFoods {
					nextSection.foods.append(food)
				}
				restBrief.sections.append(nextSection)
			}
		}
	}
	
	var theSections: Array<SectionBrief> = []
	
	var noodleBowlSection = SectionBrief(name: "Noodle Bowls")
	var asianSpecialsSection = SectionBrief(name: "Asian Daily Specials")
	
	let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
	
	for (sectionIndex, section) in enumerate(restBrief.sections) {
		if sectionIndex == 8 {
			for (index, food) in enumerate(section.foods) {
				if let side = food.sideBrief {
					section.foods[index].sideBrief!.name = "\(days[(index)/2]) - \(side.name)"
				} else {
					section.foods[index].sideBrief = FoodBrief(food: FoodInfo(name: days[(index)/2], recipe: "", type: .Regular))
				}
			}
		}
		
		if section.name != "" {
			theSections.append(section)
		} else { // special cases for the noodle bowls and asian daily specials sections
			for (foodIndex, food) in enumerate(section.foods) {
				if let side = food.sideBrief {
					section.foods[foodIndex].sideBrief!.name = "\(days[(sectionIndex-10)/2]) - \(side.name)"
				} else {
					section.foods[foodIndex].sideBrief = FoodBrief(food: FoodInfo(name: days[(sectionIndex-10)/2], recipe: "", type: .Regular))
				}
				
				switch foodIndex % 2 {
				case 0:
					asianSpecialsSection.foods.append(food)
				default: // 1
					noodleBowlSection.foods.append(food)
				}
			}
		}
	}
	
	theSections.insert(noodleBowlSection, atIndex: 10)
	theSections.insert(asianSpecialsSection, atIndex: 11)
	
	for (index, boba) in enumerate(theSections[16].foods) {
		var prefix = index < 5 ? "16 oz. " : "32 oz. "
		theSections[16].foods[index].name = prefix + boba.name
	}
	
	var breakfastBrief = RestaurantBrief(hall: currHall)
	var lunchBrief = RestaurantBrief(hall: currHall)
	var dinnerBrief = RestaurantBrief(hall: currHall)
	var lateNightBrief = RestaurantBrief(hall: currHall)
	
	for (index, section) in enumerate(theSections) {
		switch index {
		case 0...5: // breakfast only!
			breakfastBrief.sections.append(section)
		case 6...16: // lunch to late night
			lunchBrief.sections.append(section)
			dinnerBrief.sections.append(section)
			lateNightBrief.sections.append(section)
		default: // desserts is late night only
			lateNightBrief.sections.append(section)
		}
	}
	
	
	var dayBrief = DayBrief()
	dayBrief.foods = foods
	dayBrief.date = NSDate()
	
	let mealsForDay: Array<(meal: MealType, info: RestaurantBrief)> = [(.Breakfast, breakfastBrief), (.Lunch, lunchBrief), (.Dinner, dinnerBrief), (.LateNight, lateNightBrief)]
	for (meal, info) in mealsForDay {
		dayBrief.meals[meal] = MealBrief(halls: [currHall : info])
	}
	
	return dayBrief
}

func loadLateNight() -> DayBrief {
	let currHall = Halls.DeNeve
	var foods: Dictionary<String, FoodCollection> = [:]
	
	var error: NSError? = nil
	let url = NSURL(string: "http://menu.ha.ucla.edu/foodpro/denevelatenight.asp")!
	let html = NSString(contentsOfURL: url, encoding: NSASCIIStringEncoding, error: &error) as! String
	let descriptions = foodDescriptions(html)
	let hpple = Hpple(HTMLData: html)
	
	var menuSections = hpple.searchWithXPathQuery("//td[@id='borderinside']/div[@class='section']")!
	var restBrief = RestaurantBrief(hall: currHall)
	
	for (menuIndex, menuSection) in enumerate(menuSections[0...2]) {
		let sectionID = menuSection.attributes["id"] as! String
		let sectionsQuery = "//div[@id='\(sectionID)' and @class='section']/div" + (menuIndex == 1 ? "/div" : "")
		var entriesRaw = hpple.searchWithXPathQuery(sectionsQuery)!
		
		var sectionExists = false
		var currSectionName = ""
		var currSectionFoods: Array<FoodBrief> = []
		for entryRaw in entriesRaw {
			let divType = entryRaw.attributes["class"] as! String
			if divType == "catheader" {
				let sectionName = entryRaw.children![0].attributes["src"] as! String
				var underRange = sectionName.rangeOfString("_")!
				underRange.startIndex = underRange.endIndex
				underRange.endIndex = sectionName.rangeOfString(".png")!.startIndex
				var newName = sectionName.substringWithRange(underRange)
				
				let capStart = String(newName[newName.startIndex]).capitalizedString
				let firstRange = newName.startIndex...newName.startIndex
				newName.replaceRange(firstRange, with: capStart)
				if newName == "Mypizza" { newName = "MyPizza" }
				
				if currSectionFoods.count != 0 {
					var nextSection = SectionBrief(name: currSectionName)
					for food in currSectionFoods {
						nextSection.foods.append(food)
					}
					restBrief.sections.append(nextSection)
					sectionExists = false
				}
				currSectionName = newName
				currSectionFoods = []
			} else if divType.rangeOfString("item") != nil {
				let entryHpple = Hpple(HTMLData: entryRaw.raw!)
				let foodParts = entryHpple.searchWithXPathQuery("//span")!
				
				var food: FoodInfo = FoodInfo(name: "", recipe: "", type: .Regular)
				var price = ""
				var description = ""
				var subtitle = ""
				
				for foodPart in foodParts {
					let partClass = foodPart.attributes["class"] as! String
					if partClass.rangeOfString("name") != nil {
						if foodPart.raw?.rangeOfString("Fountain Beverage") == nil {
							food = processFoodPart(foodPart, descriptions)
						}
					} else if partClass.rangeOfString("price") != nil {
						price = foodPart.text!
					} else if partClass.rangeOfString("desc") != nil {
						description = foodPart.text!
						
						if let swipeRange = description.rangeOfString(" Meal Plan Swipe") {
							var numberRange = swipeRange
							numberRange.endIndex = swipeRange.startIndex
							numberRange.startIndex = swipeRange.startIndex.predecessor()
							
							let number = description.substringWithRange(numberRange)
							var ending = number == "1" ? "" : "s"
							subtitle = number + " Swipe" + ending
						}
					}
				}
				
				if food.recipe != "" {
					foods[food.recipe] = FoodCollection(info: food)
				}
				
				if subtitle != "" {
					currSectionFoods.append(FoodBrief(food: food, sideFood: FoodInfo(name: subtitle, recipe: "", type: .Regular)))
				} else {
					currSectionFoods.append(FoodBrief(food: food))
				}
			}
		}
		if currSectionFoods.count != 0 {
			var nextSection = SectionBrief(name: currSectionName)
			for food in currSectionFoods {
				nextSection.foods.append(food)
			}
			restBrief.sections.append(nextSection)
		}
	}
	
	
	var dayBrief = DayBrief()
	dayBrief.date = NSDate()
	dayBrief.foods = foods
	
	dayBrief.meals = [.LateNight : MealBrief(halls: [.DeNeve : restBrief])]
	return dayBrief
}

// MARK: URL generators

// used to have a forceTwoDigits attribute, but it isn't needed
func dateURL(date: NSDate) -> String {
	var formatter = NSDateFormatter()
	formatter.dateFormat = "M"
	var dateString = formatter.stringFromDate(date) + "%2F"
	formatter.dateFormat = "d"
	dateString = dateString + formatter.stringFromDate(date) + "%2F"
	formatter.dateFormat = "yyyy"
	dateString = dateString + formatter.stringFromDate(date)
	
	return dateString
}

func hoursURL(date: NSDate) -> String {
	var dateString = dateURL(date)
	return "http://secure5.ha.ucla.edu/restauranthours/dining-hall-hours-by-day.cfm?serviceDate=\(dateString)"
}

func hallURL(hall: Halls, meal: MealType, date: NSDate) -> String {
	var dateString = dateURL(date)
	return "http://menu.ha.ucla.edu/foodpro/default.asp?location=\(hall.urlCode()!)&date=\(dateString)&meal=\(meal.urlCode()!)"
}

func foodURL(recipe: String, portion: String) -> String {
	return "http://menu.ha.ucla.edu/foodpro/recipedetail.asp?RecipeNumber=\(recipe)&PortionSize=\(portion)"
}

// MARK: HTML loaders
private func mealsForDay(date: NSDate) -> Array<MealType> {
	let dow = NSCalendar.currentCalendar().component(.CalendarUnitWeekday, fromDate: date)
	return dow == 1 || dow == 7 ? [.Breakfast, .Brunch, .Dinner, .LateNight] : [.Breakfast, .Lunch, .Dinner, .LateNight]
}

func loadHours(date: NSDate) -> Dictionary<MealType, Dictionary<Halls, (open: Bool, openTime: Time?, closeTime: Time?)>> {
	var hours: Dictionary<MealType, Dictionary<Halls, (open: Bool, openTime: Time?, closeTime: Time?)>> = [:]
	let dayMeals = mealsForDay(date)
	for meal in dayMeals { hours[meal] = [:] }
	
	var htmlError: NSError? = nil
	if let hoursURL = NSURL(string: hoursURL(date)), html = NSString(contentsOfURL: hoursURL, encoding: NSASCIIStringEncoding, error: &htmlError) as? String, _ = html.rangeOfString("00am"), hourNodes = Hpple(HTMLData: html).searchWithXPathQuery("//table") {
		for node in Array(hourNodes[3...hourNodes.count-1]) {
			var subNodes = node.children!, subNodeIndex = subNodes.count - 1
			
			// TODO: find a good way to filter
//			subNodes.filter({ (element: HppleElement) -> Bool in
//				
//			})
			
			while subNodeIndex >= 0 {
				if subNodeIndex % 2 == 0 { subNodes.removeAtIndex(subNodeIndex) }
				subNodeIndex--
			}
			
			for body in Array(subNodes[2...subNodes.count-1]) {
				if var subBodies = body.children {
//					var subBodyIndex = subBodies.count - 1
					for var subBodyIndex = subBodies.count - 1; subBodyIndex >= 0; subBodyIndex-- {
						if subBodyIndex % 2 == 0 {
							subBodies.removeAtIndex(subBodyIndex)
						}
					}
					
					var hall: Halls?
					for (layerIndex, layer) in enumerate(subBodies) {
						if layerIndex == 0 {
							if let restaurantName = layer.children?[1].text?.stringByReplacingOccurrencesOfString("\r\n\t", withString: "").stringByTrimmingCharactersInSet(.whitespaceCharacterSet()).stringByReplacingOccurrencesOfString("Ã©", withString: "e"), newHall = Halls.hallForString(restaurantName) {
								hall = newHall
							} else {
								hall = nil
							}
						} else {
							var meal: MealType = dayMeals[layerIndex-1]
							var open = false, openTime: Time?, closeTime: Time?
							
							if let currHall = hall, openString = layer.children?[1].text?.stringByReplacingOccurrencesOfString("\r\n\t", withString: "").stringByTrimmingCharactersInSet(.whitespaceCharacterSet()).stringByReplacingOccurrencesOfString(" -", withString: "") where openString.rangeOfString("CLOSED") == nil {
								open = true
								openTime = Time(hoursString: openString)
								
								if let closeString = layer.children?[3].text?.stringByReplacingOccurrencesOfString("\r\n\t", withString: "").stringByTrimmingCharactersInSet(.whitespaceCharacterSet()) {
									closeTime = Time(hoursString: closeString)
								}
								
								if let mealHours = hours[meal] {
									if let hallMealHours = mealHours[currHall] where hallMealHours.openTime != nil { }
									else { // equilvalent to hours[meal][currHall] == nil || hours[meal][currHall].openTime == nil
										(hours[meal]!)[currHall] = (open, openTime, closeTime)
									}
								}
							}
						}
					}
				}
			}
		}
	}
	return hours
}

func loadMealBrief(hall: Halls, meal: MealType, date: NSDate) -> (open: Bool, info: RestaurantBrief, foods: Dictionary<String, FoodInfo>) {
	var restaurant = RestaurantBrief(hall: hall)
	var foods: Dictionary<String, FoodInfo> = [:]
	
	var url = NSURL(string: hallURL(hall, meal, date))!
	var htmlError: NSError? = nil
	var html: String
	var htmlData: NSData?
	if let htmlNS = NSString(contentsOfURL: url, encoding: NSASCIIStringEncoding, error: &htmlError) {
		if !htmlNS.containsString("menulocheader") {
			return (false, restaurant, [:])
		}
		
		html = htmlNS as String
		htmlData = htmlNS.dataUsingEncoding(NSASCIIStringEncoding)
	} else {
		println(htmlError)
		return (false, restaurant, [:])
	}
	
	var mealDescriptions = foodDescriptions(html)
	var foodNodes = Hpple(HTMLData: html).searchWithXPathQuery("//body/div/div[position()=3]/div/table/node()")!
	var sections: Array<Array<HppleElement>> = []
	var foodNodeCycle = Array(foodNodes[7..<foodNodes.count])
	for (index, element) in enumerate(foodNodeCycle) {
		if !element.isTextNode {
			var middleTwiceChildren = element.children?[1].children?[1].children
			var deslicer = Array((middleTwiceChildren?[1...((middleTwiceChildren?.count)!-2)])!)
			
			var index = deslicer.count-2
			while index > 0 {
				if index % 2 == 1 { deslicer.removeAtIndex(index) }
				index--
			}
			
			sections.append(deslicer)
		}
	}
	
	var processed: Array<Array<HppleElement>> = []
	for entry in sections {
		var section = SectionBrief(name: entry.first!.text!)
		for sectionFood in Array(entry[1..<entry.count]) {
			if (!sectionFood.isTextNode) {
				var relevant = (sectionFood.children?.first)!
				
				// catches w/ issues
				var isSubFood = false
				
				if let sectionFoodText = sectionFood.text {
					if sectionFoodText.rangeOfString("w/") != nil {
						isSubFood = true
						relevant = (sectionFood.children?[1])!
					}
				} else {
					if let sectionFoodText = relevant.text {
						if NSString(string: sectionFoodText).rangeOfString("w/").location == 0 {
							isSubFood = true
							relevant = (sectionFood.children?[1])!
						}
					}
				}
				
				if let raw = relevant.raw {
					var foodName = relevant.text
					foodName?.stringByReplacingOccurrencesOfString("&ntilde", withString: "ñ")
					
					var recipeRange = raw.rangeOfString("RecipeNumber=")
					// take the next six characters after the matched string
					var recipe = raw.substringWithRange(Range(start: (recipeRange?.endIndex)!, end: (recipeRange?.endIndex.successor().successor().successor().successor().successor().successor())!))
					
					var portionRange = raw.rangeOfString("PortionSize=")
					var portion = raw.substringWithRange(Range(start: (portionRange?.endIndex)!, end: (portionRange?.endIndex.successor().successor())!))
					let setToRemove = NSCharacterSet(charactersInString: "0123456789").invertedSet
					portion = "".join(portion.componentsSeparatedByCharactersInSet(setToRemove))
					
					var type:FoodType = .Regular
					if (sectionFood.raw)!.rangeOfString("VG.png") != nil { type = .Vegan }
					else if (sectionFood.raw)!.rangeOfString("V.png") != nil { type = .Vegetarian }
					
					if isSubFood {
						var withFood = FoodInfo(name: foodName!, recipe: recipe, type: type)
						(nutrition: withFood.nutrition, ingredients: withFood.ingredients) = loadNutrition(recipe, portion)
						
						if let description = mealDescriptions[recipe] {
							var breakRange = description.rangeOfString("<br/>")
							if breakRange != nil {
								withFood.countryCode = description.substringToIndex((breakRange?.startIndex)!)
								withFood.description = description.substringFromIndex((breakRange?.endIndex)!)
							} else {
								withFood.description = description
							}
						}
						
						foods[recipe] = withFood
						var lastBrief = section.foods.removeLast()
						lastBrief.sideBrief = FoodBrief(food: withFood)
						section.foods.append(lastBrief)
					} else {
						var food = FoodInfo(name: foodName ?? "[No Name]", recipe: recipe, type: type)
						(nutrition: food.nutrition, ingredients: food.ingredients) = loadNutrition(recipe, portion)
						
						if let description = mealDescriptions[recipe] {
							var breakRange = description.rangeOfString("<br/>")
							if breakRange != nil {
								food.countryCode = description.substringToIndex((breakRange?.startIndex)!)
								food.description = description.substringFromIndex((breakRange?.endIndex)!)
							} else {
								food.description = description
							}
						}
						
						foods[recipe] = food
						section.foods.append(FoodBrief(food: food))
					}
				}
			}
		}
		restaurant.sections.append(section)
	}
	
	// sort it into display order!

	restaurant.sections.sort { (lhs, rhs) -> Bool in
		var lhsType = HallSectionType.typeFromString(lhs.name)
		var rhsType = HallSectionType.typeFromString(rhs.name)
		
		return lhsType <= rhsType
	}
	
	return (true, restaurant, foods)
}

// trying to make a helper to prevent repeating code between bcafe and dining halls
func processFoodPart(element: HppleElement, descriptions: Dictionary<String, String>) -> FoodInfo {
	let raw = element.raw!
	var foodName = element.children![0].text
	foodName?.stringByReplacingOccurrencesOfString("&ntilde", withString: "ñ")
	
	var recipeRange = raw.rangeOfString("RecipeNumber=")
	// take the next six characters after the matched string
	var recipe = raw.substringWithRange(Range(start: (recipeRange?.endIndex)!, end: (recipeRange?.endIndex.successor().successor().successor().successor().successor().successor())!))
	
	var portionRange = raw.rangeOfString("PortionSize=")
	var portion = raw.substringWithRange(Range(start: (portionRange?.endIndex)!, end: (portionRange?.endIndex.successor().successor())!))
	let setToRemove = NSCharacterSet(charactersInString: "0123456789").invertedSet
	portion = "".join(portion.componentsSeparatedByCharactersInSet(setToRemove))
	
	var type:FoodType = raw.rangeOfString("VG.png") != nil ? .Vegan : .Regular
	if raw.rangeOfString("V.png") != nil { type = .Vegetarian }
	
	var food = FoodInfo(name: foodName!, recipe: recipe, type: type)
	
	(nutrition: food.nutrition, ingredients: food.ingredients) = loadNutrition(recipe, portion)
	if let description = descriptions[recipe] {
		var breakRange = description.rangeOfString("<br/>")
		if breakRange != nil {
			food.countryCode = description.substringToIndex((breakRange?.startIndex)!)
			food.description = description.substringFromIndex((breakRange?.endIndex)!)
		} else {
			food.description = description
		}
	}
	return food
}

func loadNutrition(recipe: String, portion: String) -> (nutrition: Dictionary<Nutrient, NutritionListing>, ingredients: String) {
	var url = foodURL(recipe, portion)
	var htmlError: NSError? = nil
	
	for i in 0...1 {
		if let html: String = NSString(contentsOfURL: NSURL(string: url)!, encoding: NSASCIIStringEncoding, error: &htmlError)?.stringByAppendingString("") {
			if html.rangeOfString("Nutrition") == nil { // fail case
				return (nutrition: [:], ingredients: "")
			}
			
			var parser = Hpple(HTMLData: html)
			return (nutrition: loadNutritionFacts(parser), ingredients: loadIngredients(parser))
		} else {
			println("Attempt \(i) failed: \(htmlError)")
		}
	}
	abort()
	
//	var html = NSString(contentsOfURL: NSURL(string: url)!, encoding: NSASCIIStringEncoding, error: &htmlError) as! String
//	if html.rangeOfString("Nutrition") == nil { // fail case
//		return (nutrition: [:], ingredients: "")
//	}
//	
//	var parser = Hpple(HTMLData: html)
//	return (nutrition: loadNutritionFacts(parser), ingredients: loadIngredients(parser))
}

// MARK: Helpers

/// Returns dictionary that maps from recipe numbers to descriptions.
/// Recipes without a description will not have a key in the dictionary
func foodDescriptions(html: String) -> Dictionary<String, String> {
	var javaRange = html.rangeOfString("<script language=\"javascript\">")
	var descriptionArea = html.substringFromIndex((javaRange?.endIndex)!)
	javaRange = descriptionArea.rangeOfString("</script>")
	descriptionArea = descriptionArea.substringToIndex((javaRange?.startIndex)!)
	descriptionArea = descriptionArea.stringByReplacingOccurrencesOfString("\t", withString: "")
	
	var recipeDescriptions: Dictionary<String, String> = Dictionary()
	for line in descriptionArea.componentsSeparatedByCharactersInSet(.newlineCharacterSet()) {
		if count(line) > 0 {
			var info = line.rangeOfString("recipeInfo[\"")
			var recipe = line.substringFromIndex((info?.endIndex)!)
			info = recipe.rangeOfString("\"] = ")
			var popover = recipe.substringFromIndex((info?.endIndex)!)
			popover = popover.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\""))
			popover = popover.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\";"))
			popover = popover.stringByReplacingOccurrencesOfString("\\\"", withString: "\"")
			popover = popover.stringByReplacingOccurrencesOfString("\\n", withString: "\n")
			recipe = recipe.substringToIndex((info?.startIndex)!)
			
			// parse popovers
			if let items = (Hpple(HTMLData: popover).searchWithXPathQuery("//*")) {
				for item in items {
					var raw = item.children?.first?.children?.first?.raw
					if raw == nil || raw?.rangeOfString("<p>") == nil { continue }
					
					// clean up, add in
					var description = raw!.stringByReplacingOccurrencesOfString("<p>", withString: "")
					description = description.stringByReplacingOccurrencesOfString("</p>", withString: "")
					description = description.stringByReplacingOccurrencesOfString("<br/>", withString: " ")
					description = description.stringByReplacingOccurrencesOfString("\n", withString: "")
					description = description.stringByReplacingOccurrencesOfString("&amp;ntilde", withString: "ñ")
					description = description.stringByReplacingOccurrencesOfString("&amp;", withString: "&")
					description = description.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "() "))
					if (count(description) > 1) { recipeDescriptions[recipe] = description }
				}
			}
		}
	}
	
	return recipeDescriptions
}

func loadNutritionFacts(parser: Hpple) -> Dictionary<Nutrient, NutritionListing> {
	var nutrients: Dictionary<Nutrient, NutritionListing> = [:]
	var index = -1
	for node in (parser.searchWithXPathQuery("//div[@class='left_lightbox']")?.first?.children![1].children)! {
		index++
		if index > 6 && index < 28 && !node.isTextNode {
			// parse it out
			var cleanNode = (node.text)!.stringByTrimmingCharactersInSet(.whitespaceCharacterSet())
			if node.children?.count == 5 {
				switch index {
				case 13, 21: // Top level
					var first = (node.children?[1].text)!.stringByTrimmingCharactersInSet(.whitespaceCharacterSet())
					var second = (node.children?[3].text)!.stringByTrimmingCharactersInSet(.whitespaceCharacterSet())
					cleanNode = "\(first)\n\(second)"
				default: // Vitamins and Minerals (consider adding back .stringByTrimmingCharactersInSet(.whitespaceCharacterSet()))
					var oneA = (node.children?[1].children?[0].text)!
					var oneB = (node.children?[1].children?[2].text)!
					var twoA = (node.children?[3].children?[0].text)!
					var twoB = (node.children?[3].children?[2].text)!
					
					cleanNode = "\(oneA) \(oneB)\n\(twoA) \(twoB)"
				}
			}
			if node.children?.count == 3 {
				switch index {
				case 7:
					cleanNode = "\((node.children?[0].text)!) \(cleanNode)\n\((node.children?[2].text)!)"
				default:
					cleanNode = "\((node.children?[0].text)!) \(cleanNode)"
				}
			}
			if node.children?.count == 2 {
				cleanNode = "\((node.children?[0].text)!) \(cleanNode)"
			}
			
			for line in cleanNode.componentsSeparatedByCharactersInSet(.newlineCharacterSet()) {
				if count(line) > 0 {
					var typeOpt = Nutrient.typeForName(line)
					if typeOpt == nil { continue }
					var type = typeOpt!
					
					// remove name of entry from string
					var nutrIndex = (find(Nutrient.allValues, type))!
					var displayName = Nutrient.allMatchingValues[nutrIndex]
					
					var displayNameRange = (line.rangeOfString(displayName))!
					var measure = line.substringFromIndex(displayNameRange.endIndex.successor()) // skip the inevitable space
					measure = measure.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
					
					// go either until the next space or the end of the string
					// check if there's one more space
					if let nextSpace = measure.rangeOfString(" ") {
						measure = measure.substringToIndex(nextSpace.startIndex)
					}
					
					// remove all non-numbers (and percent)
					measure = measure.stringByReplacingOccurrencesOfString(type.unit(), withString: "")
					nutrients[type] = NutritionListing(type: type, measure: measure)
				}
			}
		}
	}
	return nutrients
}

func loadIngredients(parser: Hpple) -> String {
	return (parser.searchWithXPathQuery("//p[@class='rdingred_list']")?.first?.text)! // was .content
}