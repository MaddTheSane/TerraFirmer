//
//  FileHandleAdditions.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/18/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation

extension FileHandle {
	func readUInt8() -> UInt8? {
		let newData = self.readData(ofLength: 1)
		guard newData.count == 1 else {
			return nil
		}
		return newData[0]
	}
	
	func readInt8() -> Int8? {
		guard let newData: UInt8 = readUInt8() else {
			return nil
		}
		return Int8(bitPattern: newData)
	}

	func readUInt16() -> UInt16? {
		let newData = self.readData(ofLength: 2)
		guard newData.count == 2 else {
			return nil
		}
		var full = UInt16(newData[0])
		full |= UInt16(newData[1]) << 8
		return full
	}
	
	func readInt16() -> Int16? {
		guard let newData: UInt16 = readUInt16() else {
			return nil
		}
		return Int16(bitPattern: newData)
	}

	func readUInt32() -> UInt32? {
		let newData = self.readData(ofLength: 4)
		guard newData.count == 4 else {
			return nil
		}
		var full = UInt32(newData[0])
		full |= UInt32(newData[1]) << 8
		full |= UInt32(newData[2]) << 16
		full |= UInt32(newData[3]) << 24
		return full
	}
	
	func readInt32() -> Int32? {
		guard let newData: UInt32 = readUInt32() else {
			return nil
		}
		return Int32(bitPattern: newData)
	}

	func readUInt64() -> UInt64? {
		let newData = self.readData(ofLength: 8)
		guard newData.count == 8 else {
			return nil
		}
		var full = UInt64(newData[0])
		full |= UInt64(newData[1]) << 8
		full |= UInt64(newData[2]) << 16
		full |= UInt64(newData[3]) << 24
		full |= UInt64(newData[4]) << 32
		full |= UInt64(newData[5]) << 40
		full |= UInt64(newData[6]) << 48
		full |= UInt64(newData[7]) << 56
		return full
	}
	
	func readInt64() -> Int64? {
		guard let newData: UInt64 = readUInt64() else {
			return nil
		}
		return Int64(bitPattern: newData)
	}

	func readFloat() -> Float? {
		guard let rawData: UInt32 = readUInt32() else {
			return nil
		}
		return Float(bitPattern: rawData)
	}
	
	func readDouble() -> Double? {
		guard let rawData: UInt64 = readUInt64() else {
			return nil
		}
		return Double(bitPattern: rawData)
	}

	func readString() -> String? {
		var len = 0;
		var shift = 0;
		var u7 = UInt8();
		repeat {
			let tmpDat = readData(ofLength: 1)
			u7 = tmpDat[0];
			len |= Int(u7 & 0x7f) << shift;
			shift += 7;
		} while (u7 & 0x80) != 0
		// Rewind by one?
		//seek(toFileOffset: offsetInFile - 1)
		
		let data = readData(ofLength: len)
		return String(data: data, encoding: .utf8)
	}
}
