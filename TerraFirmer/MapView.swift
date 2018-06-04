//
//  MapView.swift
//  TerraFirmer
//
//  Created by C.W. Betts on 5/21/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

import Cocoa
import Quartz

func locateTerrariaApp() throws -> URL {
	var errOut: Unmanaged<CFError>? = nil
	guard let appNSList = LSCopyApplicationURLsForBundleIdentifier("org.Terraria" as NSString, &errOut)?.takeRetainedValue() as NSArray?,
		let appList = appNSList as? [URL] else {
			if let errThrow = errOut?.takeRetainedValue() {
				throw errThrow
			} else {
				throw NSError(domain: NSCocoaErrorDomain, code: -1)
			}
	}
	return appList[0]
}

class MapView: NSView {

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		wantsLayer = true
	}
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		wantsLayer = true
	}
	
	override func updateLayer() {
		
	}
	
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
	
	
    
}
