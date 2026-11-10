import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// The messenger of the engine that runs the app, for the menu bar item.
  static var messenger: FlutterBinaryMessenger?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    MainFlutterWindow.messenger = flutterViewController.engine.binaryMessenger

    // Transparent, unified title bar so the Flutter UI runs under the traffic lights.
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.toolbar = NSToolbar(identifier: "GITWatcherToolbar")
    self.toolbarStyle = .unified
    self.minSize = NSSize(width: 760, height: 620)
    if !self.setFrameUsingName("GITWatcherMainWindow") {
      self.setContentSize(NSSize(width: 1560, height: 960))
      self.center()
    }
    self.setFrameAutosaveName("GITWatcherMainWindow")

    let channel = FlutterMethodChannel(
      name: "gitwatcher/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "startDrag", let self, let event = NSApp.currentEvent {
        self.performDrag(with: event)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
    // The menu bar item needs this engine, so it can start as soon as the window exists.
    (NSApp.delegate as? AppDelegate)?.startMenuBar()
  }

  /// The red button hides the window instead of closing it: the app keeps running in the menu bar.
  override func performClose(_ sender: Any?) {
    self.orderOut(sender)
  }

  /// The green button fills the screen. The menu bar stays, because the app lives there now.
  override func performZoom(_ sender: Any?) {
    guard let screen = self.screen ?? NSScreen.main else {
      super.performZoom(sender)
      return
    }
    let target = screen.visibleFrame
    let current = self.frame
    let already = abs(current.origin.x - target.origin.x) < 1
      && abs(current.origin.y - target.origin.y) < 1
      && abs(current.width - target.width) < 1
      && abs(current.height - target.height) < 1
    if already {
      super.performZoom(sender)
      return
    }
    self.setFrame(target, display: true)
  }
}
