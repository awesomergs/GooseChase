//
//  QuarryWidgetsBundle.swift
//  QuarryWidgets: holds only the Live Activity (Lock Screen, Dynamic Island, Watch Smart Stack).
//

import WidgetKit
import SwiftUI

@main
struct QuarryWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HuntLiveActivity()
    }
}
