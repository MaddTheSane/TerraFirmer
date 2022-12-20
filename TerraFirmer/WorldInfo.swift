//
//  WorldInfo.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/17/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Cocoa

private struct IDName: Decodable {
	var identifier: UInt16
	var name: String
	
	enum CodingKeys: String, CodingKey {
		case name
		case identifier = "id"
	}

	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		name = try values.decode(String.self, forKey: .name)
		let ident = try values.decode(Int32.self, forKey: .identifier)
		if ident < 0 {
			let ident2 = Int16(ident)
			identifier = UInt16(bitPattern: ident2)
		} else {
			identifier = UInt16(ident)
		}
	}
}

private struct GlobalStruct: Decodable {
	enum CodingKeys: String, CodingKey {
		case color
		case identifier = "id"
	}
	var identifier: String
	var color: String
}

private func loadDictionary(from: URL, using decode: JSONDecoder) throws -> [UInt16: String] {
	let data = try Data(contentsOf: from)
	var toRet = [UInt16: String]()
	let decoded = try decode.decode([IDName].self, from: data)
	for both in decoded {
		toRet[both.identifier] = both.name
	}
	
	if toRet.count != decoded.count {
		print("toRet count \(toRet.count) != decoded count \(decoded.count)! from \(from)")
	}
	return toRet
}

let asciiSet: CharacterSet = {
	let space = UnicodeScalar(UInt8(0x20))
	let lastValidASCII = UnicodeScalar(UInt8(0x7F))
	let aSet = CharacterSet(charactersIn: space ... lastValidASCII)
	return aSet
}()

let asciiLowercase: CharacterSet = {
	return CharacterSet.lowercaseLetters.intersection(asciiSet)
}()

let asciiDecimal: CharacterSet = {
	return CharacterSet.decimalDigits.intersection(asciiSet)
}()

class WorldInfo {
	static let shared = WorldInfo()
	
	enum WorldErrors: Error {
		case unknownType(Character)
		case unknownGroup(String)
	}
	
	private init() {
		let decoder = JSONDecoder()
		
		var jsonURL = Bundle.main.url(forResource: "items", withExtension: "json")!
		items = try! loadDictionary(from: jsonURL, using: decoder)

		jsonURL = Bundle.main.url(forResource: "prefixes", withExtension: "json")!
		prefixes = try! loadDictionary(from: jsonURL, using: decoder)
		
		jsonURL = Bundle.main.url(forResource: "walls", withExtension: "json")!
		var data = try! Data(contentsOf: jsonURL)
		walls = try! decoder.decode([WallInfo].self, from: data)
		
		jsonURL = Bundle.main.url(forResource: "tiles", withExtension: "json")!
		data = try! Data(contentsOf: jsonURL)
		#if DEBUG
		do {
			tiles = try decoder.decode([TileInfo].self, from: data)
		} catch {
			print("\(error) + \(error.localizedDescription)")
			fatalError()
		}
		#else
		tiles = try! decoder.decode([TileInfo].self, from: data)
		#endif
		
		jsonURL = Bundle.main.url(forResource: "npcs", withExtension: "json")!
		data = try! Data(contentsOf: jsonURL)
		npcs = try! decoder.decode([NPC].self, from: data)
		
		do {
			var npcsByID = [Int16: NPC]()
			var npcBanner = [Int32: NPC]()
			var npcName = [String: NPC]()
			for npc in npcs {
				npcsByID[npc.identifier] = npc
				if let banner = npc.banner {
					npcBanner[banner] = npc
				} else {
					npcName[npc.title] = npc
				}
			}
			
			npcsByIdentifier = npcsByID
			npcsByBanner = npcBanner
			npcsByName = npcName
		}
		
		// Convoluted mess begin
		jsonURL = Bundle.main.url(forResource: "globals", withExtension: "json")!
		data = try! Data(contentsOf: jsonURL)
		
		var bDict = [String: String]()
		
		do {
			let globals = try! decoder.decode([GlobalStruct].self, from: data)
			for aDict in globals {
				bDict[aDict.identifier] = aDict.color
			}
		}
		
		if let skyVal = bDict["sky"],
			let skyCol = DTColorCreateWithHTMLName(skyVal) {
			skyColor = skyCol
		} else {
			skyColor = .clear
		}
		
		if let skyVal = bDict["earth"],
			let skyCol = DTColorCreateWithHTMLName(skyVal) {
			earthColor = skyCol
		} else {
			earthColor = .clear
		}
		
		if let skyVal = bDict["rock"],
			let skyCol = DTColorCreateWithHTMLName(skyVal) {
			rockColor = skyCol
		} else {
			rockColor = .clear
		}

		if let skyVal = bDict["hell"],
			let skyCol = DTColorCreateWithHTMLName(skyVal) {
			hellColor = skyCol
		} else {
			hellColor = .clear
		}

		if let skyVal = bDict["water"],
			let skyCol = DTColorCreateWithHTMLName(skyVal) {
			waterColor = skyCol
		} else {
			waterColor = .clear
		}

		if let skyVal = bDict["lava"],
			let skyCol = DTColorCreateWithHTMLName(skyVal) {
			lavaColor = skyCol
		} else {
			lavaColor = .clear
		}

		if let skyVal = bDict["honey"],
			let skyCol = DTColorCreateWithHTMLName(skyVal) {
			honeyColor = skyCol
		} else {
			honeyColor = .clear
		}
		// Convoluted mess end
	}
	
	struct WallInfo: Decodable {
		enum CodingKeys: String, CodingKey {
			case name
			case identifier = "id"
			case color
			case blend
			case large
		}

		var name: String
		var identifier: Int
		var color: NSColor
		var blend: UInt16
		var large: UInt8
		
		init(from decoder: Decoder) throws {
			let values = try decoder.container(keyedBy: CodingKeys.self)
			name = try values.decode(String.self, forKey: .name)
			if let colorStr = try values.decodeIfPresent(String.self, forKey: .color) {
				color = DTColorCreateWithHTMLName(colorStr) ?? .clear
			} else {
				color = .clear
			}
			identifier = try values.decode(Int.self, forKey: .identifier)
			blend = try values.decodeIfPresent(UInt16.self, forKey: .blend) ?? 0
			large = try values.decodeIfPresent(UInt8.self, forKey: .large) ?? 0
		}
	}
	
	class TileInfo: Decodable {
		struct TileFlag: OptionSet, Codable {
			var rawValue: UInt32
			
			static var solid: TileFlag {
				return TileFlag(rawValue: 1 << 0)
			}
			static var transparent: TileFlag {
				return TileFlag(rawValue: 1 << 1)
			}
			static var dirt: TileFlag {
				return TileFlag(rawValue: 1 << 2)
			}
			static var stone: TileFlag {
				return TileFlag(rawValue: 1 << 3)
			}
			static var grass: TileFlag {
				return TileFlag(rawValue: 1 << 4)
			}
			static var pile: TileFlag {
				return TileFlag(rawValue: 1 << 5)
			}
			static var flip: TileFlag {
				return TileFlag(rawValue: 1 << 6)
			}
			static var brick: TileFlag {
				return TileFlag(rawValue: 1 << 7)
			}
			static var moss: TileFlag {
				return TileFlag(rawValue: 1 << 8)
			}
			static var merge: TileFlag {
				return TileFlag(rawValue: 1 << 9)
			}
			static var large: TileFlag {
				return TileFlag(rawValue: 1 << 10)
			}
		}
		
		struct MergeBlend {
			var hasTile: Bool
			var tile: Int16
			var mask: TileFlag = []
			var blend: Bool
			var recursive: Bool
			var direction: UInt8 = 0
			
			private static func mergeBlends(from string: String, areBlends: Bool) throws -> [MergeBlend] {
				var toRet = [MergeBlend]()
				var curIdx = string.startIndex
				let lastIdx = string.index(before: string.endIndex)
				while curIdx <= lastIdx {
					var group = ""
					var mb = MergeBlend(hasTile: false, tile: 0, mask: TileFlag(), blend: areBlends, recursive: false, direction: 0)
					var i = curIdx
					while i <= lastIdx {
						let c = string[i]
						string.formIndex(after: &i)
						if c == "," {
							break
						}
						if c == "*" {
							mb.recursive = true
						} else if c == "v" {
							mb.direction |= 4
						} else if c == "^" {
							mb.direction |= 8
						} else if c == "+" {
							mb.direction |= 8 + 4 + 2 + 1
						} else if asciiDecimal.contains(c.unicodeScalars.first!) {
							mb.hasTile = true
							mb.tile *= 10
							mb.tile += Int16(String(c))!
						} else if asciiLowercase.contains(c.unicodeScalars.first!) {
							group += String(c)
						} else {
							throw WorldErrors.unknownType(c)
						}
					}
					if mb.direction == 0 {
						mb.direction = 0xff
					}
					if !mb.hasTile {
						switch group {
						case "solid":
							mb.mask.insert(.solid)

						case "dirt":
							mb.mask.insert(.dirt)

						case "brick":
							mb.mask.insert(.brick)

						case "moss":
							mb.mask.insert(.moss)
							
						default:
							throw WorldErrors.unknownGroup(group)
						}
					}
					
					toRet.append(mb)
					curIdx = i
				}
				
				return toRet
			}
			
			static func merges(from string: String) throws -> [MergeBlend] {
				return try mergeBlends(from: string, areBlends: false)
			}
			
			static func blends(from string: String) throws -> [MergeBlend] {
				return try mergeBlends(from: string, areBlends: true)
			}
			
			static func blend(from integer: Int16) -> MergeBlend {
				return MergeBlend(hasTile: true, tile: integer, blend: true, recursive: false)
			}

		}
		
		private struct TempTileInfo: Decodable {
			enum CodingKeys: String, CodingKey {
				case name
				case color
				case lightR = "r"
				case lightG = "g"
				case lightB = "b"
				case skipY = "skipy"
				case topPad = "toppad"
				case variants = "var"
				case x
				case y
				case minX = "minx"
				case maxX = "maxx"
				case minY = "miny"
				case maxY = "maxy"
				case reference = "ref"
			}
			
			var name: String?
			var color: String?
			var lightR: Double?
			var lightG: Double?
			var lightB: Double?
			var skipY: Int32?
			var topPad: Int32?
			var x: Int32?
			var y: Int32?
			var minX: Int32?
			var maxX: Int32?
			var minY: Int32?
			var maxY: Int32?
			var variants: [TempTileInfo]?
			var reference: Int32?
		}

		enum CodingKeys: String, CodingKey {
			case name
			case color
			case identifier = "id"
			case lightR = "r"
			case lightG = "g"
			case lightB = "b"
			case mask = "flags"
			case blend
			case merge
			case width = "w"
			case height = "h"
			case skipY = "skipy"
			case topPad = "toppad"
			case variants = "var"
			case reference = "ref"
		}

		let name: String
		let identifier: Int32
		let color: NSColor
		let light: (r: Double, g: Double, b: Double)
		let mask: TileFlag
		private(set) var blends = [MergeBlend]()
		let width: Int32
		let height: Int32
		let skipY: Int32
		let topPad: Int32
		let u: Int32
		let v: Int32
		let minU: Int32
		let maxU: Int32
		let minV: Int32
		let maxV: Int32
		var isHilighting: Bool = false
		private(set) var variants = [TileInfo]()
		let reference: Int32
		
		required init(from decoder: Decoder) throws {
			let values = try decoder.container(keyedBy: CodingKeys.self)
			name = try values.decode(String.self, forKey: .name)
			identifier = try values.decode(Int32.self, forKey: .identifier)
			if let colorStr = try values.decodeIfPresent(String.self, forKey: .color) {
				color = DTColorCreateWithHTMLName(colorStr) ?? .clear
			} else {
				color = .clear
			}
			let r = try values.decodeIfPresent(Double.self, forKey: .lightR) ?? 0
			let g = try values.decodeIfPresent(Double.self, forKey: .lightG) ?? 0
			let b = try values.decodeIfPresent(Double.self, forKey: .lightB) ?? 0
			light = (r, g, b)
			mask = try values.decodeIfPresent(TileFlag.self, forKey: .mask) ?? []
			width = try values.decodeIfPresent(Int32.self, forKey: .width) ?? 18
			height = try values.decodeIfPresent(Int32.self, forKey: .height) ?? 18
			skipY = try values.decodeIfPresent(Int32.self, forKey: .skipY) ?? 0
			topPad = try values.decodeIfPresent(Int32.self, forKey: .topPad) ?? 0
			if values.contains(.blend), !(try values.decodeNil(forKey: .blend)) {
				do {
					let blends = try values.decode(String.self, forKey: .blend)
					self.blends.append(contentsOf: try MergeBlend.blends(from: blends))
				} catch DecodingError.typeMismatch(_, _) {
					let aBlend = try values.decode(Int16.self, forKey: .blend)
					self.blends.append(MergeBlend.blend(from: aBlend))
					//print("ugh, \(error)")
				}
			}
			if values.contains(.merge),
			   !(try values.decodeNil(forKey: .merge)),
			   let blends = try values.decodeIfPresent(String.self, forKey: .merge) {
				self.blends.append(contentsOf: try MergeBlend.merges(from: blends))
			}
			u = 0
			v = 0
			minU = 0
			maxU = 0
			minV = 0
			maxV = 0
			reference = try values.decodeIfPresent(Int32.self, forKey: .reference) ?? 0
			if let temps = try values.decodeIfPresent([TempTileInfo].self, forKey: .variants) {
				variants = temps.map({TileInfo(using: $0, parent: self)})
			}
		}
		
		private init(using temp: TempTileInfo, parent: TileInfo) {
			name = temp.name ?? parent.name
			if let colorStr = temp.color {
				color = DTColorCreateWithHTMLName(colorStr) ?? parent.color
			} else {
				color = parent.color
			}
			width = parent.width
			height = parent.height
			skipY = parent.skipY
			identifier = parent.identifier
			topPad = temp.topPad ?? parent.topPad
			light = (temp.lightR ?? parent.light.r, temp.lightG ?? parent.light.g, temp.lightB ?? parent.light.b)
			mask = parent.mask
			blends = []
			u = (temp.x ?? -1) * width
			v = (temp.y ?? -1) * (height + skipY)
			minU = (temp.minX ?? -1) * width;
			maxU = (temp.maxX ?? -1) * width
			minV = (temp.minY ?? -1) * (height + skipY);
			maxV = (temp.maxY ?? -1) * (height + skipY);
			reference = temp.reference ?? 0
			if let otherTemps = temp.variants {
				variants = otherTemps.map({TileInfo(using: $0, parent: self)})
			}
		}
	}
	
	final class NPC: Codable {
		enum CodingKeys: String, CodingKey {
			case title = "name"
			case head
			case identifier = "id"
			case banner
		}
		
		let title: String
		let head: UInt16?
		let identifier: Int16
		let banner: Int32?
		
		required init(from decoder: Decoder) throws {
			let values = try decoder.container(keyedBy: CodingKeys.self)
			title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
			head = try values.decodeIfPresent(UInt16.self, forKey: .head)
			identifier = try values.decode(Int16.self, forKey: .identifier)
			banner = try values.decodeIfPresent(Int32.self, forKey: .banner)
		}
	}

	let prefixes: [UInt16: String]
	let items: [UInt16: String]
	let walls: [WallInfo]
	let tiles: [TileInfo]
	let npcs: [NPC]
	let npcsByIdentifier: [Int16: NPC]
	let npcsByBanner: [Int32: NPC]
	let npcsByName: [String: NPC]
	
	let skyColor: NSColor
	let earthColor: NSColor
	let rockColor: NSColor
	let hellColor: NSColor
	let waterColor: NSColor
	let lavaColor: NSColor
	let honeyColor: NSColor
}
