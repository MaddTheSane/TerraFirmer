//
//  Document.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/17/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Cocoa

class Document: NSDocument {
	private var stopLoading = false
	private var totalTiles = 0
	
	var world = World()
	private var allLoaded = false
	@IBOutlet weak var mapView: MapView!
	@IBOutlet weak var statusLine: NSTextField!
	@IBOutlet weak var progressWindow: NSWindow!
	@IBOutlet weak var progressBar: NSProgressIndicator!

	override init() {
	    super.init()
		// Add your subclass-specific initialization here.
	}

	override class var autosavesInPlace: Bool {
		return true
	}

	override var windowNibName: NSNib.Name? {
		// Returns the nib file name of the document
		// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
		return NSNib.Name("Document")
	}

	override func data(ofType typeName: String) throws -> Data {
		// Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
		// You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}

	override func read(from url: URL, ofType typeName: String) throws {
		world.loadDelegate = self
		DispatchQueue.global().async {
			do {
				try self.world.open(from: url)
			} catch {
				self.presentError(error)
			}
		}
	}
	
	override func close() {
		stopLoading = true
		super.close()
	}
	
	override var isEntireFileLoaded: Bool {
		return allLoaded
	}
	
	@IBAction func showKills(_ sender: Any?) {
		
	}
}

extension Document: WorldLoadDelegate {
	func willReadHeader(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadHeader(_ worldObj: World) {
		
	}
	
	func willReadChests(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadChests(_ worldObj: World) {
		
	}
	
	func willReadSigns(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadSigns(_ worldObj: World) {
		
	}
	
	func willReadNPCs(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadNPCs(_ worldObj: World) {
		
	}
	
	func willReadDummies(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadDummies(_ worldObj: World) {
		
	}
	
	func willReadEntities(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadEntities(_ worldObj: World) {
		
	}
	
	func willReadPressurePlates(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadPressurePlates(_ worldObj: World) {
		
	}
	
	func willReadTownManager(_ worldObj: World) {
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadTownManager(_ worldObj: World) {
		
	}
	
	func willReadMap(_ worldObj: World) {
		assert(self.world === worldObj)
		//DispatchQueue.main.async {
		//
		//}
	}
	
	func didReadMap(_ world: World) {
		assert(self.world === world)
		DispatchQueue.main.async {
			self.allLoaded = true
		}
	}
	
	func willReadTiles(_ worldObj: World, totalCount: Int) {
		assert(self.world === worldObj)
		DispatchQueue.main.async {
			self.totalTiles = totalCount
		}
	}
	
	func countOfTilesRead(in worldObj: World, count: Int) {
		assert(self.world === worldObj)
		DispatchQueue.main.async {
			let percentage = CGFloat(count) / CGFloat(self.totalTiles)
			self.statusLine?.stringValue = String(format: NSLocalizedString("Loading tiles… %f%%", comment: "Loading Tiles percentage"), percentage * 100)
		}
	}
	
	func didReadTiles(_ worldObj: World, wasSuccessful: Bool) {
		assert(self.world === worldObj)
		DispatchQueue.main.async {
			
		}
	}
	
	func shouldCancelLoading(_ worldObj: World) -> Bool {
		assert(self.world === worldObj)
		return stopLoading
	}
}

