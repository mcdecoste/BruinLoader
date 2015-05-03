//
//  XPathQuery.swift
//  BruinBackendGUI
//
//  Created by Nicolai on 24/06/14.
//	Modified by Matthew on 12/27/14.
//
//  Copyright (c) 2014 Matthew DeCoste. All rights reserved.
//

import Foundation

func createNode(currentNode: xmlNodePtr, inout parentDictionary: Dictionary<String, AnyObject>, parentContent: Bool) -> Dictionary<String, AnyObject>? {
    var resultForNode = Dictionary<String, AnyObject>(minimumCapacity: 8)
    
    if currentNode.memory.name != nil {
        let name = String.fromCString(UnsafePointer<CChar>(currentNode.memory.name))
        resultForNode.updateValue(name!, forKey: HppleNodeKey.Name.rawValue)
    }
    
    if currentNode.memory.content != nil {
        let content = String.fromCString(UnsafePointer<CChar>(currentNode.memory.content))
        if resultForNode[HppleNodeKey.Name.rawValue] as AnyObject? as? String == "text" {
            
            if parentContent {
                parentDictionary.updateValue(content!, forKey: HppleNodeKey.Content.rawValue)
                return nil
            }
            
            resultForNode.updateValue(content!, forKey: HppleNodeKey.Content.rawValue)
            return resultForNode
        } else {
            resultForNode.updateValue(content!, forKey: HppleNodeKey.Content.rawValue)
        }
    }
    
    var attribute = currentNode.memory.properties
    if attribute != nil {
        var attributeArray = Array<Dictionary<String, AnyObject>>()
        while attribute != nil {
            var attributeDictionary = Dictionary<String, AnyObject>()
            let attributeName = attribute.memory.name
            if attributeName != nil {
                attributeDictionary.updateValue(String.fromCString(UnsafePointer<CChar>(attributeName))!, forKey: HppleNodeKey.AttributeName.rawValue)
            }
            
            if attribute.memory.children != nil {
                if let childDictionary = createNode(attribute.memory.children, &attributeDictionary, true) {
                    attributeDictionary.updateValue(childDictionary, forKey: HppleNodeKey.AttributeContent.rawValue)
                }
            }
            
            if attributeDictionary.count > 0 {
                attributeArray.append(attributeDictionary)
            }
            attribute = attribute.memory.next
        }
        if attributeArray.count > 0 {
            resultForNode.updateValue(attributeArray, forKey: HppleNodeKey.AttributeArray.rawValue)
        }
    }
    
    var childNode = currentNode.memory.children
    if childNode != nil {
        var childContentArray = Array<Dictionary<String, AnyObject>>()
        while childNode != nil {
            if let childDictionary = createNode(childNode, &resultForNode, false) {
                childContentArray.append(childDictionary)
            }
            childNode = childNode.memory.next
        }
        if childContentArray.count > 0 {
            resultForNode.updateValue(childContentArray, forKey: HppleNodeKey.Children.rawValue)
        }
    }
    
    let buffer = xmlBufferCreate()
    xmlNodeDump(buffer, currentNode.memory.doc, currentNode, 0, 0)
    resultForNode.updateValue(String.fromCString(UnsafePointer<CChar>(buffer.memory.content))!, forKey: "raw")
    xmlBufferFree(buffer)
    
    return resultForNode
}

func PerformXPathQuery(data: NSString, query: String, isXML: Bool) -> Array<Dictionary<String, AnyObject>>? {
    let bytes = data.cStringUsingEncoding(NSUTF8StringEncoding)
    let length = CInt(data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
    let url = ""
    let encoding = CFStringGetCStringPtr(nil, 0)
    let options: CInt = isXML ? 1 : ((1 << 5) | (1 << 6))
	
	var result: Array<Dictionary<String, AnyObject>>?
    
    var function = isXML ? xmlReadMemory : htmlReadMemory
    let doc = function(bytes, length, url, encoding, options)

    if doc != nil {
        let xPathCtx = xmlXPathNewContext(doc)
        if xPathCtx != nil {
            var queryBytes = query.cStringUsingEncoding(NSUTF8StringEncoding)!
            let ptr = UnsafePointer<CChar>(queryBytes)
            let xPathObj = xmlXPathEvalExpression(UnsafePointer<CUnsignedChar>(ptr), xPathCtx)
            if xPathObj != nil {
                let nodes = xPathObj.memory.nodesetval
                if nodes != nil {
                    var resultNodes = Array<Dictionary<String, AnyObject>>()
                    let nodesArray = UnsafeBufferPointer(start: nodes.memory.nodeTab, count: Int(nodes.memory.nodeNr))
                    var dummy = Dictionary<String, AnyObject>()
                    for rawNode in nodesArray {
                        if let node = createNode(rawNode, &dummy, false) {
                            resultNodes.append(node)
                        }
                    }
                    result = resultNodes
                }
                xmlXPathFreeObject(xPathObj)
            }
            xmlXPathFreeContext(xPathCtx)
        }
        xmlFreeDoc(doc)
    }
    return result
}

func PerformXMLXPathQuery(data: String, query: String) -> Array<Dictionary<String, AnyObject>>? {
    return PerformXPathQuery(data, query, true)
}

func PerformHTMLXPathQuery(data: String, query: String) -> Array<Dictionary<String, AnyObject>>? {
    return PerformXPathQuery(data, query, false)
}