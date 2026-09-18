import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/chat_replies.dart';
import '../../theme/app_colors.dart';
import '../app_logo.dart';

/// Buka panel chat customer dari bawah layar.
///
/// Hanya tampilan: balasannya dari aturan kata kunci di `chat_replies.dart`,
/// tidak ada koneksi ke server atau WhatsApp.
Future<void> showChatSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _ChatPanel(),
  );
}

class _ChatMessage {
  const _ChatMessage(this.text, {required this.fromCustomer});

  final String text;
  final bool fromCustomer;
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel();

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(kChatGreeting, fromCustomer: false),
  ];

  /// Jeda sebelum balasan muncul, supaya tidak terasa seperti teks yang
  /// langsung nongol bersamaan dengan pertanyaannya.
  static const _replyDelay = Duration(milliseconds: 700);

  bool _isTyping = false;
  Timer? _replyTimer;

  @override
  void dispose() {
    _replyTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final message = text.trim();
    if (message.isEmpty) return;

    _input.clear();
    setState(() {
      _messages.add(_ChatMessage(message, fromCustomer: true));
      _isTyping = true;
    });
    _scrollToBottom();

    _replyTimer?.cancel();
    _replyTimer = Timer(_replyDelay, () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(autoReply(message), fromCustomer: false));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    // Daftar baru diukur setelah frame ini selesai.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sisakan ruang untuk papan ketik yang sedang terbuka.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Header(),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) return const _TypingBubble();
                  return _Bubble(message: _messages[index]);
                },
              ),
            ),
            // Tombol pertanyaan siap-pakai hanya selama belum ada tanya-jawab,
            // supaya tidak menutupi percakapan yang sudah panjang.
            if (_messages.length == 1) _QuickQuestions(onTap: _send),
            _Composer(controller: _input, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          const AppLogo(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asisten Supply Sync',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.statusGood,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        // Jelas sejak awal bahwa ini bukan manusia.
                        'Balasan otomatis · aktif 24 jam',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromCustomer = message.fromCustomer;

    return Align(
      alignment: fromCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: fromCustomer ? AppColors.navy : const Color(0xFFF1F3F7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromCustomer ? 16 : 4),
            bottomRight: Radius.circular(fromCustomer ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: fromCustomer ? Colors.white : AppColors.textPrimary,
            height: 1.4,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFF1F3F7),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Text(
          'Sedang menulis…',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _QuickQuestions extends StatelessWidget {
  const _QuickQuestions({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final question in kChatQuickQuestions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(question),
                onPressed: () => onTap(question),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                labelStyle: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tulis pesan…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: const Color(0xFFF1F3F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.navy,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSend(controller.text),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                  semanticLabel: 'Kirim',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
