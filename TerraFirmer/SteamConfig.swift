//
//  SteamConfig.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/21/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation

class SteamConfig {
	fileprivate struct Element {
		var children: [String: Element]
		var name: String
		var value: String
		
		func find(path: String) -> String? {
			guard let ofs = path.index(of: "/") else {
				return children[path]?.value
			}
			let ofs1 = path.index(after: ofs)
			
			return children[String(path[path.startIndex ..< ofs])]?.find(path:String(path[ofs1 ..< path.endIndex]))
		}
	}
	
	private var root: Element?
	
	init() throws {
		var urlPath = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
		urlPath.appendPathComponent("Steam")
		urlPath.appendPathComponent("config")
		urlPath.appendPathComponent("config.vdf")
		guard try urlPath.checkResourceIsReachable() else {
			throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [NSURLErrorKey: urlPath])
		}
		try parse(fileAt: urlPath)
	}
	
	subscript(index: String) -> String? {
		guard let root = root else {
			return nil
		}
		return root.find(path: index)
	}
	
	private func parse(fileAt: URL) throws {
		let wholeString = try String(contentsOf: fileAt)
		var lines = wholeString.components(separatedBy: CharacterSet.newlines)
		guard let aRoot = Element(lines: &lines) else {
			throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
		}
		root = aRoot
	}
}

extension SteamConfig.Element {
	fileprivate init?(lines: inout [String]) {
		children = [:]
		value = ""
		name = ""
		var line = ""
		let re = try! NSRegularExpression(pattern: "\"([^\"]*)\"", options: [.useUnicodeWordBoundaries])
		var i = [NSTextCheckingResult]()
		while lines.count > 0 {
			line = lines.removeFirst()
			let range = NSRange(line.startIndex ..< line.endIndex, in: line)
			i = re.matches(in: line, range: range)
			if i.count > 0 {
				break
			}
		}
		guard lines.count != 0, i.count > 0 else {
			// corrupt
			return nil
		}
		let match = i[0]
		var aRange = match.range(at: 1)
		name = line[Range(aRange, in: line)!].lowercased()
		if i.count >= 2 {
			aRange = i[1].range(at: 1)
			let stringRange = Range(aRange, in: line)!
			let subStr = line[stringRange]
			value = subStr.replacingOccurrences(of: "\\\\", with: "\\")
		}
		line = lines[0]
		if line.contains("{") {
			lines.removeFirst()
			while true {
				line = lines[0]
				if line.contains("}") { // empty
					lines.removeFirst()
					return
				}
				guard let e = SteamConfig.Element(lines: &lines) else {
					return nil
				}
				children[e.name] = e
			}
		}
	}
}
