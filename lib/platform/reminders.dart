// Local reminders through our own Android code (MainActivity "ledgerlock/files" + Reminders.kt). No plugin.
import 'package:flutter/services.dart';

import '../tax/checkin.dart';

const _ch = MethodChannel('ledgerlock/files');

/// Asks for notification permission (Android 13+). True if allowed.
Future<bool> requestNotificationPermission() async {
  try {
    return await _ch.invokeMethod<bool>('requestNotifications') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Replaces the whole schedule (empty list = cancel all). Never throws.
Future<void> scheduleReminders(List<ReminderItem> items) async {
  try {
    if (items.isEmpty) {
      await _ch.invokeMethod('cancelReminders');
    } else {
      await _ch.invokeMethod('scheduleReminders', {
        'items': [for (final i in items) i.toMap()],
      });
    }
  } on MissingPluginException {
    // Tests / desktop: nothing to schedule.
  } on PlatformException {
    // Reminders are a convenience; never block the app on them.
  }
}
