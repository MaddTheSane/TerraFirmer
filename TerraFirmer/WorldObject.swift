//
//  WorldObject.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/17/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation
import zlib

@discardableResult
private func inflateInit2(_ strm: z_streamp, _ windowBits: Int32) -> Int32 {
	return inflateInit2_(strm, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
}

struct TerrariaPoint {
	var x: Int32 = 0
	var y: Int32 = 0
}

struct TerrariaPoint16 {
	var x: Int16 = 0
	var y: Int16 = 0
}

protocol TerrariaEntity {
	var identifier: Int32 {get set}
	var location: TerrariaPoint16 {get set}
}

extension TerrariaEntity {
	var x: Int16 {
		get {
			return location.x
		}
		set {
			location.x = newValue
		}
	}
	var y: Int16 {
		get {
			return location.y
		}
		set {
			location.y = newValue
		}
	}
}

protocol WorldLoadDelegate: class {
	func willReadHeader(_ :World)
	func didReadHeader(_ :World)
}

final class World {
	enum LoadError: Error {
		case invalidMagic
		case unexpectedEndOfFile
		case notAPlayerFile
		case unsupportedMapVersion(Int)
		case mapTooOld
		case notAMapFile
	}

	weak var loadDelegate: WorldLoadDelegate?
	
	static var minimumVersion: Int {
		return 88
	}
	static var highestVersion: Int {
		return 194
	}
	
	struct Chest {
		struct Item {
			var stack: Int16 = 1
			var name: String = ""
			var prefix: String = ""
		};
		var location: TerrariaPoint = TerrariaPoint()
		var name: String = ""
		var items: [Item] = []
	};
	
	struct Sign {
		var location: TerrariaPoint = TerrariaPoint()
		var text: String = ""
	};
	
	struct NPC {
		var title: String = ""
		var name: String = ""
		var location: TerrariaPoint = TerrariaPoint()
		var isHomeless: Bool = false
		var homeLocation: TerrariaPoint?
		var sprite: Int16 = 0
		var head: Int16 = 0
		var order: Int16 = 0
	};

	struct TrainingDummy : TerrariaEntity {
		var identifier: Int32 = 0
		var location: TerrariaPoint16 = TerrariaPoint16()
		var npc: Int16 = 0
	};
	
	struct ItemFrame : TerrariaEntity {
		var identifier: Int32 = 0
		var location: TerrariaPoint16 = TerrariaPoint16()
		var itemID: Int16 = 0
		var prefix: UInt8 = 0
		var stack: Int16 = 0
	};
	
	struct LogicSensor : TerrariaEntity {
		var identifier: Int32 = 0
		var location: TerrariaPoint16 = TerrariaPoint16()
		var type: UInt8 = 0
		var isOn: Bool = false
	};
	
	let header = WorldHeader()
	private(set) var tiles = [Tile]()
	private(set) var chests = [Chest]()
	private(set) var signs = [Sign]()
	private(set) var npcs = [NPC]()
	private(set) var entities = [TerrariaEntity]()
	private(set) var tilesHigh = 0
	private(set) var tilesWide = 0
	
	func open(from: URL) throws {
		let handle = try FileHandle(forReadingFrom: from)
		guard let version2 = handle.readUInt32() else {
			throw LoadError.unexpectedEndOfFile
		}
		let version = Int(version2)
		guard version <= World.highestVersion else {
			throw LoadError.unsupportedMapVersion(version)
		}
		guard version >= World.minimumVersion else {
			throw LoadError.mapTooOld
		}
		
		if version >= 135 {
			let magicData = handle.readData(ofLength: 7)
			guard let magic = String(data: magicData, encoding: .utf8), magic == "relogic" else {
				throw LoadError.invalidMagic
			}
			guard let type = handle.readUInt8() else {
				throw LoadError.unexpectedEndOfFile
			}
			guard type == 2 else {
				throw LoadError.notAMapFile
			}
			_=handle.readData(ofLength: 4 + 8);  // revision + favorites
		}
		
		
		guard let numSections = handle.readUInt16() else {
			throw LoadError.unexpectedEndOfFile
		}
		var sections = [Int32]()
		for _ in 0 ..< numSections {
			guard let section = handle.readInt32() else {
				throw LoadError.unexpectedEndOfFile
			}
			sections.append(section)
		}
		
		guard let numTiles = handle.readUInt16() else {
			throw LoadError.unexpectedEndOfFile
		}
		var mask: UInt8 = 0x80
		var bits: UInt8 = 0
		var extra = [Bool]()
		for _ in 0 ..< numTiles {
			if mask == 0x80 {
				guard let newBits = handle.readUInt8() else {
					throw LoadError.unexpectedEndOfFile
				}
				bits = newBits
				mask = 1
			} else {
				mask <<= 1
			}
			extra.append((bits & mask) != 0)
		}
		
		handle.seek(toFileOffset: UInt64(sections[0]))  // skip any extra junk
		guard loadHeader(handle: handle, version: version) else {
			throw LoadError.unexpectedEndOfFile
		}
		
		handle.seek(toFileOffset: UInt64(sections[1]))
		guard loadTiles(handle: handle, version: version, extra: extra) else {
			throw LoadError.unexpectedEndOfFile
		}
		
		handle.seek(toFileOffset: UInt64(sections[2]))
		guard loadChests(handle: handle, version: version) else {
			throw LoadError.unexpectedEndOfFile
		}
		handle.seek(toFileOffset: UInt64(sections[3]))
		guard loadSigns(handle: handle, version: version) else {
			throw LoadError.unexpectedEndOfFile
		}
		handle.seek(toFileOffset: UInt64(sections[4]))
		guard loadNPCs(handle: handle, version: version) else {
			throw LoadError.unexpectedEndOfFile
		}
		handle.seek(toFileOffset: UInt64(sections[5]))
		if version >= 116 {
			if version < 122 {
				guard loadDummies(handle: handle, version: version) else {
					throw LoadError.unexpectedEndOfFile
				}
			} else {
				guard loadEntities(handle: handle, version: version) else {
					throw LoadError.unexpectedEndOfFile
				}
			}
		}
		if (version >= 170) {
			handle.seek(toFileOffset: UInt64(sections[6]))
			guard loadPressurePlates(handle: handle, version: version) else {
				throw LoadError.unexpectedEndOfFile
			}
		}
		if (version >= 189) {
			handle.seek(toFileOffset: UInt64(sections[7]))
			guard loadTownManager(handle: handle, version: version) else {
				throw LoadError.unexpectedEndOfFile
			}
		}
		
		//if (!player.isEmpty()) {
		//	loadPlayer();
		//}

		spreadLight()
	}
	
	private func loadHeader(handle: FileHandle, version: Int) -> Bool {
		
		guard header.load(handle: handle, version: version) else {
			return false
		}
		
		guard let tilesHigh = header["tilesHigh"]?.toInt(),
			let tilesWide = header["tilesWide"]?.toInt() else {
				return false
		}
		
		self.tilesHigh = tilesHigh
		self.tilesWide = tilesWide

		tiles = [Tile](repeating: Tile(), count: tilesHigh * tilesWide)
		return true
	}
	
	private func loadTiles(handle: FileHandle, version: Int, extra: [Bool]) -> Bool {
		// TODO: Speed this up, but how?
		for x in 0 ..< tilesWide {
			var offset = x
			var y = 0
			repeat {
				var rle = 0
				defer {
					y += 1
				}
				guard let newTile = Tile(fileHandle: handle, extra: extra, rle: &rle) else {
					return false
				}
				tiles[offset] = newTile
				
				var destOffset = offset + tilesWide
				if rle > 0 {
					for r in 0 ..< rle {
						defer {
							destOffset += tilesWide
						}
						tiles[destOffset] = tiles[offset]
					}
				}
				y += rle
				offset = destOffset
			} while y < tilesHigh
		}
		
		return true
	}
	
	private func loadChests(handle: FileHandle, version: Int) -> Bool {
		
		guard let numChests = handle.readUInt16(),
			let itemsPerChest = handle.readUInt16() else {
			return false
		}
		
		for _ in 0 ..< numChests {
			guard let cx = handle.readInt32(),
				let cy = handle.readInt32(),
				let cname = handle.readString() else {
				return false
			}
			
			var chest = Chest(location: TerrariaPoint(x: cx, y: cy), name: cname, items: [])
			for _ in 0 ..< itemsPerChest {
				guard let stack = handle.readInt16() else {
					return false
				}
				
				if stack > 0 {
					var item = Chest.Item()
					item.stack = stack
					guard let itm = handle.readUInt32(),
						let prfx = handle.readUInt8() else {
						return false
					}
					
					item.name = WorldInfo.shared.items[UInt16(itm)] ?? ""
					item.prefix = WorldInfo.shared.prefixes[UInt16(prfx)] ?? ""
					chest.items.append(item)
				}
			}
			
			chests.append(chest)
		}
		
		return true
	}
	
	private func loadSigns(handle: FileHandle, version: Int) -> Bool {
		guard let numSigns = handle.readUInt16() else {
			return false
		}
		
		for _ in 0 ..< numSigns {
			guard let st = handle.readString(),
				let sx = handle.readInt32(),
				let sy = handle.readInt32() else {
				return false
			}
			signs.append(World.Sign(location: TerrariaPoint(x: sx, y: sy), text: st))
		}
		
		return true
	}
	
	private func loadNPCs(handle: FileHandle, version: Int) -> Bool {
		
		while handle.readUInt8()! != 0 {
			var npc = NPC()
			npc.head = 0;
			npc.sprite = 0;
			if version >= 190 {
				guard let sprite = handle.readInt32() else {
					return false
				}
				npc.sprite = Int16(sprite);
				if let theNPC = WorldInfo.shared.npcsByIdentifier[npc.sprite] {
					npc.head = Int16(bitPattern: theNPC.head ?? 0)
					npc.title = theNPC.title;
				}
			} else {
				guard let title = handle.readString() else {
					return false
				}
				npc.title = title
				if let theNPC = WorldInfo.shared.npcsByName[npc.title] {
					npc.head = Int16(bitPattern: theNPC.head ?? 0)
					npc.sprite = theNPC.identifier;
				}
			}
			guard let nName = handle.readString(), let nx = handle.readFloat(), let ny = handle.readFloat(), let homelessByte = handle.readUInt8(), let hx = handle.readInt32(), let hy = handle.readInt32() else {
				return false
			}
			npc.name = nName
			npc.location = TerrariaPoint(x: Int32(nx), y: Int32(ny))
			npc.isHomeless = homelessByte != 0
			npc.homeLocation = TerrariaPoint(x: hx, y: hy)
			npcs.append(npc);
		}
		
		if version >= 140 {
			while handle.readUInt8()! != 0 {
				var npc = NPC();
				if version >= 190 {
					guard let npcSprite = handle.readInt32() else {
						return false
					}
					npc.sprite = Int16(npcSprite);
					if let theNPC = WorldInfo.shared.npcsByIdentifier[npc.sprite] {
						npc.title = theNPC.title;
					}
				} else {
					guard let npcTitle = handle.readString() else {
						return false
					}
					npc.title = npcTitle
					if let theNPC = WorldInfo.shared.npcsByName[npc.title] {
						npc.sprite = theNPC.identifier;
					}
				}
				npc.name = "!!";
				guard let npcx = handle.readFloat(), let npcy = handle.readFloat() else {
					return false
				}
				npc.location = TerrariaPoint(x: Int32(npcx), y: Int32(npcy))
				npc.isHomeless = true;
				npcs.append(npc);
			}
		}

		return true
	}

	private func loadDummies(handle: FileHandle, version: Int) -> Bool {
		guard let numDummies = handle.readInt32() else {
			return false
		}
		for _ in 0 ..< numDummies {
			guard let _ = handle.readInt16() /* x */,
				let _ = handle.readInt16() /* y */ else {
					return false
			}
		}
		
		return true
	}

	private func loadEntities(handle: FileHandle, version: Int) -> Bool {
		
		guard let numEntities = handle.readInt32() else {
			return false
		}
		
		for _ in 0 ..< numEntities {
			guard let type = handle.readInt8() else {
				return false
			}
			
			switch type {
			case 0:
				guard let did = handle.readInt32(),
					let dx = handle.readInt16(),
					let dy = handle.readInt16(),
					let dnpc = handle.readInt16() else {
					return false
				}
				var dummy = TrainingDummy()
				dummy.identifier = did
				dummy.location = TerrariaPoint16(x: dx, y: dy)
				dummy.npc = dnpc
				
				entities.append(dummy)
				
			case 1:
				guard let did = handle.readInt32(),
					let dx = handle.readInt16(),
					let dy = handle.readInt16(),
					let fItemID = handle.readInt16(),
					let fprefix = handle.readUInt8(),
					let fstack = handle.readInt16() else {
						return false
				}
				let itemFrame = ItemFrame(identifier: did, location: TerrariaPoint16(x: dx, y: dy), itemID: fItemID, prefix: fprefix, stack: fstack)
				entities.append(itemFrame)
				
			case 2:
				guard let did = handle.readInt32(),
					let dx = handle.readInt16(),
					let dy = handle.readInt16(),
					let stype = handle.readUInt8(),
					let son = handle.readInt8() else {
						return false
				}
				let sensor = LogicSensor(identifier: did, location: TerrariaPoint16(x: dx, y: dy), type: stype, isOn: son != 0)
				entities.append(sensor)

			default:
				break
			}
		}
		
		return true
	}
	
	private func loadPressurePlates(handle: FileHandle, version: Int) -> Bool {
		guard let numPlates = handle.readInt32() else {
			return false
		}
		
		for _ in 0 ..< numPlates {
			_=handle.readUInt32() //x
			_=handle.readUInt32() //y
		}
		
		return true
	}
	
	private func loadTownManager(handle: FileHandle, version: Int) -> Bool {
		guard let numRooms = handle.readInt32() else {
			return false
		}
		
		for _ in 0 ..< numRooms {
			_=handle.readUInt32()  //NPC
			_=handle.readUInt32()  //X
			_=handle.readUInt32()  //Y
			// I wonder if they will eventually depreciate the 'home' location in the NPC data. This data is for the new feature where NPC's remember which room they were in before they died
		}
		
		return true
	}
	
	private func spreadLight() {
		/*
		// step 1, set light sources
		int offset = 0;
		for (int y = 0; y < tilesHigh; y++) {
		emit status(tr("Lighting tiles : %1%").arg(
		static_cast<int>(y * 50.0f / tilesHigh)), 0);
		for (int x = 0; x < tilesWide; x++, offset++) {
		auto tile = &tiles[offset];
		auto inf = info[tile];
		if ((!tile->active() || inf->transparent) &&
		(tile->wall == 0 || tile->wall == 21) &&
		tile->liquid < 255 && y < header["groundLevel"]->toInt())
		// sunlit
		tile->setLight(1.0, 1.0, 1.0);
		else
		tile->setLight(0.0, 0.0, 0.0);
		if (tile->liquid > 0 && tile->lava())
		tile->addLight(0.66, 0.39, 0.13);
		tile->addLight(inf->lightR, inf->lightG, inf->lightB);
		
		double delta = 0.04;
		if (tile->active() && !inf->transparent)
		delta = 0.16;
		if (y > 0) {
		auto prev = &tiles[offset - tilesWide];
		tile->addLight(prev->lightR() - delta,
		prev->lightG() - delta,
		prev->lightB() - delta);
		}
		if (x > 0) {
		auto prev = &tiles[offset - 1];
		tile->addLight(prev->lightR() - delta,
		prev->lightG() - delta,
		prev->lightB() - delta);
		}
		}
		}
		// step 2, spread light backwards
		offset = tilesHigh * tilesWide - 1;
		for (int y = tilesHigh - 1; y >= 0; y--) {
		emit status(tr("Spreading light: %1%").arg(
		static_cast<int>((tilesHigh - y) * 50.0f / tilesHigh + 50)), 0);
		for (int x = tilesWide - 1; x >= 0; x--, offset--) {
		auto tile = &tiles[offset];
		auto inf = info[tile];
		double delta = 0.04;
		if (tile->active() && !inf->transparent)
		delta = 0.16;
		if (y < tilesHigh - 1) {
		auto prev = &tiles[offset + tilesWide];
		tile->addLight(prev->lightR() - delta,
		prev->lightG() - delta,
		prev->lightB() - delta);
		}
		if (x < tilesWide - 1) {
		auto prev = &tiles[offset + 1];
		tile->addLight(prev->lightR() - delta,
		prev->lightG() - delta,
		prev->lightB() - delta);
		}
		}
		}*/
	}
	
	/*
void World::loadPlayer() {
QString path = player.left(player.lastIndexOf("."));
path += QDir::toNativeSeparators(QString("/%1.map")
.arg(header["worldID"]->toInt()));
QDir dir;
}
*/

	func loadPlayerMap(at url: URL) throws {
		
		for offset in 0 ..< (tilesHigh * tilesWide) {
			tiles[offset].isSeen = true
		}
		
		let handle = try FileHandle(forReadingFrom: url)
		guard let version = handle.readUInt32() else {
			throw LoadError.unexpectedEndOfFile
		}
		
		if version <= 91 {
			guard loadPlayerV1(handle: handle, version: Int(version)) else {
				throw LoadError.unexpectedEndOfFile
			}
		} else {
			try loadPlayerV2(handle: handle, version: Int(version))
		}
	}
	
	private func loadPlayerV1(handle: FileHandle, version: Int) -> Bool {
		_=handle.readString() // name
		_=handle.readUInt32() // id
		_=handle.readUInt32() // tiles high
		_=handle.readUInt32() // tiles wide

		for x in 0 ..< tilesWide {
			var offset = x
			var y = 0
			repeat {
				defer {
					y += 1
					offset += tilesWide
				}
				
				guard let aBool = handle.readUInt8() else {
					return false
				}
				
				if aBool != 0 {
					if version <= 77 {
						_=handle.readUInt8() // tileid
					} else {
						_=handle.readUInt16() // tileid
					}
					_=handle.readUInt8() // light
					_=handle.readUInt8() // misc
					if version >= 50 {
						_=handle.readUInt8() // misc2
					}
					tiles[offset].isSeen = true
					guard var rle = handle.readUInt16() else {
						return false
					}
					while rle > 0 {
						rle -= 1
						y += 1
						offset += tilesWide
						tiles[offset].isSeen = true
					}
				} else {
					guard var rle = handle.readUInt16() else {
						return false
					}
					while rle > 0 {
						rle -= 1
						y += 1
						offset += tilesWide
						tiles[offset].isSeen = false
					}
				}
				
			} while y < tilesHigh
		}
		
		return true
	}
	
	private func loadPlayerV2(handle origHandle: FileHandle, version: Int) throws {
		var toDelete: URL? = nil
		defer {
			if let toDelete = toDelete {
				try? FileManager.default.removeItem(at: toDelete)
			}
		}
		var handle = origHandle
		if (version >= 135) {
			let magicData = handle.readData(ofLength: 7)
			guard let magic = String(data: magicData, encoding: .utf8),
				magic == "relogic" else {
				throw LoadError.invalidMagic
			}
			guard let type = handle.readUInt8() else {
				throw LoadError.unexpectedEndOfFile
			}
			
			guard type == 1 else {
				throw LoadError.notAPlayerFile
			}
			handle.readData(ofLength: 4 + 8) // revision + favorites
		}
		_=handle.readString()  // name
		_=handle.readUInt32()  // worldid
		_=handle.readUInt32()  // tiles high
		_=handle.readUInt32()  // tiles wide

		guard let numTiles = handle.readUInt16(),
			let numWalls = handle.readUInt16() else {
			throw LoadError.unexpectedEndOfFile
		}
		
		_=handle.readUInt16() // num unk1
		_=handle.readUInt16() // num unk2
		_=handle.readUInt16() // num unk3
		_=handle.readUInt16() // num unk4
		
		var tilePresent = [Bool]()
		var mask: UInt8 = 0x80
		var bits: UInt8 = 0
		for _ in 0 ..< numTiles {
			if mask == 0x80 {
				guard let newBits = handle.readUInt8() else {
					throw LoadError.unexpectedEndOfFile
				}
				bits = newBits
				mask = 1
			} else {
				mask <<= 1
			}
			tilePresent.append((bits & mask) != 0)
		}
		
		var wallPresent = [Bool]()
		mask = 0x80
		bits = 0
		for _ in 0 ..< numTiles {
			if mask == 0x80 {
				guard let newBits = handle.readUInt8() else {
					throw LoadError.unexpectedEndOfFile
				}
				bits = newBits
				mask = 1
			} else {
				mask <<= 1
			}
			wallPresent.append((bits & mask) != 0)
		}
		
		for i in 0 ..< Int(numTiles) {
			if tilePresent[i] {
				_=handle.readUInt8() // throw away tile data
			}
		}
		
		for i in 0 ..< Int(numTiles) {
			if wallPresent[i] {
				_=handle.readUInt8() // throw away wall data
			}
		}

		if version >= 93 {
			let toRead = handle.readDataToEndOfFile()
			var output = Data(capacity: toRead.count * 2)
			let CHUNK_SIZE = 32768
			
			var strm = z_stream()
			strm.zalloc = nil
			strm.zfree = nil
			strm.opaque = nil
			strm.avail_in = uInt(toRead.count)
			toRead.withUnsafeBytes { (headBytes: UnsafePointer<Bytef>) -> Void in
				let unsafebc = UnsafeMutablePointer(mutating: headBytes)
				strm.next_in = unsafebc
				inflateInit2(&strm, -15);

				var outChunk = Data(count: CHUNK_SIZE)
				repeat {
					outChunk.withUnsafeMutableBytes({ (outBytes: UnsafeMutablePointer<Bytef>) -> Void in
						strm.avail_out = uInt(CHUNK_SIZE)
						strm.next_out = outBytes
						inflate(&strm, Z_NO_FLUSH)
					})
					outChunk.count = CHUNK_SIZE - Int(strm.avail_out)
					output.append(outChunk)
				} while strm.avail_out == 0
				inflateEnd(&strm)
			}
			
			var tmpURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
			tmpURL.appendPathComponent("tmpPlayerMap")
			try output.write(to: tmpURL)
			toDelete = tmpURL
			handle = try FileHandle(forReadingFrom: tmpURL)
		}
		
		var offset = 0
		for y in 0 ..< tilesHigh {
			var x = 0
			repeat {
				defer {
					x += 1
					offset += 1
				}

				guard let flags = handle.readUInt8() else {
					throw LoadError.unexpectedEndOfFile
				}
				if (flags & 1) != 0 {
					_=handle.readUInt8() // color
				}
				let tile = (flags >> 1) & 7
				switch tile {
				case 1, 2, 7:
					if (flags & 16) != 0 {
						_=handle.readUInt16() // tileid
					} else {
						_=handle.readUInt8() // tileid
					}
					
				default:
					break
				}
				
				var light: UInt8
				if (flags & 32) == 0 {
					light = 255
				} else {
					guard let newLight = handle.readUInt8() else {
						throw LoadError.unexpectedEndOfFile
					}
					light = newLight
				}
				
				var rle = 0
				switch ((flags >> 6) & 3) {
				case 1:
					guard let rle1 = handle.readUInt8() else {
						throw LoadError.unexpectedEndOfFile
					}
					rle = Int(rle1)
					
				case 2:
					guard let rle1 = handle.readUInt16() else {
						throw LoadError.unexpectedEndOfFile
					}
					rle = Int(rle1)

				default:
					break
				}
				
				if tile != 0 {
					tiles[offset].isSeen = true
					if light == 255 {
						while rle > 0 {
							rle -= 1
							x += 1
							offset += 1
							tiles[offset].isSeen = true
						}
					} else {
						while rle > 0 {
							rle -= 1
							x += 1
							guard let newLight = handle.readUInt8() else {
								throw LoadError.unexpectedEndOfFile
							}
							light = newLight
							offset += 1
							tiles[offset].isSeen = true
						}
					}
				} else {
					tiles[offset].isSeen = false;
					while rle > 0 {
						rle -= 1
						x += 1
						offset += 1
						tiles[offset].isSeen = false
					}

				}
				
			} while x < tilesWide
		}
	}
}
