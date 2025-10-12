/// Centralized constants for Altrix feature.
class AltrixConstants {
  // Hive box names
  static const String threadsBox = 'altrix_threads';
  static const String messagesBox = 'altrix_messages';
  static const String analyticsBox = 'altrix_analytics';
  static const String settingsBox = 'settingsBox';

  // Hive encryption key identifiers (stored via flutter_secure_storage)
  static const String hiveKeyName = 'hive_altrix_key_v1';

  // Hive typeIds (must be globally unique per app)
  // Note: existing project uses 10..17. We pick higher, reserved range for Altrix.
  static const int messageTypeId = 30;
  static const int threadTypeId = 31;

  // Assistant identity
  static const String assistantName = 'Altrix';
}
