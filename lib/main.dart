import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Config.missing.isNotEmpty) {
    runApp(_MissingConfig(Config.missing));
    return;
  }
  await Future.wait([
    Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey),
    initializeDateFormatting('en_IN'),
    initializeDateFormatting('ta_IN'),
  ]);
  final lang = await Lang.load();
  runApp(MarieWilsonApp(lang: lang));
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig(this.missing);
  final List<String> missing;
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Missing build configuration: ${missing.join(', ')}.\n\n'
                'Run with: flutter run --dart-define-from-file=config/env.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
