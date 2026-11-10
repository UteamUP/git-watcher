import 'package:flutter/services.dart';

/// The channel between the app and the native menu bar item.
class MenuBarBridge {
  MenuBarBridge._();

  static const _channel = MethodChannel('gitwatcher/menubar');

  /// The native side calls this when the panel asks the app to do something.
  static Future<void> Function(MethodCall call)? handler;

  static void listen() {
    _channel.setMethodCallHandler((call) async {
      final onCall = handler;
      if (onCall != null) await onCall(call);
    });
  }

  /// The counts the menu bar icon wears as a badge.
  static Future<void> updateSummary({
    required int dirty,
    required int ahead,
    required int ciRunning,
    required int ciFailed,
  }) =>
      _channel.invokeMethod<void>('updateSummary', {
        'dirty': dirty,
        'ahead': ahead,
        'ciRunning': ciRunning,
        'ciFailed': ciFailed,
      });

  /// The whole picture, for the panel in the menu bar.
  static Future<void> sendSnapshot(Map<String, dynamic> snapshot) =>
      _channel.invokeMethod<void>('snapshot', snapshot);

  static Future<void> showWindow() => _channel.invokeMethod<void>('showWindow');

  static Future<void> quit() => _channel.invokeMethod<void>('quit');
}

/// The channel between the panel and the native menu bar item.
class MenuBarPanelBridge {
  MenuBarPanelBridge._();

  static const _channel = MethodChannel('gitwatcher/menubar/panel');

  /// The native side pushes a new snapshot into the panel.
  static Future<void> listen(
    void Function(Map<String, dynamic> snapshot) onSnapshot, {
    void Function(String appearance)? onAppearance,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'snapshot') {
        final args = call.arguments;
        if (args is Map) onSnapshot(args.cast<String, dynamic>());
      }
      if (call.method == 'appearance') {
        final name = call.arguments;
        if (name is String) onAppearance?.call(name);
      }
    });
    // The panel may start after the app has already sent a snapshot.
    final current = await _channel.invokeMethod<Map<Object?, Object?>>('getSnapshot');
    if (current != null) onSnapshot(current.cast<String, dynamic>());
    // The material of the panel follows the system, so the text has to follow it too.
    final look = await _channel.invokeMethod<String>('getAppearance');
    if (look != null) onAppearance?.call(look);
  }

  /// Asks the main app to do something. The panel has no git of its own.
  static Future<void> action(String method, {String? path}) =>
      _channel.invokeMethod<void>('action', {'method': method, 'path': ?path});

  static Future<void> quit() => _channel.invokeMethod<void>('quit');
}
