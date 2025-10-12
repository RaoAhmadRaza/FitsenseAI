import 'package:hive/hive.dart';
import '../../features/altrix/utils/altrix_constants.dart';
import 'encryption_service.dart';

class LocalStorageService {
  LocalStorageService({EncryptionService? encryption})
    : _encryption = encryption ?? const EncryptionService();

  final EncryptionService _encryption;

  Future<Box<T>> openEncryptedBox<T>(String name) async {
    final cipher = await _encryption.getCipher(AltrixConstants.hiveKeyName);
    if (Hive.isBoxOpen(name)) {
      // If already open unencrypted, migrate by re-opening encrypted
      final box = Hive.box(name);
      if (!box.isOpen) await box.close();
      await Hive.deleteBoxFromDisk(name);
    }
    return Hive.openBox<T>(name, encryptionCipher: cipher);
  }

  Future<Box> openEncryptedDynamicBox(String name) async {
    final cipher = await _encryption.getCipher(AltrixConstants.hiveKeyName);
    return Hive.openBox(name, encryptionCipher: cipher);
  }
}
