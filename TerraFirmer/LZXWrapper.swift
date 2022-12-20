//
//  LZXWrapper.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/18/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation

class LZX {
	enum ErrorCode: Int32, Error {
		case badDataFormat = 1
		case illegalData = 2
		case noMemory = 3
	}
	
	private var state: OpaquePointer
	
	/// create an lzx state object
	init(window: Int) {
		state = LZXinit(Int32(window))
	}
	
	deinit {
		LZXteardown(state)
	}
	
	/// reset an lzx stream
	func reset() {
		LZXreset(state)
	}
	
	/// decompress an LZX compressed block
	func decompress(_ inData: Data, outputLength: Int) throws -> Data {
		var outData = Data(count: outputLength)
		
		let retVal = inData.withUnsafeBytes { (inBytes: UnsafeRawBufferPointer) -> Int32 in
			return outData.withUnsafeMutableBytes({ (outBytes: UnsafeMutableRawBufferPointer) -> Int32 in
                return LZXdecompress(state, inBytes.baseAddress, outBytes.baseAddress, Int32(inBytes.count), Int32(outBytes.count))
			})
		}
		
		guard retVal == DECR_OK else {
			throw ErrorCode(rawValue: retVal) ?? ErrorCode.illegalData
		}
		return outData
	}
}
