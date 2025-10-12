import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/altrix_repository.dart';
import '../models/altrix_message.dart';
import '../models/altrix_thread.dart';

class AltrixState {
  final List<AltrixThread> threads;
  final String? activeThreadId;
  final List<AltrixMessage> messages;
  final bool loading;
  final String? error;

  const AltrixState({
    this.threads = const [],
    this.activeThreadId,
    this.messages = const [],
    this.loading = false,
    this.error,
  });

  AltrixState copyWith({
    List<AltrixThread>? threads,
    String? activeThreadId,
    List<AltrixMessage>? messages,
    bool? loading,
    String? error,
  }) => AltrixState(
    threads: threads ?? this.threads,
    activeThreadId: activeThreadId ?? this.activeThreadId,
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    error: error,
  );
}

class AltrixCubit extends Cubit<AltrixState> {
  AltrixCubit(this._repo) : super(const AltrixState());

  final AltrixRepository _repo;

  Future<void> init() async {
    emit(state.copyWith(loading: true));
    try {
      await _repo.init();
      final threads = _repo.getThreads();
      emit(state.copyWith(threads: threads, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> startNewChat(String firstMessage) async {
    emit(state.copyWith(loading: true));
    try {
      final thread = await _repo.createThread(firstMessage: firstMessage);
      await _repo.addUserMessage(thread.id, firstMessage);
      final reply = await _repo.generateAssistantReply(thread.id, firstMessage);
      await _repo.addAssistantMessage(thread.id, reply);
      final threads = _repo.getThreads();
      final messages = _repo.getMessages(thread.id);
      emit(
        AltrixState(
          threads: threads,
          activeThreadId: thread.id,
          messages: messages,
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> sendMessage(String content) async {
    final id = state.activeThreadId;
    if (id == null) return;
    emit(state.copyWith(loading: true));
    try {
      await _repo.addUserMessage(id, content);
      final reply = await _repo.generateAssistantReply(id, content);
      await _repo.addAssistantMessage(id, reply);
      final messages = _repo.getMessages(id);
      emit(state.copyWith(messages: messages, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void setActiveThread(String threadId) {
    final messages = _repo.getMessages(threadId);
    emit(state.copyWith(activeThreadId: threadId, messages: messages));
  }
}
