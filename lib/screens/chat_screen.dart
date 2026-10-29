import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/signaling_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.roomChat)),
      body: const SafeArea(child: ChatPanel()),
    );
  }
}

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, this.isSidePanel = false, this.onClose});

  final bool isSidePanel;
  final VoidCallback? onClose;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  static const _emojis = [
    '😀',
    '😂',
    '😊',
    '😍',
    '🥳',
    '👍',
    '👏',
    '❤️',
    '🔥',
    '🎉',
    '🙏',
    '🤔',
    '😢',
    '😮',
    '👋',
    '💯',
  ];

  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  String _mentionText = '';
  int _mentionStart = -1;
  int _mentionCursor = -1;

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      context.read<SignalingService>().sendChatMessage(text);
      _messageController.clear();
    } catch (error) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.couldNotSendChatMessage('$error'))),
        );
    }
  }

  Future<void> _showEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final emoji in _emojis)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || emoji == null) return;
    final value = _messageController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final updatedText = value.text.replaceRange(start, end, emoji);
    _messageController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signaling = context.watch<SignalingService>();
    final messages = signaling.chatMessages;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final mentionBorderColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFD54F)
        : const Color(0xFFB8860B);
    final mentionNames = signaling.peers
        .map((peer) => peer.name)
        .where((name) => name != signaling.localDisplayName)
        .toList();

    return Container(
      decoration: widget.isSidePanel
          ? BoxDecoration(
              border: Border(
                left: Directionality.of(context) == TextDirection.rtl
                    ? BorderSide(color: colorScheme.outlineVariant)
                    : BorderSide.none,
                right: Directionality.of(context) == TextDirection.ltr
                    ? BorderSide(color: colorScheme.outlineVariant)
                    : BorderSide.none,
              ),
            )
          : null,
      child: Column(
        children: [
          if (widget.isSidePanel)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.roomChat,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.closeChat,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      l10n.noChatMessages,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      final time = MaterialLocalizations.of(context)
                          .formatTimeOfDay(
                            TimeOfDay.fromDateTime(message.timestamp.toLocal()),
                          );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                message.text.contains(
                                  '@${signaling.localDisplayName}',
                                )
                                ? Border.all(
                                    color: mentionBorderColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        message.senderName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      time,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(message.text),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.addEmoji,
                  onPressed: _showEmojiPicker,
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: _messageController,
                    focusNode: _messageFocusNode,
                    optionsViewOpenDirection: OptionsViewOpenDirection.up,
                    optionsBuilder: (value) {
                      final cursor = value.selection.isValid
                          ? value.selection.extentOffset
                          : value.text.length;
                      if (cursor < 0 || cursor > value.text.length) {
                        return const [];
                      }
                      final beforeCursor = value.text.substring(0, cursor);
                      final atIndex = beforeCursor.lastIndexOf('@');
                      if (atIndex < 0 ||
                          (atIndex > 0 &&
                              beforeCursor[atIndex - 1].trim().isNotEmpty)) {
                        return const [];
                      }

                      _mentionText = value.text;
                      _mentionStart = atIndex;
                      _mentionCursor = cursor;
                      final query = beforeCursor.substring(atIndex + 1);
                      return mentionNames.where(
                        (name) =>
                            name.toLowerCase().contains(query.toLowerCase()),
                      );
                    },
                    onSelected: (name) {
                      final start = _mentionStart;
                      final cursor = _mentionCursor;
                      if (start < 0 || cursor < start) return;
                      final updatedText = _mentionText.replaceRange(
                        start,
                        cursor,
                        '@$name ',
                      );
                      final newCursor = start + name.length + 2;
                      _messageController.value = TextEditingValue(
                        text: updatedText,
                        selection: TextSelection.collapsed(offset: newCursor),
                      );
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) =>
                            TextField(
                              controller: controller,
                              focusNode: focusNode,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 2000,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: l10n.typeMessage,
                                counterText: '',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                    optionsViewBuilder: (context, onSelected, options) {
                      final names = options.toList();
                      return Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                              maxWidth: 320,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: names.length,
                              itemBuilder: (context, index) {
                                final name = names[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(name),
                                  onTap: () => onSelected(name),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton.filled(
                    tooltip: l10n.sendMessage,
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
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
