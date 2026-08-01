import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'data/local/items_local_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use bundled google_fonts assets only — avoid runtime font network fetches.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Hive must be ready before product providers read the local catalog.
  await ItemsLocalCache.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ProviderScope(child: RexApp()));
}
