//
//  CaptureFlowApp.swift
//  CaptureFlow
//
//  Created by Mike Chen on 2026/5/11.
//

import SwiftUI

@main
struct CaptureFlowApp: App {
    private let container = AppContainer.prototype()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
