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
import AVFoundation
import MusicKit

fileprivate let formatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.allowedUnits = [.minute, .second]
    return f
}()

class State: NSObject, ObservableObject {
    // MARK: - Current State
    var statusItem: NSStatusItem?
    @Published private(set) var timer: AnyCancellable?
    @Published var secondsLeft = TimeInterval(0)
    @Published var isCooldown = false
    @Published var hasStarted = false
    @Published var running = false
    
    // MARK: - Settings
    @Published var doesContinueAutomatically = false
    @Published var volume: Float = 1.0
    @Published var endSound = endSounds.None
    
#if DEBUG
    @Published var regularMinutes = -5
    @Published var cooldownMinutes = -2
#else
    @Published var regularMinutes = 25
    @Published var cooldownMinutes = 5
#endif
    //    @Published var pauseCharacter = "⏸"
    //    @Published var runCharacter = "🏃🏻‍♂️"
    //    @Published var cooldownCharacter = "❄️"
    
    private var ccl: AnyCancellable? = nil
    
    override init() {
        super.init()
        ccl = $volume.sink(receiveValue: { newVolume in
            backgroundNoise.setVolume(newVolume)
        })
    }
}

//let backgroundNoise = Player(url: Bundle.main.url(forResource: "Coffee-shop-background-noise", withExtension: "mp3")!)
let backgroundNoise = Player(url: Bundle.main.url(forResource: "562863__buzzatsea__coffee-shop-sounds-2", withExtension: "m4a")!)


enum endSounds: String {
    case None, Basso, Blow, Bottle, Froge, Funk, Glass, Hero, More, Ping, Purr, Sosumi, Submarine, Tink
    
    func play(at volume: Float) {
        guard self != .None else { return }
        let endSound = NSSound(named: self.rawValue)!
        endSound.volume = volume
        endSound.play()
    }
}

extension endSounds: CaseIterable, Identifiable {
    var id: String { rawValue }
}

var endSound = endSounds.None

struct Player {
    private let player: AVAudioPlayer?
    
    init(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
        } catch let error as NSError {
            print(error.description)
            player = nil
        }
    }
    
    func setVolume(_ volume: Float) {
        player?.setVolume(volume, fadeDuration: 0.0)
    }
    
    func play(at volume: Float) {
        guard let player = player else { return }
        player.volume = 0.0
        player.prepareToPlay()
        player.play()
        player.setVolume(volume, fadeDuration: 2.0)
    }
    
    func stop() {
        guard let player = player else { return }
        player.setVolume(0.0, fadeDuration: 1.0)
        DispatchQueue.main.async {
            sleep(1)
            player.stop()
        }
    }
}

// TODO: play/stop Music instead of white noise
//extension Player {
//    func playMusic() {
//        let player = MPMusicPlayerController.system
//    }
//}

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
                    if self.secondsLeft == 1 {
                        self.sendNotification()
                    }
                }
                self.setTitle()
            }
        running = true
        hasStarted = true
        setTitle()
        
        guard !isCooldown else { return }
        backgroundNoise.play(at: volume)
    }
    
    func pause() {
        backgroundNoise.stop()
        timer?.cancel()
        timer = nil
        running = false
        setTitle()
    }
    
    func end() {
        backgroundNoise.stop()
        if !isCooldown {
            endSound.play(at: volume)
        }
        
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
        case startNext:
            DispatchQueue.main.async {
                self.play()
            }
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
                let previousSession = self.isCooldown ? "Break" : "Focus"
                let minutes = self.isCooldown ? self.cooldownMinutes : self.regularMinutes
                
                let content = UNMutableNotificationContent()
                content.sound = .default
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

// MARK: - Notifications
let startNext = "START_NEXT"
let startNextAction = UNNotificationAction(identifier: startNext,
                                           title: "Start Next",
                                           options: UNNotificationActionOptions(rawValue: 0))
let categoryId = "START_NEXT"
let startNextCategory = UNNotificationCategory(identifier: categoryId,
                                               actions: [startNextAction],
                                               intentIdentifiers: [],
                                               hiddenPreviewsBodyPlaceholder: "",
                                               options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle])
