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
	@IBOutlet weak var openWorldMenu: NSMenu!
	let steamInfo = try? SteamConfig()

	func applicationWillFinishLaunching(_ notification: Notification) {
		_=WorldInfo.shared
		_=WorldHeader.fields
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		scanWorlds()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}
	
	@IBAction func openWorld(_ sender: NSMenuItem) {
		guard let url = sender.representedObject as? URL else {
			NSSound.beep()
			return
		}
		do {
			let newDoc: NSDocument
			if let theDoc = NSDocumentController.shared.document(for: url) {
				newDoc = theDoc
			} else {
				newDoc = try NSDocumentController.shared.makeDocument(withContentsOf: url, ofType: "TerrariaWorld")
				newDoc.makeWindowControllers()
				NSDocumentController.shared.addDocument(newDoc)
			}
			newDoc.showWindows()
		} catch {
			NSApp.presentError(error)
		}
	}
	
	func scanWorlds() {
		var worldDirectories = [URL]()
		let steamDir: URL
		if let steamInstallPath = steamInfo?["software/valve/steam/baseinstallfolder_1"] {
			steamDir = URL(fileURLWithPath: steamInstallPath)
		} else {
			var localURL = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
			localURL.appendPathComponent("Steam", isDirectory: true)
			steamDir = localURL
		}
		do {
			let userData = steamDir.appendingPathComponent("userdata", isDirectory: true)
			if let dirEnum = FileManager.default.enumerator(at: userData, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
				for dir in dirEnum {
					var dirE = (dir as! URL).appendingPathComponent("105600", isDirectory: true)
					dirE.appendPathComponent("remote", isDirectory: true)
					dirE.appendPathComponent("worlds", isDirectory: true)
					guard (try? dirE.checkResourceIsReachable()) ?? false else {
						continue
					}
					worldDirectories.append(dirE)
				}
			}
		}
		
		do {
			var localURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
			localURL.appendPathComponent("Terraria", isDirectory: true)
			localURL.appendPathComponent("Worlds", isDirectory: true)

			if try localURL.checkResourceIsReachable() {
				worldDirectories.append(localURL)
			}
		} catch _ { }
		
		for worldPath in worldDirectories {
			if openWorldMenu.numberOfItems != 0 {
				openWorldMenu.addItem(.separator())
			}
			var worldURLs = [URL]()
			
			guard let dirEnum = FileManager.default.enumerator(at: worldPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
				continue
			}
			for worldURL1 in dirEnum {
				let worldURL = worldURL1 as! URL
				if worldURL.pathExtension.compare("wld", options: [.caseInsensitive]) == .orderedSame {
					worldURLs.append(worldURL)
				}
			}
			worldURLs.sort { (url1, url2) -> Bool in
				return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
			}
			
			for world in worldURLs {
				let worldName = world.deletingPathExtension()
				let newItem = NSMenuItem(title: worldName.lastPathComponent, action: #selector(AppDelegate.openWorld(_:)), keyEquivalent: "")
				newItem.representedObject = world
				newItem.target = self
				openWorldMenu.addItem(newItem)
			}
		}
	}
}

