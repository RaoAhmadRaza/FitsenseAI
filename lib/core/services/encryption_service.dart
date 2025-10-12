import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Provides an app-wide encrypted key for Hive boxes.
class EncryptionService {
  const EncryptionService();

  Future<HiveAesCipher> getCipher(String keyName) async {
    const storage = FlutterSecureStorage();
    String? base64Key = await storage.read(key: keyName);
    if (base64Key == null) {
      final bytes = Hive.generateSecureKey();
      base64Key = base64Encode(bytes);
      await storage.write(key: keyName, value: base64Key);
    }
    return HiveAesCipher(base64Decode(base64Key));
  }
}
