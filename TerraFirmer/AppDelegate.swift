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
		var worldPaths = [URL]()
		if let steamInstallPath = steamInfo?["software/valve/steam/baseinstallfolder_1"] {
			let steamDir = URL(fileURLWithPath: steamInstallPath)
			let userData = steamDir.appendingPathComponent("userdata", isDirectory: true)
			if let dirEnum = FileManager.default.enumerator(at: userData, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
				for dir in dirEnum {
					var dirE = (dir as! URL).appendingPathComponent("105600")
					dirE.appendPathComponent("remote")
					dirE.appendPathComponent("worlds", isDirectory: true)
					guard (try? dirE.checkResourceIsReachable()) ?? false else {
						continue
					}
					worldPaths.append(dirE)
				}
			}
		}
		
		var localURL = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
		localURL.appendPathComponent("Terraria")
		localURL.appendPathComponent("Worlds")
		worldPaths.append(localURL)
		
		for worldURL in worldPaths {
			_=worldURL
		}
	}
}

