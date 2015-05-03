//
//  Hpple.swift
//  BruinBackendGUI
//
//  Created by Nicolai on 24/06/14 as NDHpple.swift.
//  Modified by Matthew on 12/27/14 to be Hpple.swift.
//
//  Copyright (c) 2014 Matthew DeCoste. All rights reserved.
//

import Foundation

class Hpple {
    var data: String
    var isXML: Bool
    
    init(data: String, isXML: Bool) {
        self.data = data
        self.isXML = isXML
    }
    
    convenience init(XMLData: String) {
        self.init(data: XMLData, isXML: true)
    }
    
    convenience init(HTMLData: String) {
        self.init(data: HTMLData, isXML: false)
    }
    
    func searchWithXPathQuery(xPathOrCSS: String) -> Array<HppleElement>? {
        let nodes = isXML ? PerformXMLXPathQuery(data, xPathOrCSS) : PerformHTMLXPathQuery(data, xPathOrCSS)
        return nodes?.map{ HppleElement(node: $0) }
    }
    
    func peekAtSearchWithXPathQuery(xPathOrCSS: String) -> HppleElement? {
        return searchWithXPathQuery(xPathOrCSS)?[0]
    }
}