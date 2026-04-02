import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'database/db_mobile.dart' if (dart.library.html) 'database/db_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await DatabaseHelper.instance.initialize();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}