import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../presentation/widgets/colors.dart';
import '../../../main.dart' show gUserDisplayName;
import '../responses.dart';
import '../../../main.dart' show gUserPhotoUrl;

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
  final List<String> _previousChats = const [
    'Full body plan ideas',
    'Track calories for today',
    'Best dumbbell-only workout',
    'Quick mobility routine',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      HapticFeedback.selectionClick();
      _scrollToBottom();
    });

    // Scroll when the input gains focus (keyboard opening)
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Called on various metrics changes, including keyboard open/close.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Schedule after frame so viewInsets are applied
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
    HapticFeedback.selectionClick();

    setState(() {
      _hasStartedChat = true;
      _messages.add(_ChatMessage.user(text));
    });
    _controller.clear();
    _scrollToBottom();

    // Show thinking placeholder for ~2–3 seconds
    setState(() {
      _messages.add(_ChatMessage.thinking());
    });
    _scrollToBottom();

    await Future.delayed(
      Duration(
        milliseconds:
            1800 + (500 * (DateTime.now().millisecond % 3)).clamp(0, 1000),
      ),
    );
    if (!mounted) return;

    // Remove thinking placeholder if still present
    setState(() {
      final idx = _messages.lastIndexWhere(
        (m) => m.type == _MessageType.thinking,
      );
      if (idx != -1) _messages.removeAt(idx);
    });

    // Compose a demo response
    final demo = AltrixDemoResponses.random();
    final reply = _formatDemoResponse(demo);
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage.altrix(reply));
    });
    _scrollToBottom();
  }

  String _formatDemoResponse(Map<String, Object?> m) {
    final type = (m['type'] ?? 'text').toString();
    final title = m['title']?.toString();
    final content = m['content']?.toString();
    final items = (m['items'] as List?)?.map((e) => '- $e').join('\n');
    final plan = m['plan'];

    final buff = StringBuffer();
    if (title != null && title.isNotEmpty) {
      buff.writeln('• $title');
      buff.writeln('');
    }
    if (type == 'list' && items != null) {
      buff.writeln(items);
    } else if (type == 'plan' && plan is Map) {
      // rudimentary pretty printer
      if (plan['warmup'] is List) {
        buff.writeln('Warm-up:');
        for (final s in (plan['warmup'] as List)) {
          buff.writeln('  • $s');
        }
        buff.writeln('');
      }
      if (plan['main'] is List) {
        buff.writeln('Main:');
        for (final s in (plan['main'] as List)) {
          buff.writeln('  • $s');
        }
        buff.writeln('');
      }
      if (plan['cooldown'] is List) {
        buff.writeln('Cooldown:');
        for (final s in (plan['cooldown'] as List)) {
          buff.writeln('  • $s');
        }
      }
      if (plan['days'] is List) {
        for (final day in (plan['days'] as List)) {
          if (day is Map && day['name'] != null) {
            buff.writeln(day['name']);
            if (day['exercises'] is List) {
              for (final ex in (day['exercises'] as List)) {
                buff.writeln('  • $ex');
              }
            }
            buff.writeln('');
          }
        }
      }
      if (plan['weeks'] is List) {
        int i = 1;
        for (final w in (plan['weeks'] as List)) {
          buff.writeln('Week $i: $w');
          i++;
        }
      }
    } else if (content != null) {
      buff.writeln(content);
    }
    return buff.toString().trim();
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
                          child: _previousChats.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    'No previous chats yet',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _previousChats.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final title = _previousChats[index];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.of(context).pop();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                          horizontal: 8.0,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              CupertinoIcons.chat_bubble_text,
                                              size: 18,
                                              color: Colors.black,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
        shadowColor: Colors.transparent,
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
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: Semantics(
                button: true,
                label: 'Back to Home',
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.vibrantRed,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.house_fill,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _hasStartedChat
                ? ListView.builder(
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
                          );
                        case _MessageType.altrix:
                          return _AltrixBubble(text: msg.text);
                        case _MessageType.thinking:
                          return const _ThinkingBubble();
                      }
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
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final void Function(String) onSend;
  const _ChatInputBar({
    required this.focusNode,
    required this.controller,
    required this.onSend,
  });

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
              focusNode: focusNode,
              controller: controller,
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
              onSubmitted: (value) => onSend(value),
            ),
          ),
          GestureDetector(
            onTap: () => onSend(controller.text),
            child: const Icon(
              CupertinoIcons.arrow_up_circle_fill,
              color: AppColors.vibrantRed,
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
  _ChatMessage._(this.type, this.text);
  factory _ChatMessage.user(String t) => _ChatMessage._(_MessageType.user, t);
  factory _ChatMessage.altrix(String t) =>
      _ChatMessage._(_MessageType.altrix, t);
  factory _ChatMessage.thinking() =>
      _ChatMessage._(_MessageType.thinking, 'Thinking…');
}

class _UserBubble extends StatelessWidget {
  final String text;
  final String? photoUrl;
  const _UserBubble({required this.text, required this.photoUrl});

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
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'SF Pro Text',
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                ? NetworkImage(photoUrl!)
                : const AssetImage('assets/default_avatar.png')
                      as ImageProvider,
          ),
        ],
      ),
    );
  }
}

class _AltrixBubble extends StatefulWidget {
  final String text;
  const _AltrixBubble({required this.text});

  @override
  State<_AltrixBubble> createState() => _AltrixBubbleState();
}

class _AltrixBubbleState extends State<_AltrixBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -0.1),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
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
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Text(
                      widget.text,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontFamily: 'SF Pro Text',
                        fontSize: 15,
                        height: 1.35,
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

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Lottie.network(
              'https://lottie.host/2d58d506-a04c-4354-b6ed-b03812317093/5fPPvtbClc.json',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CupertinoActivityIndicator(radius: 8),
                ),
                SizedBox(width: 8),
                Text(
                  'Thinking…',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
