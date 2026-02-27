//
//  JudgeE2App.swift
//  JudgeE2
//
//  Created by Jian Sun on 2/26/26.
//

import SwiftUI

@main
struct JudgeE2App: App {
    init() {
        ModelLoader.testLoad()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
