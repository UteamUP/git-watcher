import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private(set) var menuBar: MenuBarController?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    NSLog("[GITWatcher] didFinishLaunching windows=\(NSApp.windows.count)")
    for window in NSApp.windows {
      NSLog("[GITWatcher] window=\(type(of: window)) content=\(String(describing: window.contentViewController))")
    }
    startMenuBar()
  }

  /// The menu bar item needs the messenger of the engine that runs the app.
  /// The window may come before or after this callback, so both paths ask for it.
  func startMenuBar() {
    guard menuBar == nil else { return }
    guard let messenger = MainFlutterWindow.messenger else {
      NSLog("[GITWatcher] no messenger yet")
      return
    }
    menuBar = MenuBarController(messenger: messenger)
    NSLog("[GITWatcher] menu bar ready")
  }

  /// The window is hidden by its close button, so the app stays alive in the menu bar.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  /// Clicking the app in the Dock brings the window back.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in NSApp.windows where window is MainFlutterWindow {
        window.makeKeyAndOrderFront(nil)
        break
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
