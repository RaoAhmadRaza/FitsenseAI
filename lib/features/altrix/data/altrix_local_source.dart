import 'package:hive/hive.dart';
import '../models/altrix_message.dart';
import '../models/altrix_thread.dart';
import '../utils/altrix_constants.dart';
import '../../../core/services/local_storage_service.dart';

class AltrixLocalSource {
  AltrixLocalSource(this._storage);

  final LocalStorageService _storage;

  Box<AltrixThread>? _threads;
  Box<AltrixMessage>? _messages;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(AltrixConstants.messageTypeId)) {
      Hive.registerAdapter(AltrixMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(AltrixConstants.threadTypeId)) {
      Hive.registerAdapter(AltrixThreadAdapter());
    }
    _threads = await _storage.openEncryptedBox<AltrixThread>(
      AltrixConstants.threadsBox,
    );
    _messages = await _storage.openEncryptedBox<AltrixMessage>(
      AltrixConstants.messagesBox,
    );
  }

  Box<AltrixThread> get threadsBox =>
      _threads ?? (throw StateError('AltrixLocalSource not initialized'));
  Box<AltrixMessage> get messagesBox =>
      _messages ?? (throw StateError('AltrixLocalSource not initialized'));

  // Thread operations
  Future<void> upsertThread(AltrixThread t) async {
    await threadsBox.put(t.id, t);
  }

  Future<void> deleteThread(String id) async {
    // delete thread and its messages
    await threadsBox.delete(id);
    final keys = messagesBox.keys
        .whereType<String>()
        .where((k) => messagesBox.get(k)?.threadId == id)
        .toList();
    await messagesBox.deleteAll(keys);
  }

  List<AltrixThread> getAllThreads({bool includeArchived = false}) {
    final list = threadsBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return includeArchived ? list : list.where((t) => !t.archived).toList();
  }

  // Message operations
  Future<void> addMessage(AltrixMessage m) async {
    await messagesBox.put(m.id, m);
  }

  Future<void> updateMessage(AltrixMessage m) async {
    await messagesBox.put(m.id, m);
  }

  List<AltrixMessage> getMessagesForThread(String threadId) {
    final list =
        messagesBox.values.where((m) => m.threadId == threadId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }
}
