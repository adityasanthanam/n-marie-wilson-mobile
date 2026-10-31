import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the web's LanguageProvider: `en` default, persisted as `mw-lang`,
/// dictionary from src/i18n/dict.ts (exported to assets/i18n/dict.json).
class Lang extends ChangeNotifier {
  Lang._(this._dict, this.code);

  static late Lang instance;
  final Map<String, dynamic> _dict;
  String code;

  bool get ta => code == 'ta';
  Locale get locale => Locale(code, 'IN');
  String get dateLocale => ta ? 'ta_IN' : 'en_IN';

  static Future<Lang> load() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/i18n/dict.json')) as Map<String, dynamic>;
    var code = 'en';
    try {
      code = (await SharedPreferences.getInstance()).getString('mw-lang') ?? 'en';
    } catch (_) {}
    return instance = Lang._(raw, code == 'ta' ? 'ta' : 'en');
  }

  /// Test/preview constructor.
  static Lang forTest(Map<String, dynamic> dict, [String code = 'en']) => instance = Lang._(dict, code);

  Future<void> set(String c) async {
    code = c;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString('mw-lang', c);
    } catch (_) {}
  }

  /// Dictionary lookup by dotted path, e.g. `t('hero.ctaNew')`.
  String t(String path) {
    dynamic node = _dict[code];
    for (final k in path.split('.')) {
      node = node is Map ? node[k] : null;
    }
    if (node is String) return node;
    if (code != 'en') {
      dynamic en = _dict['en'];
      for (final k in path.split('.')) {
        en = en is Map ? en[k] : null;
      }
      if (en is String) return en;
    }
    return path;
  }

  String date(DateTime d, {bool long = false}) =>
      (long ? DateFormat.yMMMMd(dateLocale) : DateFormat.yMMMd(dateLocale)).format(d.toLocal());
  String dateTime(DateTime d) => DateFormat.yMMMd(dateLocale).add_jm().format(d.toLocal());
}

/// Inline bilingual string, same as the web's `L(lang, en, ta)`.
String L(String en, String ta) => Lang.instance.ta ? ta : en;
String t(String path) => Lang.instance.t(path);

DateTime? parseDate(dynamic v) => v is String ? DateTime.tryParse(v) : null;

class LangScope extends InheritedNotifier<Lang> {
  const LangScope({super.key, required Lang lang, required super.child}) : super(notifier: lang);
  static Lang of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<LangScope>()!.notifier!;
}
