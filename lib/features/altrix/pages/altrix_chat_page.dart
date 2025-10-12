import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ai_fitness_tracker/features/altrix/utils/altrix_constants.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../presentation/widgets/colors.dart';
import '../../../main.dart' show gUserDisplayName, gUserPhotoUrl;
// import '../responses.dart';
import 'altrix_settings_page.dart';
// Altrix memory imports
import 'package:ai_fitness_tracker/features/altrix/data/altrix_repository.dart';
import 'package:ai_fitness_tracker/features/altrix/data/altrix_local_source.dart';
import 'package:ai_fitness_tracker/features/altrix/data/altrix_analytics_logger.dart';
import 'package:ai_fitness_tracker/core/services/local_storage_service.dart';
import 'package:ai_fitness_tracker/features/altrix/models/altrix_thread.dart';
import 'package:ai_fitness_tracker/core/network/gemini_client.dart';

class AltrixChatPage extends StatefulWidget {
  const AltrixChatPage({super.key});

  @override
  State<AltrixChatPage> createState() => _AltrixChatPageState();
}

class _AltrixChatPageState extends State<AltrixChatPage>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _linesVertical = false;
  bool _chatsExpanded = false;
  bool _hasStartedChat = false;
  final List<_ChatMessage> _messages = [];
  late final AltrixRepository _repo;
  List<AltrixThread> _threads = [];
  Box? _analyticsBox;
  String? _activeThreadId;
  bool _repoReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _initRepo();
  }

  Future<void> _initRepo() async {
    try {
      final storage = LocalStorageService();
      _repo = AltrixRepository(
        local: AltrixLocalSource(storage),
        analytics: LocalAltrixAnalyticsLogger(storage),
      );
      await _repo.init();
      _repoReady = true;
      try {
        _analyticsBox = await storage.openEncryptedDynamicBox(
          AltrixConstants.analyticsBox,
        );
      } catch (_) {
        _analyticsBox = null;
      }
      final threads = _repo.getThreads();
      if (!mounted) return;
      setState(() => _threads = threads);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleSend(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (!_repoReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting up chat… try again in a second')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    final userMsgIndex = _messages.length;
    setState(() {
      _hasStartedChat = true;
      _messages.add(_ChatMessage.user(text, status: 'sending'));
    });
    _controller.clear();
    _scrollToBottom();

    try {
      if (_activeThreadId == null) {
        final t = await _repo.createThread(firstMessage: text);
        _activeThreadId = t.id;
      }
      final persisted = await _repo.addUserMessage(_activeThreadId!, text);
      if (mounted && userMsgIndex >= 0 && userMsgIndex < _messages.length) {
        setState(() {
          _messages[userMsgIndex] = _messages[userMsgIndex].copyWith(
            status: 'success',
            id: persisted.id,
          );
        });
      }
    } catch (_) {
      if (mounted && userMsgIndex >= 0 && userMsgIndex < _messages.length) {
        setState(() {
          _messages[userMsgIndex] = _messages[userMsgIndex].copyWith(
            status: 'error',
          );
        });
      }
    }

    setState(() => _messages.add(_ChatMessage.thinking()));
    _scrollToBottom();
    String accumulated = '';
    final started = DateTime.now();
    try {
      await _repo.recordGeminiRequest(threadId: _activeThreadId);
    } catch (_) {}
    final cancelToken = CancelToken();
    try {
      await for (final chunk in _repo.streamGeminiText(
        text,
        cancelToken: cancelToken,
      )) {
        accumulated += chunk;
        if (!mounted) return;
        setState(() {
          final idx = _messages.lastIndexWhere(
            (m) => m.type == _MessageType.thinking,
          );
          if (idx != -1) {
            _messages[idx] = _ChatMessage._(_MessageType.thinking, accumulated);
          }
        });
      }
      if (!mounted) return;
      setState(() {
        final idx = _messages.lastIndexWhere(
          (m) => m.type == _MessageType.thinking,
        );
        if (idx != -1) {
          _messages.removeAt(idx);
          _messages.add(
            _ChatMessage.altrix(accumulated, isGeminiResponse: true),
          );
        }
      });
      if (_activeThreadId != null) {
        try {
          await _repo.addAssistantMessage(
            _activeThreadId!,
            accumulated,
            meta: const {'isGeminiResponse': true},
          );
          final threads = _repo.getThreads();
          if (mounted) setState(() => _threads = threads);
        } catch (_) {}
      }
      try {
        final latency = DateTime.now().difference(started).inMilliseconds;
        await _repo.recordGeminiSuccess(
          threadId: _activeThreadId,
          tokensUsed: 0,
          latencyMs: latency,
        );
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      // Build friendly, contextual message
      String friendly =
          'Something went wrong generating a reply. You can retry.';
      if (e is GeminiException) {
        friendly = _describeGeminiError(e);
      } else {
        final msg = e.toString().toLowerCase();
        if (msg.contains('timeout') || msg.contains('timed out')) {
          friendly = 'The request timed out. Try again.';
        }
      }
      setState(() {
        final idx = _messages.lastIndexWhere(
          (m) => m.type == _MessageType.thinking,
        );
        if (idx != -1) _messages.removeAt(idx);
        final lastUser = _messages.lastIndexWhere(
          (m) => m.type == _MessageType.user,
        );
        if (lastUser != -1) {
          _messages[lastUser] = _messages[lastUser].copyWith(status: 'failed');
        }
        String? promptId;
        if (lastUser != -1) {
          promptId = _messages[lastUser].id;
        }
        final hasDuplicate = _messages.any(
          (m) =>
              m.type == _MessageType.altrix &&
              m.status == 'error' &&
              (promptId != null && m.originalPromptId == promptId),
        );
        if (!hasDuplicate) {
          _messages.add(
            _ChatMessage.altrix(
              'Sorry, I couldn\'t generate a response.',
              status: 'error',
              error: friendly,
              originalPrompt: text,
              originalPromptId: promptId,
            ),
          );
        }
      });
      try {
        await _repo.recordGeminiError(
          threadId: _activeThreadId,
          code: 'stream',
        );
      } catch (_) {}
    } finally {
      cancelToken.cancel();
    }

    // Voice mode: speak the assistant reply if enabled
    try {
      final settings = Hive.box('settingsBox');
      final voice =
          settings.get('altrixVoiceMode', defaultValue: false) as bool;
      if (voice && _activeThreadId != null) {
        final persisted = _repo.getMessages(_activeThreadId!);
        final last = persisted.isNotEmpty ? persisted.last : null;
        if (last != null && last.role == 'assistant') {
          _speakAssistant(last.content);
        }
      }
    } catch (_) {}
  }

  void _speakAssistant(String text) {
    // Hook for TTS if needed in the future.
  }

  String _describeGeminiError(GeminiException e) {
    switch (e.code) {
      case 'networkOffline':
        return 'No internet connection. Please check your connection and retry.';
      case 'rateLimit':
        return 'Too many requests. Please wait a few seconds.';
      case 'unauthorized':
        return 'Missing or invalid API key. Please check your settings.';
      case 'serverError':
        return 'Server error. Please try again shortly.';
      case 'unknown':
      default:
        if (e.statusCode == null &&
            (e.message.toLowerCase().contains('timeout') ||
                e.message.toLowerCase().contains('timed out'))) {
          return 'The request timed out. Try again.';
        }
        return 'Something went wrong generating a reply. You can retry.';
    }
  }

  // Retry a failed assistant response in place, animating within the same bubble
  void _retryAssistantAt(int index, String prompt) async {
    if (index < 0 || index >= _messages.length) return;
    final current = _messages[index];
    if (current.type != _MessageType.altrix) return;
    // Replace with a 'thinking' placeholder to trigger AnimatedSwitcher swap
    setState(() {
      _messages[index] = _ChatMessage._(_MessageType.thinking, 'Thinking…');
    });

    String accumulated = '';
    final started = DateTime.now();
    try {
      await _repo.recordGeminiRequest(threadId: _activeThreadId);
    } catch (_) {}
    final cancelToken = CancelToken();
    try {
      await for (final chunk in _repo.streamGeminiText(
        prompt,
        cancelToken: cancelToken,
      )) {
        accumulated += chunk;
        if (!mounted) return;
        setState(() {
          if (index >= 0 &&
              index < _messages.length &&
              _messages[index].type == _MessageType.thinking) {
            _messages[index] = _ChatMessage._(
              _MessageType.thinking,
              accumulated,
            );
          }
        });
      }
      if (!mounted) return;
      setState(() {
        if (index >= 0 && index < _messages.length) {
          _messages[index] = _ChatMessage.altrix(
            accumulated,
            isGeminiResponse: true,
          );
        }
      });
      if (_activeThreadId != null) {
        try {
          await _repo.addAssistantMessage(
            _activeThreadId!,
            accumulated,
            meta: const {'isGeminiResponse': true},
          );
          final threads = _repo.getThreads();
          if (mounted) setState(() => _threads = threads);
        } catch (_) {}
      }
      try {
        final latency = DateTime.now().difference(started).inMilliseconds;
        await _repo.recordGeminiSuccess(
          threadId: _activeThreadId,
          tokensUsed: 0,
          latencyMs: latency,
        );
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      String friendly =
          'Something went wrong generating a reply. You can retry.';
      if (e is GeminiException) {
        friendly = _describeGeminiError(e);
      } else {
        final msg = e.toString().toLowerCase();
        if (msg.contains('timeout') || msg.contains('timed out')) {
          friendly = 'The request timed out. Try again.';
        }
      }
      setState(() {
        if (index >= 0 && index < _messages.length) {
          _messages[index] = _ChatMessage.altrix(
            'Sorry, I couldn\'t generate a response.',
            status: 'error',
            error: friendly,
            originalPrompt: prompt,
            originalPromptId: current.originalPromptId,
          );
        }
      });
      try {
        await _repo.recordGeminiError(
          threadId: _activeThreadId,
          code: 'stream',
        );
      } catch (_) {}
    } finally {
      cancelToken.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (gUserDisplayName ?? '').isNotEmpty
        ? gUserDisplayName!.split(' ').first
        : 'Friend';
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      onDrawerChanged: (opened) => setState(() => _linesVertical = opened),
      drawer: Drawer(
        elevation: 12,
        width: 280,
        child: Container(
          color: Colors.grey.shade100,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: SizedBox(
                          height: 80,
                          width: 80,
                          child: Lottie.network(
                            'https://lottie.host/2d58d506-a04c-4354-b6ed-b03812317093/5fPPvtbClc.json',
                            fit: BoxFit.contain,
                            repeat: true,
                            animate: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.grey.shade400,
                            AppColors.vibrantRed,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'Altrix',
                          style: TextStyle(
                            fontSize: 49,
                            fontFamily: 'Sora',
                            letterSpacing: -5,
                            wordSpacing: -8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    CupertinoIcons.bubble_left_bubble_right,
                    color: Colors.black,
                  ),
                  title: const Text(
                    'New chat',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _messages.clear();
                      _hasStartedChat = false; // return to greeting view
                      _activeThreadId = null; // no active thread
                    });
                    _controller.clear();
                    _scrollToBottom();
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _chatsExpanded
                        ? CupertinoIcons.chevron_down
                        : CupertinoIcons.chevron_right,
                    color: Colors.black,
                    size: 18,
                  ),
                  title: const Text(
                    'Chats',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _chatsExpanded = !_chatsExpanded);
                  },
                ),
                // Fills remaining space; shows list only when expanded
                Expanded(
                  child: _chatsExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: 14.0,
                            right: 8.0,
                          ),
                          child: _threads.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    'No previous chats yet',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                )
                              : (_analyticsBox != null
                                    ? ValueListenableBuilder(
                                        valueListenable: _analyticsBox!
                                            .listenable(),
                                        builder: (context, Box box, child) {
                                          return _buildThreadListWithMetrics(
                                            context,
                                            box,
                                          );
                                        },
                                      )
                                    : _buildThreadListWithMetrics(
                                        context,
                                        null,
                                      )),
                        )
                      : const SizedBox.shrink(),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.gear, color: Colors.black),
                  title: const Text(
                    'Settings',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const AltrixSettingsPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              );
                              return SlideTransition(
                                position: curved.drive(
                                  Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ),
                                ),
                                child: child,
                              );
                            },
                        transitionDuration: const Duration(milliseconds: 280),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 240,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Semantics(
            button: true,
            label: _linesVertical ? 'Menu vertical' : 'Menu horizontal',
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                HapticFeedback.selectionClick();
                final isOpen = _scaffoldKey.currentState?.isDrawerOpen ?? false;
                if (isOpen) {
                  Navigator.of(context).pop();
                } else {
                  _scaffoldKey.currentState?.openDrawer();
                }
              },
              child: Center(
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _linesVertical ? 0.25 : 0.0,
                  curve: Curves.easeInOut,
                  child: const Icon(
                    CupertinoIcons.line_horizontal_3,
                    size: 22,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Altrix',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.2,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Semantics(
              button: true,
              label: 'Back to Home',
              child: Material(
                color: AppColors.vibrantRed,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: Colors.white.withValues(alpha: 0.25),
                  highlightColor: Colors.white.withValues(alpha: 0.12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: Icon(
                        CupertinoIcons.house_fill,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: NotificationListener<_RetryRequest>(
        onNotification: (n) {
          // If the retry targets a specific assistant bubble, perform in-place retry
          if (n.atIndex != null) {
            _retryAssistantAt(n.atIndex!, n.text);
          } else {
            // Fallback: create a new user message and stream normally
            _handleSend(n.text);
          }
          return true;
        },
        child: Column(
          children: [
            Expanded(
              child: _hasStartedChat
                  ? ValueListenableBuilder(
                      valueListenable: Hive.box(
                        AltrixConstants.settingsBox,
                      ).listenable(keys: ['altrixTextFast']),
                      builder: (context, Box box, child) {
                        final fast =
                            box.get('altrixTextFast', defaultValue: false)
                                as bool;
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            switch (msg.type) {
                              case _MessageType.user:
                                return _UserBubble(
                                  text: msg.text,
                                  photoUrl: gUserPhotoUrl,
                                  status: msg.status,
                                );
                              case _MessageType.altrix:
                                return _AltrixBubble(
                                  text: msg.text,
                                  fastReveal: fast,
                                  tokensUsed: msg.tokensUsed,
                                  latencyMs: msg.latencyMs,
                                  isGeminiResponse: msg.isGeminiResponse,
                                  error: msg.error,
                                  originalPrompt: msg.originalPrompt,
                                  atIndex: index,
                                );
                              case _MessageType.thinking:
                                // Show the progressively updating text as an Altrix bubble
                                return _AltrixBubble(
                                  text: msg.text,
                                  fastReveal: true,
                                  tokensUsed: 0,
                                  latencyMs: 0,
                                  isGeminiResponse: false,
                                  error: null,
                                  originalPrompt: null,
                                  atIndex: index,
                                  isThinking: true,
                                );
                            }
                          },
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.network(
                            'https://lottie.host/2d58d506-a04c-4354-b6ed-b03812317093/5fPPvtbClc.json',
                            width: 180,
                            height: 180,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Hey $firstName,',
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'What can I help you with?',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _ChatInputBar(
                  focusNode: _focusNode,
                  controller: _controller,
                  onSend: _handleSend,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadListWithMetrics(BuildContext context, Box? metricsBox) {
    return ListView.separated(
      itemCount: _threads.length,
      separatorBuilder: (context, i) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final t = _threads[index];
        final title = t.title;
        final isActive = _activeThreadId == t.id;
        Map? m;
        if (metricsBox != null) {
          m = metricsBox.get('metrics_${t.id}') as Map?;
        }
        final int? count = (m != null && m['promptCount'] is int)
            ? m['promptCount'] as int
            : null;
        final double? avg = (m != null && m['avgResponseTime'] is num)
            ? (m['avgResponseTime'] as num).toDouble()
            : null;
        final subtitle = (count == null || avg == null)
            ? null
            : '${count} prompts • avg ${_formatMs(avg)}';

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _activeThreadId = t.id;
              _hasStartedChat = true;
              // Load persisted messages
              final persisted = _repo.getMessages(t.id);
              _messages
                ..clear()
                ..addAll(
                  persisted.map(
                    (m) => m.role == 'user'
                        ? _ChatMessage.user(
                            m.content,
                            id: m.id,
                            status: m.status,
                          )
                        : _ChatMessage.altrix(
                            m.content,
                            tokensUsed: m.tokensUsed,
                            latencyMs: m.latencyMs,
                            isGeminiResponse: m.isGeminiResponse,
                          ),
                  ),
                );
            });
            Navigator.of(context).pop();
            _scrollToBottom();
          },
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: isActive ? Border.all(color: Colors.black12) : null,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_text,
                  size: 18,
                  color: isActive ? AppColors.vibrantRed : Colors.black,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isActive ? AppColors.vibrantRed : Colors.black,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11.5,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Format latency for thread list metrics subtitle
  String _formatMs(double ms) {
    if (ms < 1000) return '${ms.toStringAsFixed(0)}ms';
    final s = ms / 1000.0;
    return s >= 10 ? '${s.toStringAsFixed(0)}s' : '${s.toStringAsFixed(1)}s';
  }
}

class _ChatInputBar extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final void Function(String) onSend;
  const _ChatInputBar({
    required this.focusNode,
    required this.controller,
    required this.onSend,
  });

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.sparkles,
            size: 18,
            color: AppColors.fitnessBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              focusNode: widget.focusNode,
              controller: widget.controller,
              autofocus: true,
              cursorColor: AppColors.vibrantRed,
              style: const TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 15,
                color: Color(0xFF111827),
              ),
              decoration: const InputDecoration(
                hintText: 'Ask Altrix…',
                hintStyle: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (value) => widget.onSend(value),
            ),
          ),
          Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              onTap: () => widget.onSend(widget.controller.text),
              child: AnimatedScale(
                scale: _pressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                child: const Icon(
                  CupertinoIcons.arrow_up_circle_fill,
                  color: AppColors.vibrantRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MessageType { user, altrix, thinking }

class _ChatMessage {
  final _MessageType type;
  final String text;
  final String? id; // persisted id for user messages
  final String? status; // 'sending' | 'success' | 'error'
  final int tokensUsed; // assistant meta
  final int latencyMs; // assistant meta
  final bool isGeminiResponse; // assistant meta
  final String? error; // assistant error message (for UI)
  final String? originalPrompt; // used to retry assistant generation
  final String?
  originalPromptId; // used to dedupe assistant error blocks per user message

  _ChatMessage._(
    this.type,
    this.text, {
    this.id,
    this.status,
    this.tokensUsed = 0,
    this.latencyMs = 0,
    this.isGeminiResponse = false,
    this.error,
    this.originalPrompt,
    this.originalPromptId,
  });

  factory _ChatMessage.user(
    String t, {
    String? id,
    String status = 'success',
  }) => _ChatMessage._(_MessageType.user, t, id: id, status: status);
  factory _ChatMessage.altrix(
    String t, {
    int tokensUsed = 0,
    int latencyMs = 0,
    bool isGeminiResponse = false,
    String? status,
    String? error,
    String? originalPrompt,
    String? originalPromptId,
  }) => _ChatMessage._(
    _MessageType.altrix,
    t,
    tokensUsed: tokensUsed,
    latencyMs: latencyMs,
    isGeminiResponse: isGeminiResponse,
    status: status,
    error: error,
    originalPrompt: originalPrompt,
    originalPromptId: originalPromptId,
  );
  factory _ChatMessage.thinking() =>
      _ChatMessage._(_MessageType.thinking, 'Thinking…');

  _ChatMessage copyWith({
    String? id,
    String? status,
    int? tokensUsed,
    int? latencyMs,
    bool? isGeminiResponse,
    String? error,
    String? originalPrompt,
    String? originalPromptId,
  }) {
    return _ChatMessage._(
      type,
      text,
      id: id ?? this.id,
      status: status ?? this.status,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      latencyMs: latencyMs ?? this.latencyMs,
      isGeminiResponse: isGeminiResponse ?? this.isGeminiResponse,
      error: error ?? this.error,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      originalPromptId: originalPromptId ?? this.originalPromptId,
    );
  }
}

class _UserBubble extends StatefulWidget {
  final String text;
  final String? photoUrl;
  final String? status; // sending | success | error
  const _UserBubble({required this.text, required this.photoUrl, this.status});

  @override
  State<_UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<_UserBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -0.08),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ac.forward());
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.vibrantRed,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade100,
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'SF Pro Text',
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                    ? NetworkImage(widget.photoUrl!)
                    : const AssetImage('assets/default_avatar.png')
                          as ImageProvider,
              ),
              if (widget.status == 'sending')
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CupertinoActivityIndicator(radius: 6),
                )
              else if (widget.status == 'error')
                const Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  color: Colors.redAccent,
                  size: 14,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Simple retry chip widget

// Notification used to bubble retry requests up to the page
class _RetryRequest extends Notification {
  final String text;
  final int? atIndex; // if provided, perform in-place retry at this list index
  _RetryRequest(this.text, {this.atIndex});

  static void send(BuildContext context, String text, {int? atIndex}) {
    _RetryRequest(text, atIndex: atIndex).dispatch(context);
  }
}

class _AltrixBubble extends StatefulWidget {
  final String text;
  final bool fastReveal;
  final int tokensUsed;
  final int latencyMs;
  final bool isGeminiResponse;
  final String? error;
  final String? originalPrompt;
  final int? atIndex; // list index for in-place retry
  final bool
  isThinking; // show spinner/placeholder while retrying or generating
  const _AltrixBubble({
    required this.text,
    this.fastReveal = false,
    this.tokensUsed = 0,
    this.latencyMs = 0,
    this.isGeminiResponse = false,
    this.error,
    this.originalPrompt,
    this.atIndex,
    this.isThinking = false,
  });

  @override
  State<_AltrixBubble> createState() => _AltrixBubbleState();
}

class _AltrixBubbleState extends State<_AltrixBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.fastReveal ? 220 : 400),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _slide = Tween(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(_fade);
    // Start text fade after build so bubble + lottie appear first
    WidgetsBinding.instance.addPostFrameCallback((_) => _ac.forward());
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Lottie.network(
              'https://lottie.host/2d58d506-a04c-4354-b6ed-b03812317093/5fPPvtbClc.json',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: widget.isThinking ? 1.0 : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: (widget.error != null && widget.error!.isNotEmpty)
                        ? _AssistantErrorBlock(
                            key: const ValueKey('assistant-error'),
                            message: widget.error!,
                            onRetry: () {
                              final text = widget.originalPrompt ?? '';
                              if (text.trim().isEmpty) return;
                              _RetryRequest.send(
                                context,
                                text,
                                atIndex: widget.atIndex,
                              );
                            },
                          )
                        : widget.isThinking
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              CupertinoActivityIndicator(radius: 8),
                              SizedBox(width: 6),
                              Text(
                                'Thinking…',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          )
                        : FadeTransition(
                            opacity: _fade,
                            child: SlideTransition(
                              position: _slide,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [_MarkdownMessage(text: widget.text)],
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Compact error block shown for failed assistant generations
class _AssistantErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _AssistantErrorBlock({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Colors.orange,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontFamily: 'SF Pro Text',
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: AppColors.vibrantRed, size: 16),
            label: Text(
              'Retry',
              style: TextStyle(
                color: AppColors.vibrantRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Removed legacy thinking bubble; we now render streaming text in _AltrixBubble

class _MarkdownMessage extends StatelessWidget {
  final String text;
  const _MarkdownMessage({required this.text});

  // Convert common bold-as-title patterns to proper Markdown headings
  String _preprocess(String input) {
    final lines = input.split('\n');
    final buf = StringBuffer();
    final headingBold = RegExp(r'^\s*\*\*([^*]+)\*\*:?\s*$');
    for (var line in lines) {
      final m = headingBold.firstMatch(line);
      if (m != null) {
        // Promote to H3 heading for visual hierarchy
        buf.writeln('### ${m.group(1)!.trim()}');
        continue;
      }
      // Normalize list markers that LLMs often vary (•, -, *)
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('• ')) {
        final indent = ' ' * (line.length - trimmed.length);
        buf.writeln('${indent}* ${trimmed.substring(2)}');
        continue;
      }
      // Ensure there is a blank line before lists and headings to help parsers
      buf.writeln(line);
    }
    return buf.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final data = _preprocess(text.trimRight());
    final base = Theme.of(context).textTheme;
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: Color(0xFF111827),
          fontFamily: 'SF Pro Text',
          fontSize: 15,
          height: 1.3,
        ),
        h1: const TextStyle(
          color: Color(0xFF111827),
          fontFamily: 'Sora',
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        h2: const TextStyle(
          color: Color(0xFF111827),
          fontFamily: 'Sora',
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        h3: const TextStyle(
          color: Color(0xFF111827),
          fontFamily: 'Sora',
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        listBullet: const TextStyle(
          color: Color(0xFF111827),
          fontFamily: 'SF Pro Text',
          fontSize: 15,
        ),
        strong: const TextStyle(
          color: Color(0xFF111827),
          fontFamily: 'SF Pro Text',
          fontWeight: FontWeight.w700,
        ),
        blockquote: TextStyle(
          color: const Color(0xFF111827).withValues(alpha: 0.8),
          fontFamily: 'SF Pro Text',
          fontStyle: FontStyle.italic,
        ),
        code: TextStyle(
          fontFamily: base.bodyMedium?.fontFamily,
          backgroundColor: const Color(0xFFF3F4F6),
          color: const Color(0xFF111827),
          fontSize: 13.5,
        ),
      ),
      // Keep bubble layout tight; no padding here
      softLineBreak: true,
      onTapLink: (text, href, title) {
        // Optional: implement link opening via url_launcher
      },
    );
  }
}
