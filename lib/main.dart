import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assistant/app/app.dart';
import 'package:assistant/core/firebase/cache_warmer.dart';
import 'package:assistant/core/security/auth_controller.dart';
import 'package:assistant/core/security/auth_gateway.dart';
import 'package:assistant/core/security/key_value_store.dart';
import 'package:assistant/core/utils/cairo_time.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  initCairoTime();
  // Android reads its configuration from google-services.json.
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(SecureKeyValueStore()),
        authGatewayProvider.overrideWithValue(FirebaseAuthGateway()),
        cacheWarmerProvider.overrideWithValue(FirestoreCacheWarmer()),
      ],
      child: const MnaraApp(),
    ),
  );
}
