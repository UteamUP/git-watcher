import Cocoa
import FlutterMacOS

/// A small item in the macOS menu bar that shows what the watched repositories are doing:
/// uncommitted work, commits waiting to be pushed and running pipelines.
///
/// The item keeps the app alive when the window is closed, opens a panel with the details when
/// the mouse rests on it, and brings the window back when it is clicked twice.
final class MenuBarController: NSObject {

  /// The main app talks to the menu bar over this channel.
  static let channelName = "gitwatcher/menubar"
  /// The panel inside the menu bar window talks over this channel.
  static let panelChannelName = "gitwatcher/menubar/panel"

  private static let panelWidth: CGFloat = 400
  private static let panelGap: CGFloat = 8
  private static let iconSize: CGFloat = 17

  /// How long the mouse may be away before the panel closes.
  private static let closeDelay: TimeInterval = 2

  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private var panel: NSPanel!
  private var panelEngine: FlutterEngine!
  private var panelChannel: FlutterMethodChannel!
  private var mainChannel: FlutterMethodChannel!
  private var pollTimer: Timer?
  private var closeTimer: Timer?
  private var appearanceObservation: NSKeyValueObservation?

  /// The last snapshot the app sent, so the panel can ask for it when it starts.
  private var latestSnapshot: Any?

  /// The counts drawn on the menu bar icon.
  private var dirty = 0
  private var ahead = 0
  private var ciRunning = 0
  private var ciFailed = 0

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    mainChannel = FlutterMethodChannel(name: MenuBarController.channelName, binaryMessenger: messenger)
    mainChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleMain(call: call, result: result)
    }
    startPanel()
    buildIcon()
    watchMouse()
  }

  deinit {
    pollTimer?.invalidate()
    closeTimer?.invalidate()
  }

  // MARK: - The main app

  private func handleMain(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateSummary":
      let args = call.arguments as? [String: Any] ?? [:]
      dirty = args["dirty"] as? Int ?? 0
      ahead = args["ahead"] as? Int ?? 0
      ciRunning = args["ciRunning"] as? Int ?? 0
      ciFailed = args["ciFailed"] as? Int ?? 0
      buildIcon()
      result(nil)
    case "snapshot":
      // The panel runs in its own engine, so the snapshot travels through here.
      latestSnapshot = call.arguments
      panelChannel.invokeMethod("snapshot", arguments: call.arguments)
      result(nil)
    case "showWindow":
      showMainWindow()
      result(nil)
    case "quit":
      NSApp.terminate(nil)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - The panel

  private func startPanel() {
    panelEngine = FlutterEngine(name: "gitwatcher-panel", project: nil, allowHeadlessExecution: false)

    let controller = FlutterViewController(engine: panelEngine, nibName: nil, bundle: nil)
    // A clear background lets the panel draw its own shape over the desktop.
    controller.backgroundColor = .clear
    controller.view.wantsLayer = true
    controller.view.layer?.isOpaque = false

    panelChannel = FlutterMethodChannel(name: MenuBarController.panelChannelName, binaryMessenger: panelEngine.binaryMessenger)
    panelChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "action":
        // The panel has no git of its own: the main app does the work and answers.
        self.mainChannel.invokeMethod("action", arguments: call.arguments)
        result(nil)
      case "getSnapshot":
        // The panel may start after the app has already sent a snapshot.
        result(self.latestSnapshot)
      case "getAppearance":
        result(self.appearanceName())
      case "getMaxHeight":
        result(self.maxPanelHeight)
      case "resize":
        // The panel asks for the height it needs, so all of it is seen without scrolling.
        let args = call.arguments as? [String: Any] ?? [:]
        let wanted = args["height"] as? Double ?? 0
        let height = min(max(wanted, 240), self.maxPanelHeight)
        if abs(self.panel.frame.height - height) > 1 {
          self.panel.setFrame(self.panelFrame(height: height), display: true)
        }
        result(height)
      case "close":
        self.hidePanel()
        result(nil)
      case "quit":
        NSApp.terminate(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // The engine only runs once a view controller is attached to it.
    panelEngine.run(withEntrypoint: "menuBarPanel")

    // The panel is a window of its own, so its size and place are ours to decide.
    // It needs a title bar in the style mask: a borderless window cannot become the key
    // window, and then the clicks and the scroll wheel never reach the panel.
    panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: NSSize(width: MenuBarController.panelWidth, height: 300)),
      styleMask: [.titled, .resizable, .nonactivatingPanel],
      backing: .buffered,
      defer: false)
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.styleMask.insert(.fullSizeContentView)
    panel.isFloatingPanel = true
    panel.level = .popUpMenu
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    panel.acceptsMouseMovedEvents = true
    // The Flutter view does not take the first click, so the panel has to be the key window
    // before the click lands. Otherwise the click is swallowed and nothing happens.
    panel.becomesKeyOnlyIfNeeded = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentViewController = controller

    // The material follows the system, so the panel has to know when the look changes.
    appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
      guard let self else { return }
      DispatchQueue.main.async {
        self.panelChannel.invokeMethod("appearance", arguments: self.appearanceName())
      }
    }
  }

  /// "dark" or "light", so the panel can use text that reads on the background of macOS.
  private func appearanceName() -> String {
    let match = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
    return match == .darkAqua ? "dark" : "light"
  }

  /// How tall the panel may grow: the screen, with room for the menu bar above.
  private var maxPanelHeight: Double {
    let screen = NSScreen.screens.first ?? NSScreen.main
    return max(320, (screen?.visibleFrame.height ?? 900) - 60)
  }

  private func showPanel() {
    positionPanel(height: panel.frame.height)
    panel.orderFrontRegardless()
    panel.makeKey()
    startPolling()
  }

  private func hidePanel() {
    closeTimer?.invalidate()
    closeTimer = nil
    pollTimer?.invalidate()
    pollTimer = nil
    panel.orderOut(nil)
    // The panel took the key from the window of the app, so it gets it back.
    if NSApp.isActive {
      for window in NSApp.windows where window is MainFlutterWindow {
        window.makeKey()
        break
      }
    }
  }

  /// Where the panel stands: under the menu bar item, centred on it and always on its screen.
  private func panelFrame(height: CGFloat) -> NSRect {
    let width = MenuBarController.panelWidth
    guard let button = statusItem.button, let window = button.window else {
      return NSRect(x: 0, y: 0, width: width, height: height)
    }
    let buttonFrame = window.convertToScreen(button.frame)
    var frame = NSRect(x: buttonFrame.midX - width / 2, y: buttonFrame.minY - height - MenuBarController.panelGap, width: width, height: height)
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(buttonFrame) }) ?? NSScreen.main {
      let visible = screen.visibleFrame
      if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
      if frame.minX < visible.minX { frame.origin.x = visible.minX }
      if frame.minY < visible.minY { frame.origin.y = visible.minY }
    }
    return frame
  }

  private func positionPanel(height: CGFloat) {
    panel.setFrame(panelFrame(height: height), display: true)
  }

  /// The panel follows the mouse: it closes two seconds after the mouse has left both the panel
  /// and the menu bar, and stays open as long as the mouse comes back.
  private func startPolling() {
    pollTimer?.invalidate()
    pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
      guard let self, self.panel.isVisible else { return }
      let mouse = NSEvent.mouseLocation
      if self.panel.frame.contains(mouse) {
        // macOS sends the scroll wheel to the key window, so the panel has to be that one
        // while the mouse is on it.
        if !self.panel.isKeyWindow {
          self.panel.makeKey()
        }
        self.closeTimer?.invalidate()
        self.closeTimer = nil
        return
      }
      if self.menuArea.contains(mouse) {
        self.closeTimer?.invalidate()
        self.closeTimer = nil
        return
      }
      guard self.closeTimer == nil else { return }
      self.closeTimer = Timer.scheduledTimer(withTimeInterval: MenuBarController.closeDelay, repeats: false) { [weak self] _ in
        self?.hidePanel()
      }
    }
  }

  /// The menu bar of the screen the mouse is on. The panel stays open as long as the mouse
  /// rests there, the way a menu of macOS stays while the mouse is on it.
  private var menuArea: NSRect {
    let mouse = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
      return .zero
    }
    let top = screen.frame.maxY - 30
    return NSRect(x: screen.frame.minX, y: top, width: screen.frame.width, height: screen.frame.height - top)
  }

  // MARK: - The icon

  /// The app icon with a badge that says how much is waiting.
  private func buildIcon() {
    let size = NSSize(width: MenuBarController.iconSize, height: MenuBarController.iconSize)
    let image = NSImage(size: size)
    image.lockFocus()
    if let iconBase = appIcon() {
      iconBase.draw(
        in: NSRect(x: 0, y: 0, width: size.width, height: size.height),
        from: .zero,
        operation: .sourceOver,
        fraction: 1)
    }

    let waiting = dirty + ahead + ciFailed
    let badge = waiting > 0 ? waiting : ciRunning
    if badge > 0 {
      let color: NSColor
      if ciFailed > 0 {
        color = NSColor(srgbRed: 0.85, green: 0.18, blue: 0.31, alpha: 1)
      } else if dirty > 0 {
        color = NSColor(srgbRed: 0.76, green: 0.25, blue: 0.05, alpha: 1)
      } else {
        color = NSColor(srgbRed: 0.10, green: 0.42, blue: 0.71, alpha: 1)
      }
      let radius: CGFloat = 6
      let center = NSPoint(x: size.width - radius + 1, y: radius - 1)
      let badgeRect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
      color.setFill()
      NSBezierPath(ovalIn: badgeRect).fill()
      NSColor.white.withAlphaComponent(0.95).setStroke()
      let ring = NSBezierPath(ovalIn: badgeRect.insetBy(dx: 0.5, dy: 0.5))
      ring.lineWidth = 1
      ring.stroke()
      if badge < 10 {
        let text = "\(badge)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
          .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
          .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
          at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2),
          withAttributes: attributes)
      }
    }
    image.unlockFocus()

    statusItem.button?.image = image
    statusItem.button?.imagePosition = .imageOnly
  }

  /// The app icon, from the bundle so it is there even before the system has it.
  private func appIcon() -> NSImage? {
    if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
       let image = NSImage(contentsOfFile: path) {
      return image
    }
    return NSApp.applicationIconImage
  }

  // MARK: - The mouse

  private func watchMouse() {
    guard let button = statusItem.button else { return }
    button.target = self
    button.action = #selector(statusItemClicked(_:))
    button.sendAction(on: [.leftMouseUp])
    let area = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil)
    button.addTrackingArea(area)
  }

  /// The mouse rested on the menu bar item: show the panel.
  @objc(mouseEntered:)
  func mouseEntered(with event: NSEvent) {
    showPanel()
  }

  /// The mouse left the menu bar item. The panel stays until the mouse has been away for a while.
  @objc(mouseExited:)
  func mouseExited(with event: NSEvent) {
    closeTimer?.invalidate()
    closeTimer = nil
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    if NSApp.currentEvent?.clickCount == 2 {
      showMainWindow()
      return
    }
    // A click keeps the panel open. It closes on its own when the mouse stays away.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
      guard let self, !self.panel.isVisible else { return }
      self.showPanel()
    }
  }

  private func showMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    for window in NSApp.windows {
      if window is MainFlutterWindow {
        window.makeKeyAndOrderFront(nil)
        return
      }
    }
  }
}
