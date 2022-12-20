//
//  AESWrapper.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/17/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Foundation
import CommonCrypto
import CommonCrypto.CommonCryptor

class CommonCryptorWrapper {
	enum ErrorCode: CCCryptorStatus, Error {
		/// Illegal parameter value.
		case parameter		= -4300
		/// Insufficent buffer provided for specified
		/// operation.
		case bufferTooSmall	= -4301
		/// Memory allocation failure. 
		case memoryFailure	= -4302
		/// Input size was not aligned properly. 
		case alignment		= -4303
		/// Input data did not decode or decrypt
		/// properly.
		case decode			= -4304
		/// Function not implemented for the current
		/// algorithm.
		case unimplemented	= -4305
		case overflow		= -4306
		case rngFailure		= -4307
		case unspecified	= -4308
		case callSequence	= -4309
		case keySize		= -4310
	}
	
	enum Operation: CCOperation {
		case encrypt = 0
		case decrypt
	}
	
	/// Encryption algorithms implemented by CommonCrypto.
	enum Algorithm: CCAlgorithm {
		/// Advanced Encryption Standard, 128-bit block
		case AES = 0
		
		/// Data Encryption Standard
		case DES
		
		/// Triple-DES, three key, EDE configuration
		case algorithm3DES
		
		/// CAST
		case CAST
		
		/// RC4 stream cipher
		case RC4
		
		/// RC2 stream(?) cipher
		case RC2
		
		/// Blowfish block cipher
		case Blowfish

		/// Advanced Encryption Standard, 128-bit block
		/// This is kept for historical reasons.  It's
		/// preferred now to use kCCAlgorithmAES since
		/// 128-bit blocks are part of the standard.
		static var AES128: Algorithm {
			return Algorithm.AES
		}
	}
	
	struct Options: OptionSet {
		typealias RawValue = CCOptions
		
		var rawValue: CCOptions
		
		init(rawValue: CCOptions) {
			self.rawValue = rawValue
		}
		
		/// Perform PKCS7 padding.
		static var PKCS7Padding: Options {
			return Options(rawValue: 0x01)
		}
		
		/// Electronic Code Book Mode.
		///
		/// Default is CBC.
		static var ECBMode: Options {
			return Options(rawValue: 0x02)
		}
	}
	
	private var crypto: CCCryptorRef
	
	init(operation: Operation, algorithm: Algorithm, options: Options = [], key: Data, initializationVector: Data? = nil) throws {
		var tmpCryptoRef: CCCryptorRef? = nil
		var iv: [UInt8]
		if let iniVec = initializationVector {
			iv = Array(iniVec)
		} else {
			iv = []
		}
		let status = key.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> CCCryptorStatus in
			return iv.withUnsafeBytes({ (buf) -> CCCryptorStatus in
				return CCCryptorCreate(operation.rawValue, algorithm.rawValue, options.rawValue, bytes.baseAddress, bytes.count, iv.count == 0 ? nil : buf.baseAddress, &tmpCryptoRef)
			})
		}
		
		guard status == kCCSuccess, let cryptoRef = tmpCryptoRef else {
			throw ErrorCode(rawValue: status) ?? ErrorCode.unspecified
		}
		crypto = cryptoRef
	}
	
	deinit {
		CCCryptorRelease(crypto)
	}
	
	/// Process (encrypt, decrypt) some data. The result, if any,
	/// is returned.
	/// - parameter data: Data to process.
	///
	/// This routine can be called multiple times. The caller does
	/// not need to align input data lengths to block sizes; input is
	/// bufferred as necessary for block ciphers.
	///
	/// In the following cases, the CCCryptorFinal() is superfluous as
	/// it will not yield any data nor return an error:
	/// 1. Encrypting or decrypting with a block cipher with padding
	/// disabled, when the total amount of data provided to
	/// CCCryptorUpdate() is an integral multiple of the block size.
	/// 2. Encrypting or decrypting with a stream cipher.
	func update(_ data: Data) throws -> Data {
		let toRetSize = CCCryptorGetOutputLength(crypto, data.count, false)
		var toRet = Data(count: toRetSize)
		
		let status = data.withUnsafeBytes { (newBytes: UnsafeRawBufferPointer) -> CCCryptorStatus in
			var newStatus: CCCryptorStatus = 0
			var written = 0
			repeat {
				newStatus = toRet.withUnsafeMutableBytes({ (toRetBytes: UnsafeMutableRawBufferPointer) -> CCCryptorStatus in
					return CCCryptorUpdate(crypto, newBytes.baseAddress, newBytes.count, toRetBytes.baseAddress, toRetBytes.count, &written)
				})
				toRet.append(Data(count: 128))
			} while newStatus == kCCBufferTooSmall
			
			toRet.count = written
			
			return newStatus
		}
		
		guard status == kCCSuccess else {
			throw ErrorCode(rawValue: status) ?? ErrorCode.unspecified
		}
		
		return toRet
	}
	
	/// Finish an encrypt or decrypt operation, and obtain the (possible)
	/// final data output.
	func finalize() throws -> Data {
		let toRetSize = CCCryptorGetOutputLength(crypto, 0, true)
		var toRet = Data(count: toRetSize)

		var written = 0
		var status: CCCryptorStatus = 0
		repeat {
			status = toRet.withUnsafeMutableBytes({ (toRetBytes: UnsafeMutableRawBufferPointer) -> CCCryptorStatus in
				return CCCryptorFinal(crypto, toRetBytes.baseAddress, toRetBytes.count, &written)
			})
			toRet.append(Data(count: 128))
		} while status == kCCBufferTooSmall
		
		toRet.count = written
		
		guard status == kCCSuccess else {
			throw ErrorCode(rawValue: status) ?? ErrorCode.unspecified
		}

		return toRet
	}
	
	/// Reinitializes an existing CCCryptorRef with a (possibly)
	/// new initialization vector. The `CommonCryptorWrapper`'s key is
	/// unchanged. Use only for CBC mode.
	func reset(initializationVector iv: Data? = nil) throws {
		var ivec: [UInt8]
		if let iniVec = iv {
			ivec = Array(iniVec)
		} else {
			ivec = []
		}

		let status = ivec.withUnsafeBytes({ (buf) -> CCCryptorStatus in
			return CCCryptorReset(crypto, ivec.count == 0 ? nil : buf.baseAddress)
		})

		guard status == kCCSuccess else {
			throw ErrorCode(rawValue: status) ?? ErrorCode.unspecified
		}
	}
	
	/// These are the selections available for modes of operation for
	/// use with block ciphers.  If RC4 is selected as the cipher (a stream
	/// cipher) the only correct mode is `.RC4`.
	enum Mode: CCMode {
		/// Electronic Code Book Mode.
		case ECB = 1
		/// Cipher Block Chaining Mode.
		case CBC		= 2
		/// Cipher Feedback Mode.
		case CFB		= 3
		case CTR		= 4
		/// Unimplemented for now (not included)
		case F8		= 5
		/// Unimplemented for now (not included)
		case LRW		= 6
		/// Output Feedback Mode.
		case OFB		= 7
		/// XEX-based Tweaked CodeBook Mode.
		case XTS		= 8
		/// RC4 as a streaming cipher is handled internally as a mode.
		case RC4		= 9
		/// Cipher Feedback Mode producing 8 bits per round.
		case CFB8		= 10
	}
	
	/// Padding for Block Ciphers
	///
	/// These are the padding options available for block modes.
	enum Padding: CCPadding {
		/// No padding
		case none = 0
		/// PKCS7 Padding
		case PKCS7 = 1
	}
	
	init(operation: Operation, mode: Mode, algorithm: Algorithm, padding: Padding, initializationVector: Data? = nil, key: Data, tweak: Data, numberOfRounds: Int = 0, options: Options = []) throws {
		if numberOfRounds > Int(Int32.max) || numberOfRounds < 0 {
			throw ErrorCode.parameter
		}
		var tmpCryptoRef: CCCryptorRef? = nil
		var iv: [UInt8]
		if let iniVec = initializationVector {
			iv = Array(iniVec)
		} else {
			iv = []
		}
		let status = key.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> CCCryptorStatus in
			return tweak.withUnsafeBytes({ (tweakBytes: UnsafeRawBufferPointer) -> CCCryptorStatus in
				return iv.withUnsafeBytes({ (buf) -> CCCryptorStatus in
					return CCCryptorCreateWithMode(operation.rawValue, mode.rawValue, algorithm.rawValue, padding.rawValue, iv.count == 0 ? nil : buf.baseAddress, bytes.baseAddress, bytes.count, tweakBytes.baseAddress, tweakBytes.count, Int32(numberOfRounds), options.rawValue, &tmpCryptoRef)
				})
			})
		}
		
		guard status == kCCSuccess, let cryptoRef = tmpCryptoRef else {
			throw ErrorCode(rawValue: status) ?? ErrorCode.unspecified
		}
		crypto = cryptoRef
	}
}
