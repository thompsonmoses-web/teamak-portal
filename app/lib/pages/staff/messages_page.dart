import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/shell.dart';

/// Staff inbox for messages sent through the public contact form.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, required this.session});

  final Session session;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<ContactMessage> _messages = const <ContactMessage>[];
  bool _loading = true;
  String? _error;

  Session get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await _session.api.fetchMessages();
      if (mounted) setState(() => _messages = messages);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;

    return AppShell(
      title: 'Messages',
      child: ListView(
        padding: EdgeInsets.all(wide ? 24 : 14),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Contact messages',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_messages.length} message${_messages.length == 1 ? '' : 's'} '
                      'received through the website contact form.',
                      style: const TextStyle(color: TeamakColors.subtle),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/staff'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Dashboard'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('$_error', style: TextStyle(color: Colors.red.shade700)),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_messages.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No messages yet.')),
              ),
            )
          else
            for (final message in _messages) _MessageCard(message: message),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final ContactMessage message;

  String get _shortDate {
    final iso = message.createdAt;
    return iso.length >= 16 ? iso.substring(0, 16).replaceAll('T', ' ') : iso;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    message.subject.isEmpty ? 'General enquiry' : message.subject,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _shortDate,
                  style: const TextStyle(color: TeamakColors.subtle, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${message.name}  ·  ${message.phone}'
              '${message.email.isEmpty ? '' : '  ·  ${message.email}'}',
              style: const TextStyle(color: TeamakColors.subtle),
            ),
            const SizedBox(height: 12),
            Text(message.message, style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }
}
