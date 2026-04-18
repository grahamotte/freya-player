import SwiftUI
import XCTest

#if canImport(UIKit)
import UIKit

@MainActor
func assertRenders<Content: View>(
    _ view: Content,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let window = UIWindow()
    let controller = UIHostingController(rootView: view)

    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.loadViewIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))

    XCTAssertNotNil(controller.view, file: file, line: line)
    window.isHidden = true
}
#endif
