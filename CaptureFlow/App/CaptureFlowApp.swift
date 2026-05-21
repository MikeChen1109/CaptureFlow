//
//  CaptureFlowApp.swift
//  CaptureFlow
//
//  Created by Mike Chen on 2026/5/11.
//

import SwiftUI
import UIKit

@main
struct CaptureFlowApp: App {
    private let container = AppContainer.local()

    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = UIColor(red: 1, green: 0.478, blue: 0.102, alpha: 1)
        navigationBar.overrideUserInterfaceStyle = .dark
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .preferredColorScheme(.dark)
        }
    }
}
