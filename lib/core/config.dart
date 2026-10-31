/// Build-time configuration, supplied with
/// `flutter run --dart-define-from-file=config/env.json`.
/// Nothing secret is committed; see config/env.example.json.
class Config {
  static const siteUrl = String.fromEnvironment('SITE_URL');
  static const citizenApiKey = String.fromEnvironment('CITIZEN_API_KEY');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static String get apiBase => '$siteUrl/api/public/v1';

  static List<String> get missing => [
        if (siteUrl.isEmpty) 'SITE_URL',
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
      ];
}
