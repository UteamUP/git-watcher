import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

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
  }
}
