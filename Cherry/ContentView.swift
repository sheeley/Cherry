//
//  ContentView.swift
//  Ambar
//
//  Created by Anagh Sharma on 12/11/19.
//  Copyright © 2019 Anagh Sharma. All rights reserved.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var state: State
    
    var buttons: some View {
        HStack {
            Button("Quit", action: {
                NSApplication.shared.terminate(self)
            })
            
            Spacer()
            
            if state.running {
                Button("Pause", action: { state.pause() })
            } else {
                Button("Start", action: { state.play() })
            }
            
            Button("Reset", action: { state.reset() })
                .disabled(!(state.hasStarted || state.isCooldown))
        }
    }
    
    var settings: some View {
        Form {
            Section(header: Text("Settings")) {
                Picker("Work Time", selection: $state.regularMinutes) {
#if DEBUG
                    Text("5 seconds").tag(-5)
#endif
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                    Text("20").tag(20)
                    Text("25").tag(25)
                    Text("30").tag(30)
                }.onChange(of: state.regularMinutes) { _ in
                    state.reset(timeOnly: true)
                }
                
                Picker("Break Time", selection: $state.cooldownMinutes) {
#if DEBUG
                    Text("5 seconds").tag(-5)
#endif
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                    Text("20").tag(20)
                    Text("25").tag(25)
                    Text("30").tag(30)
                }.onChange(of: state.cooldownMinutes) { _ in
                    state.reset(timeOnly: true)
                }
                Picker("Session End Sound", selection: $state.endSound) {
#if DEBUG
                    
#endif
                    ForEach(endSounds.allCases) { sound in
                        Text(sound.rawValue).tag(sound)
                    }
                }.onChange(of: state.cooldownMinutes) { _ in
                    state.reset(timeOnly: true)
                }
                
                //                TextField("Running Label", text: $state.runCharacter)
                //                TextField("Cooldown Label", text: $state.cooldownCharacter)
                //                TextField("Pause Label", text: $state.pauseCharacter)
                
                Slider(value: $state.volume, in: 0.0...1.0) {
                    Text("Volume")
                }
                
//                Slider(value: $state.volume, in: 0.0...1.0) {
//                    Text("Session end volume")
//                }
                
                Toggle("Automaticaly start next session", isOn: $state.doesContinueAutomatically)
                
                
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            settings.padding()
            buttons.padding()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(state: State())
    }
}
