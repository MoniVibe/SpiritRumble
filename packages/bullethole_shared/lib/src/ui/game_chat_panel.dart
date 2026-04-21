import 'package:flutter/material.dart';

@immutable
class GameChatEntry {
  const GameChatEntry({
    required this.author,
    required this.message,
    required this.sentAt,
    required this.isMine,
  });

  final String author;
  final String message;
  final DateTime sentAt;
  final bool isMine;
}

/// Reusable docked chat card used for both games.
class GameChatPanel extends StatelessWidget {
  const GameChatPanel({
    required this.entries,
    required this.inputController,
    required this.onSend,
    required this.title,
    this.helperText,
    super.key,
  });

  final List<GameChatEntry> entries;
  final TextEditingController inputController;
  final VoidCallback onSend;
  final String title;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Docked',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.92),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (helperText != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                helperText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.74),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      colorScheme.surface.withValues(alpha: 0.8),
                      colorScheme.surface.withValues(alpha: 0.62),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.56,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _ChatBubble(entry: entry);
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: inputController,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: onSend, child: const Text('Send')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.entry});

  final GameChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onBubble = entry.isMine
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    return Align(
      alignment: entry.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: entry.isMine
                ? colorScheme.primary.withValues(alpha: 0.62)
                : colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Column(
                crossAxisAlignment: entry.isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.author,
                    style: TextStyle(
                      fontSize: 11,
                      color: onBubble.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.message,
                    style: TextStyle(fontSize: 13, color: onBubble),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
