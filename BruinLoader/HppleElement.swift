//
//  HppleElement.swift
//  BruinBackendGUI
//
//  Created by Nicolai on 24/06/14 as NDHppleElement.swift.
//  Modified by Matthew on 12/27/14 to be HppleElement.swift.
//	
//  Copyright (c) 2014 Matthew DeCoste. All rights reserved.
//

import Foundation

enum HppleNodeKey: String {
    case Content = "nodeContent"
    case Name = "nodeName"
    case Children = "nodeChildArray"
    case AttributeArray = "nodeAttributeArray"
    case AttributeContent = "attributeContent"
    case AttributeName = "attributeName"
}

class HppleElement {
    typealias Node = Dictionary<String, AnyObject>
    var node: Node
    weak var parent: HppleElement?
    
    convenience init(node: Node) {
        self.init(node: node, parent: nil)
    }
    
    init(node: Node, parent: HppleElement?) {
        self.node = node
        self.parent = parent
    }

    subscript(key: String) -> AnyObject? {
        return self.node[key]
    }

    var description: String { return self.node.description }
    var hasChildren: Bool { return self[HppleNodeKey.Children.rawValue] as? Int != nil }
    var isTextNode: Bool { return self.tagName == "text" && self.content != nil }
    var raw: String? { return self["raw"] as? String }
    var content: String? { return self[HppleNodeKey.Content.rawValue] as? String }
    var tagName: String? { return self[HppleNodeKey.Name.rawValue] as? String }
	var firstChild: HppleElement? { return self.children?.first }
	var children: Array<HppleElement>? {
    
        let children = self[HppleNodeKey.Children.rawValue] as? Array<Dictionary<String, AnyObject>>
        return children?.map{ HppleElement(node: $0, parent: self) }
    }
	
    func childrenWithTagName(tagName: String) -> Array<HppleElement>? { return self.children?.filter{ $0.tagName == tagName } }
    func firstChildWithTagName(tagName: String) -> HppleElement? {
		if let children = self.childrenWithTagName(tagName) {
			return children.first
		}
		return nil
	}
    func childrenWithClassName(className: String) -> Array<HppleElement>? { return self.children?.filter{ $0["class"] as? String == className } }
    func firstChildWithClassName(className: String) -> HppleElement? { return self.childrenWithClassName(className)?[0] }
    
    var firstTextChild: HppleElement? { return self.firstChildWithTagName("text") }
    var text: String? { return self.firstTextChild?.content }
    
    var attributes: Dictionary<String, AnyObject> {
        var translatedAttribtues = Dictionary<String, AnyObject>()
		
		if let allAttrs = self[HppleNodeKey.AttributeArray.rawValue] as? Array<Dictionary<String, AnyObject>> {
			for attributeDict in allAttrs {
				if let value = attributeDict[HppleNodeKey.Content.rawValue] as? String {
					if let key = attributeDict[HppleNodeKey.AttributeName.rawValue] as? String {
						translatedAttribtues.updateValue(value, forKey: key)
					}
				}
			}
		}
            
        return translatedAttribtues
    }
}