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
			
			return children[String(path[path.startIndex ..< ofs])]?.find(path:String(path[ofs1..<path.endIndex]))
		}
	}
	
	private var root: Element?
	
	init() throws {
		//root = Element(children: [:], name: "", value: "")
	}
	
	//    public subscript(index: Data.Index) -> UInt8
	subscript(index: String) -> String? {
		guard let root = root else {
			return nil
		}
		return root.find(path: index)
	}
	
	private func parse(fileAt: URL) throws {
		let wholeString = try String(contentsOf: fileAt)
		var lines = wholeString.components(separatedBy: CharacterSet.newlines)
		root = Element(lines: &lines)
	}
}

/*
SteamConfig::SteamConfig() {
root = NULL;
QSettings settings("HKEY_CURRENT_USER\\Software\\Valve\\Steam",
QSettings::NativeFormat);
QString path = settings.value("SteamPath").toString();
if (path.isEmpty()) {
path =  QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)
.first();
path += QDir::toNativeSeparators("/Steam");
}
path += QDir::toNativeSeparators("/config/config.vdf");
QFile file(path);
if (file.exists())
parse(path);
}
*/

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
		if i.count > 2 {
			aRange = i[1].range(at: 1)
			let stringRange = Range(aRange, in: line)!
			value = line[stringRange].replacingOccurrences(of: "\\\\", with: "\\")
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
				if let e = SteamConfig.Element(lines: &lines) {
					children[e.name] = e
				}
			}
		}
	}
}
