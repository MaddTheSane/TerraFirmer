//
//  TerraFirmerTests.swift
//  TerraFirmerTests
//
//  Created by C.W. Betts on 5/20/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import XCTest
@testable import TerraFirmer

class TerraFirmerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		_=WorldInfo.shared
		_=WorldHeader.fields
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testMapLoad() {
		var appD = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
		appD.appendPathComponent("Terraria", isDirectory: true)
		appD.appendPathComponent("Worlds", isDirectory: true)
		appD.appendPathComponent("BlankTesting.wld", isDirectory: false)
		
		let newWorld = World()
		do {
			try newWorld.open(from: appD)
		} catch {
			XCTFail("Error thrown: \(error)")
		}
	}
}
