//
//  ShellPage.swift
//  Taskr
//
//  Placeholder shown for pages that haven't been built yet.
//

import SwiftUI

/// Placeholder until each page is built from its artboard in the design.
struct ShellPage: View {
    let page: Page

    var body: some View {
        ContentUnavailableView(page.title, systemImage: page.symbol,
                               description: Text("Not built yet. See the \(page.title) artboard."))
            .navigationTitle(page.title)
    }
}
