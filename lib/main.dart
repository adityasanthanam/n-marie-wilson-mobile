import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/i18n.dart';
import 'widgets/brand_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Startup());
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  Widget? _ready;
  Widget? _destination;
  var _introDone = false;
  late final _splash = BrandSplash(onFinished: _onIntroFinished);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Config.load();
    if (!mounted) return;
    if (Config.missing.isNotEmpty) {
      _destination = _MissingConfig(Config.missing);
      _tryReveal();
      return;
    }
    await Future.wait([
      Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey),
      initializeDateFormatting('en_IN'),
      initializeDateFormatting('ta_IN'),
    ]);
    final lang = await Lang.load();
    if (!mounted) return;
    _destination = MarieWilsonApp(lang: lang);
    _tryReveal();
  }

  void _onIntroFinished() {
    _introDone = true;
    _tryReveal();
  }

  void _tryReveal() {
    if (_destination == null || !_introDone) return;
    setState(() => _ready = _destination);
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(key: ValueKey(_ready != null), child: _ready ?? _splash),
      );
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
                'Copy config/env.example.json to config/env.json and fill it in.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
