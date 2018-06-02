//
//  AppDelegate.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/17/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	let steamInfo = try? SteamConfig()

	func applicationWillFinishLaunching(_ notification: Notification) {
		_=WorldInfo.shared
		_=WorldHeader.fields
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}
	
	func scanWorlds() {
		
	}
}

