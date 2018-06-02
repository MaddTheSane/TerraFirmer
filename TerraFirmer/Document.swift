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
	func willReadMap(_ worldObj: World) {
		assert(self.world === worldObj)
		DispatchQueue.main.async {
			
		}
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
	
	func readingTileInWorld(_ worldObj: World, atIndex: Int) {
		assert(self.world === worldObj)
		DispatchQueue.main.async {
			
		}
	}
	
	func didReadTiles(_ worldObj: World, wasSuccessful: Bool) {
		assert(self.world === worldObj)
		DispatchQueue.main.async {
			
		}
	}
	
	func shouldCancelLoading(_ worldObj: World) -> Bool {
		assert(self.world === worldObj)
		var toRet = false
		DispatchQueue.main.sync {
			toRet = stopLoading
		}
		return toRet
	}

}

