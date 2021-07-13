//
//  State.swift
//  Ambar
//
//  Created by Johnny Sheeley on 7/9/21.
//  Copyright © 2021 Golden Chopper. All rights reserved.
//

import SwiftUI
import Combine
import UserNotifications

fileprivate let formatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.allowedUnits = [.minute, .second]
    return f
}()

class State: NSObject, ObservableObject {
    var statusItem: NSStatusItem?
    @Published private(set) var timer: AnyCancellable?
    @Published var secondsLeft = TimeInterval(0)
    @Published var isCooldown = false
    @Published var hasStarted = false
    @Published var running = false
    
    // Settings
    @Published var doesContinueAutomatically = true
//    @Published var pauseCharacter = "⏸"
//    @Published var runCharacter = "🏃🏻‍♂️"
//    @Published var cooldownCharacter = "❄️"
    #if DEBUG
    @Published var regularMinutes = -5
    #else
    @Published var regularMinutes = 25
    #endif
    @Published var cooldownMinutes = 5
}

// MARK: - Label & Image
extension State {
//    var label: String {
//        guard running else {
//            return pauseCharacter
//        }
//
//        guard isCooldown else {
//            return runCharacter
//        }
//
//        return cooldownCharacter
//    }
    
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
        sendNotification()
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
        #if DEBUG
        if minutesToRun < 0 {
            secondsLeft = Double(minutesToRun) * -1.0
        }
        #endif
        hasStarted = false
        setTitle()
    }
}

extension State: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if hasStarted {
            return
        }
        switch response.actionIdentifier {
        case startBreakId:
//           if isCooldown {
            DispatchQueue.main.async {
                self.play()
            }
//           }
//        case startFocusId:
//           if !isCooldown {
//               play()
//           }
        default:
           break
        }
    }
    
    func sendNotification() {
        let center = UNUserNotificationCenter.current()
        var options: UNAuthorizationOptions = [.alert, .sound, .badge , .provisional]
        if #available(macOS 12.0, *) {
            options.update(with: .timeSensitive)
        }
        
        center.requestAuthorization(options: options) { granted, error in
            guard let error = error else { return }
            print(error)
        }
        
        center.getNotificationSettings() { settings in
            let allowed: Set<UNAuthorizationStatus> = [.authorized, .provisional]
            if allowed.contains(settings.authorizationStatus) {
                // these are opposite because the state has already flipped
                let previousSession = !self.isCooldown ? "Break" : "Focus"
                let minutes = !self.isCooldown ? self.cooldownMinutes : self.regularMinutes
                
                let content = UNMutableNotificationContent()
                content.title = "\(previousSession) finished"
                content.body = "\(minutes) minutes completed."
                if !self.doesContinueAutomatically {
                    content.categoryIdentifier = categoryId
                }
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: "BOOM", content: content, trigger: trigger)
                center.add(request) { error in
                    guard let error = error else { return }
                    print(error)
                }
            }
        }
    }
}

let startBreakId = "START_BREAK"
//let startFocusId = "START_FOCUS"
let startBreakAction = UNNotificationAction(identifier: startBreakId,
      title: "Start Next",
      options: UNNotificationActionOptions(rawValue: 0))

//let startFocusAction = UNNotificationAction(identifier: startFocusId,
//      title: "Start Pomodoro",
//      options: UNNotificationActionOptions(rawValue: 0))

let categoryId = "START_NEXT"
let startNextCategory = UNNotificationCategory(identifier: categoryId,
                                               actions: [startBreakAction], // , startFocusAction],
                                               intentIdentifiers: [],
                                               hiddenPreviewsBodyPlaceholder: "",
                                               options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle])
