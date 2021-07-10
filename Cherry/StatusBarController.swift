//
//  StatusBarController.swift
//  Ambar
//
//  Created by Anagh Sharma on 12/11/19.
//  Copyright © 2019 Anagh Sharma. All rights reserved.
//

import AppKit

class StatusBarController {
    private var statusBar: NSStatusBar
    var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: EventMonitor?
    let state: State
    
    init(_ popover: NSPopover, state: State) {
        self.popover = popover
        self.state = state
        statusBar = NSStatusBar()
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarButton = statusItem.button {
            statusBarButton.action = #selector(togglePopover(sender:))
            statusBarButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusBarButton.target = self
        }
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown], handler: mouseEventHandler)
    }
    
    @objc func togglePopover(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if popover.isShown {
                hidePopover(sender)
        } else {
            if event.type == .leftMouseUp {
                state.toggle()
            } else {
                showPopover(sender)
            }
        }
    }
    
    func showPopover(_ sender: AnyObject) {
        if let statusBarButton = statusItem.button {
            popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: NSRectEdge.maxY)
            eventMonitor?.start()
        }
    }
    
    func hidePopover(_ sender: AnyObject) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    func mouseEventHandler(_ event: NSEvent?) {
        guard let event = NSApp.currentEvent else { return }
        if(popover.isShown) {
            hidePopover(event)
        }
    }
}
