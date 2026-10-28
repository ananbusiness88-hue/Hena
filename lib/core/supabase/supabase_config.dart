import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static String get mode {
    return const String.fromEnvironment('SUPABASE_MODE', defaultValue: 'local');
  }

  static bool get isProduction => mode == 'production';

  static String get url {
    final key = isProduction ? 'SUPABASE_PRODUCTION_URL' : 'SUPABASE_LOCAL_URL';

    final value = dotenv.env[key];

    if (value == null || value.isEmpty) {
      throw StateError('$key is not configured for $mode mode.');
    }

    return value;
  }

  static String get publishableKey {
    final key = isProduction
        ? 'SUPABASE_PRODUCTION_PUBLISHABLE_KEY'
        : 'SUPABASE_LOCAL_PUBLISHABLE_KEY';

    final value = dotenv.env[key];

    if (value == null || value.isEmpty) {
      throw StateError('$key is not configured for $mode mode.');
    }

    return value;
  }
}
