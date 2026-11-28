import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:assistant/data/app_controller.dart';

/// Wednesday. Group 1 of the demo seed meets on the clock's weekday.
final DateTime testNow = DateTime(2026, 11, 25, 17, 30);

/// Creates a container backed by in-memory preferences and a fixed clock.
///
/// Pass the same [prefs] to simulate an app restart.
Future<(ProviderContainer, SharedPreferences)> makeContainer({
  SharedPreferences? prefs,
  DateTime? now,
}) async {
  SharedPreferences p;
  if (prefs != null) {
    p = prefs;
  } else {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    p = await SharedPreferences.getInstance();
  }
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(p),
      clockProvider.overrideWithValue(() => now ?? testNow),
    ],
  );
  return (container, p);
}
