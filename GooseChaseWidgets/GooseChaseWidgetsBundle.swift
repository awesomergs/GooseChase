//
//  GooseChaseWidgetsBundle.swift
//  GooseChaseWidgets: holds only the Live Activity (Lock Screen, Dynamic Island, Watch Smart Stack).
//

import WidgetKit
import SwiftUI

@main
struct GooseChaseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HuntLiveActivity()
    }
}
