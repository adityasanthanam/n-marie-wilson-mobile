import 'dart:convert';

import 'package:flutter/services.dart';

/// App configuration.
///
/// Values come from `--dart-define-from-file=config/env.json` when that flag
/// is passed. Otherwise [load] reads the default `config/env.json` asset so a
/// plain `flutter run` / Xcode Run works locally.
///
/// `config/env.json` is gitignored; copy `config/env.example.json`.
class Config {
  static const _definedSiteUrl = String.fromEnvironment('SITE_URL');
  static const _definedCitizenApiKey = String.fromEnvironment('CITIZEN_API_KEY');
  static const _definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _definedSupabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static String siteUrl = _definedSiteUrl;
  static String citizenApiKey = _definedCitizenApiKey;
  static String supabaseUrl = _definedSupabaseUrl;
  static String supabaseKey = _definedSupabaseKey;

  static String get apiBase => '$siteUrl/api/public/v1';

  static List<String> get missing => [
        if (siteUrl.isEmpty) 'SITE_URL',
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
      ];

  static Future<void> load() async {
    if (missing.isEmpty) return;
    try {
      final raw = await rootBundle.loadString('config/env.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      String read(String key, String current) =>
          current.isNotEmpty ? current : '${map[key] ?? ''}';
      siteUrl = read('SITE_URL', siteUrl);
      citizenApiKey = read('CITIZEN_API_KEY', citizenApiKey);
      supabaseUrl = read('SUPABASE_URL', supabaseUrl);
      supabaseKey = read('SUPABASE_PUBLISHABLE_KEY', supabaseKey);
    } catch (_) {
      // File missing or invalid; [missing] stays populated for the startup screen.
    }
  }
}
