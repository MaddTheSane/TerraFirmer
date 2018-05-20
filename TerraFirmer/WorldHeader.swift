//
//  WorldHeader.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/20/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation

class WorldHeader {
	
	enum Header {
		case boolean(Bool)
		case byte(UInt8)
		case int16(UInt16)
		case int32(UInt32)
		case int64(UInt64)
		case float(Float)
		case double(Double)
		case string(String)
		case byteArray([UInt8])
		case int32Array([UInt32])
		case stringArray([String])
		
		func toInt() -> Int {
			switch self {
			case .boolean(let bo):
				return bo ? 1 : 0
				
			case .byte(let num):
				return Int(num)
				
			case .int16(let num):
				return Int(num)

			case .int32(let num):
				return Int(num)

			case .int64(let num):
				return Int(num)
				
			case .float(let num):
				return Int(num)

			case .double(let num):
				return Int(num)
				
			default:
				fatalError("Unable to get integer from Header type")
			}
		}
	}

	
	struct Field: Codable {
		enum FieldType: String, Codable {
			case boolean = "b"
			case byte = "u8"
			case int16 = "i16"
			case int32 = "i32"
			case int64 = "i64"
			case float32 = "f32"
			case float64 = "f64"
			case string = "s"
			case byteArray = "u8a"
			case int32Array = "i32a"
			case stringArray = "sa"
		};
		
		enum CodingKeys: String, CodingKey {
			case name
			case fieldType = "type"
			case minimumVersion = "min"
			case length = "num"
			case dynamicLength = "relnum"
		}
		
		var name: String
		var fieldType: FieldType
		var length: Int?
		var minimumVersion: Int
		var dynamicLength: String?
		
		init(from decoder: Decoder) throws {
			let values = try decoder.container(keyedBy: CodingKeys.self)
			name = try values.decode(String.self, forKey: .name)
			minimumVersion = try values.decodeIfPresent(Int.self, forKey: .minimumVersion) ?? 88
			var tmpType = try values.decodeIfPresent(FieldType.self, forKey: .fieldType) ?? .boolean
			switch tmpType {
			case .string:
				if values.contains(.length) || values.contains(.dynamicLength) {
					tmpType = .stringArray
				}
				
			case .byte:
				if values.contains(.length) || values.contains(.dynamicLength) {
					tmpType = .byteArray
				}
				
			case .int32:
				if values.contains(.length) || values.contains(.dynamicLength) {
					tmpType = .int32Array
				}
				
			default:
				break
			}
			
			fieldType = tmpType
			length = try values.decodeIfPresent(Int.self, forKey: .length)
			dynamicLength = try values.decodeIfPresent(String.self, forKey: .dynamicLength)
		}
	}
	
	static let fields: [Field] = {
		let jsonHeader = Bundle.main.url(forResource: "header", withExtension: "json")!
		let decoder = JSONDecoder()
		let headerDat = try! Data(contentsOf: jsonHeader)
		return try! decoder.decode([Field].self, from: headerDat)
	}()

	var data = [String: Header]()
	
	subscript(idx: String) -> Header? {
		get {
			return data[idx]
		}
	}
	
	func load(handle: FileHandle, version: Int) -> Bool {
		for field in WorldHeader.fields {
			guard version >= field.minimumVersion else {
				continue
			}
			
			var header: Header
			switch field.fieldType {
				
			case .boolean:
				guard let rd = handle.readUInt8() else {
					return false
				}
				header = .boolean(rd != 0)
			case .byte:
				guard let rd = handle.readUInt8() else {
					return false
				}
				header = .byte(rd)
			case .int16:
				guard let rd = handle.readUInt16() else {
					return false
				}
				header = .int16(rd)
			case .int32:
				guard let rd = handle.readUInt32() else {
					return false
				}
				header = .int32(rd)
			case .int64:
				guard let rd = handle.readUInt64() else {
					return false
				}
				header = .int64(rd)
			case .float32:
				guard let rd = handle.readFloat() else {
					return false
				}
				header = .float(rd)
			case .float64:
				guard let rd = handle.readDouble() else {
					return false
				}
				header = .double(rd)
			case .string:
				guard let rd = handle.readString() else {
					return false
				}
				header = .string(rd)
			case .byteArray:
				var num = field.length ?? 0
				if let dynLen = field.dynamicLength, let dyn2 = data[dynLen]?.toInt() {
					num = dyn2
				}
				var byteArr = [UInt8]()
				for _ in 0 ..< num {
					guard let newByte = handle.readUInt8() else {
						return false
					}
					byteArr.append(newByte)
				}
				header = .byteArray(byteArr)
				
			case .int32Array:
				var num = field.length ?? 0
				if let dynLen = field.dynamicLength, let dyn2 = data[dynLen]?.toInt() {
					num = dyn2
				}
				var byteArr = [UInt32]()
				for _ in 0 ..< num {
					guard let newByte = handle.readUInt32() else {
						return false
					}
					byteArr.append(newByte)
				}
				header = .int32Array(byteArr)
				
			case .stringArray:
				var num = field.length ?? 0
				if let dynLen = field.dynamicLength, let dyn2 = data[dynLen]?.toInt() {
					num = dyn2
				}
				var byteArr = [String]()
				for _ in 0 ..< num {
					guard let newByte = handle.readString() else {
						return false
					}
					byteArr.append(newByte)
				}
				header = .stringArray(byteArr)
			}
			data[field.name] = header
		}
		
		return true
	}
}
