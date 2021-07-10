//
//  State.swift
//  Ambar
//
//  Created by Johnny Sheeley on 7/9/21.
//  Copyright © 2021 Golden Chopper. All rights reserved.
//

import SwiftUI
import Combine

fileprivate let formatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.allowedUnits = [.minute, .second]
    return f
}()

class State: ObservableObject {
    var statusItem: NSStatusItem?
    @Published private(set) var timer: AnyCancellable?
    @Published var secondsLeft = TimeInterval(0)
    @Published var isCooldown = false
    @Published var hasStarted = false
    @Published var running = false
    
    // Settings
    @Published var doesContinueAutomatically = true
    @Published var pauseCharacter = "⏸"
    @Published var runCharacter = "🏃🏻‍♂️"
    @Published var cooldownCharacter = "❄️"
    @Published var regularMinutes = 25
    @Published var cooldownMinutes = 5
}

// MARK: - Label & Image
extension State {
    var label: String {
        guard running else {
            return pauseCharacter
        }
        
        guard isCooldown else {
            return runCharacter
        }
        
        return cooldownCharacter
    }
    
    var image: NSImage? {
        guard timer != nil else {
            // no timer, paused
            return NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Pause Cherry")
        }
        
        guard isCooldown else {
            // regular run
            return NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Pause Cherry")
        }
    
        // cooldown
        return NSImage(systemSymbolName: "powersleep", accessibilityDescription: "Pause Break")
    }
    
    func setTitle() {
        guard let button = statusItem?.button else { return }
        
        button.title = formatter.string(from: secondsLeft) ?? ""
        button.image = image
        button.imagePosition = .imageLeading
    }
}

// MARK: - Commands
extension State {
    
    func toggle() {
        guard timer != nil else {
            play()
            return
        }
        pause()
    }
    
    func play() {
        timer = Timer.publish(every: 1, on: .main, in: .default)
            .autoconnect()
            .sink { _ in
                guard self.secondsLeft > 0 else {
                    self.end()
                    return
                }
                if self.secondsLeft > 0 {
                    self.secondsLeft = self.secondsLeft - 1
                }
                self.setTitle()
            }
        running = true
        hasStarted = true
        setTitle()
    }
    
    func pause() {
        timer?.cancel()
        timer = nil
        running = false
        setTitle()
    }
    
    func end() {
        isCooldown.toggle()
        reset(timeOnly: true)
        setTitle()
        if doesContinueAutomatically {
            play()
        }
    }
    
    func reset(timeOnly: Bool = false) {
        if !timeOnly {
            isCooldown = false
        }
        pause()
        
        let minutesToRun = isCooldown ? cooldownMinutes : regularMinutes
        secondsLeft = Double(minutesToRun) * 60.0
        hasStarted = false
        setTitle()
    }
}
