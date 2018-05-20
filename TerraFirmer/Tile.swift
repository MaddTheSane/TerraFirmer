//
//  Tile.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/18/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation

struct Tile {
	struct Flag: OptionSet {
		typealias RawValue = UInt16
		var rawValue: UInt16
		
		static var active: Flag {
			return Flag(rawValue: 1 << 0)
		}
		
		static var lava: Flag {
			return Flag(rawValue: 1 << 1)
		}

		static var honey: Flag {
			return Flag(rawValue: 1 << 2)
		}

		static var redWire: Flag {
			return Flag(rawValue: 1 << 3)
		}

		static var blueWire: Flag {
			return Flag(rawValue: 1 << 4)
		}

		static var greenWire: Flag {
			return Flag(rawValue: 1 << 5)
		}

		static var half: Flag {
			return Flag(rawValue: 1 << 6)
		}

		static var actuator: Flag {
			return Flag(rawValue: 1 << 7)
		}

		static var inactive: Flag {
			return Flag(rawValue: 1 << 8)
		}

		static var seen: Flag {
			return Flag(rawValue: 1 << 9)
		}

		static var yellowWire: Flag {
			return Flag(rawValue: 1 << 10)
		}
	}
	
	var u: Int16 = 0
	var v: Int16 = 0
	var wallU: Int16 = 0
	var wallV: Int16 = 0
	var type: Int16 = 0
	var wall: UInt8 = 0
	var liquid: UInt8 = 0
	var color: UInt8 = 0
	var wallColor: UInt8 = 0
	var slope: UInt8 = 0
	var flags: Flag = []
	
	var isSeen: Bool {
		get {
			return flags.contains(.seen)
		}
		set {
			if newValue {
				flags.insert(.seen)
			} else {
				flags.remove(.seen)
			}
		}
	}
}

extension Tile {
	/// - returns: `nil` if unexpected end of file was reached.
	init?(fileHandle handle: FileHandle, extra: [Bool], rle: inout Int) {
		guard let flags1: UInt8 = handle.readUInt8() else {
			return nil
		}
		var flags2 = UInt8()
		var flags3 = UInt8()
		if (flags1 & 1) != 0 {  // has flags2
			guard let tmpFlags2: UInt8 = handle.readUInt8() else {
				return nil
			}
			flags2 = tmpFlags2
			if (flags2 & 1) != 0 {  // has flags3
				guard let tmpFlags3: UInt8 = handle.readUInt8() else {
					return nil
				}
				flags3 = tmpFlags3
			}
		}
		let active = (flags1 & 2) != 0;
		flags = active ? .active : [];
		if (active) {
			guard let tempType1: Int8 = handle.readInt8() else {
				return nil
			}
			type = Int16(tempType1)
			if (flags1 & 0x20) != 0 {  // 2-byte type
				guard let tempType2: Int8 = handle.readInt8() else {
					return nil
				}
				type |= Int16(tempType2) << 8;
			}
			if (extra[Int(type)]) {
				guard let tmpU: Int16 = handle.readInt16(), let tmpV: Int16 = handle.readInt16() else {
					return nil
				}
				u = tmpU
				v = tmpV
			} else {
				u = -1
				v = -1
			}
			if (flags3 & 0x8) != 0 {
				guard let tmpClr: UInt8 = handle.readUInt8() else {
					return nil
				}
				color = tmpClr
			} else {
				color = 0
			}
		} else {
			type = 0;
			color = 0
			u = 0
			v = 0
		}
		if (flags1 & 4) != 0 {  // wall
			guard let tmpWall: UInt8 = handle.readUInt8() else {
				return nil
			}
			wall = tmpWall
			if (flags3 & 0x10) != 0 {
				wallColor = handle.readUInt8()!
			} else {
				wallColor = 0
			}
			wallU = -1
			wallV = -1
		} else {
			wall = 0;
			wallColor = 0
			wallU = 0
			wallV = 0
		}
		if (flags1 & 0x18) != 0 {
			guard let tmpLiquid: UInt8 = handle.readUInt8() else {
				return nil
			}
			liquid = tmpLiquid
			if (flags1 & 0x18) == 0x10 { // lava
				flags.insert(.lava)
			}
			if (flags1 & 0x18) == 0x18 { // honey
				flags.insert(.honey)
			}
		} else {
			liquid = 0;
		}
		if (flags2 & 2) != 0 { // red wire
			flags.insert(.redWire)
		}
		if (flags2 & 4) != 0 { // blue wire
			flags.insert(.blueWire)
		}
		if (flags2 & 8) != 0 { // green wire
			flags.insert(.greenWire)
		}
		let slop = (flags2 >> 4) & 7;
		if (slop == 1)  { // half
			flags.insert(.half)
		}
		slope = slop > 1 ? slop - 1 : 0;
		
		if (flags3 & 2) != 0 { // actuator
			flags.insert(.actuator)
		}
		if (flags3 & 4) != 0 { // inactive
			flags.insert(.inactive)
		}
		if (flags3 & 32) != 0 { // yellow wire
			flags.insert(.yellowWire)
		}
		
		rle = 0;
		switch (flags1 >> 6) {
		case 1:
			guard let rle1: UInt8 = handle.readUInt8() else {
				return nil
			}
			rle = Int(rle1)

		case 2:
			guard let rle1: UInt16 = handle.readUInt16() else {
				return nil
			}
			rle = Int(rle1)
			
		default:
			break
		}
	}
}
