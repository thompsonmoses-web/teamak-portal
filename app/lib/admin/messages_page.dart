import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'admin_shell.dart';
import 'widgets.dart';

/// Everything riders and applicants sent through the public contact form.
///
/// Messages carry no read state in the portal, so this is a plain inbox: the
/// newest first, each with the number to call back and a WhatsApp button that
/// opens a chat with the sender's number already in it.
class AdminMessagesPage extends StatefulWidget {
  const AdminMessagesPage({super.key, required this.session});

  final Session session;

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  List<ContactMessage> _messages = const <ContactMessage>[];
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final messages = await _session.api.fetchMessages(limit: 200);
      if (mounted) setState(() => _messages = messages);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWhatsApp(ContactMessage message) async {
    final digits = message.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final number = digits.length > 10 && digits.startsWith('234')
        ? digits
        : '234${digits.replaceFirst(RegExp(r'^0'), '')}';
    final text = 'Hello ${message.name}, thank you for contacting Teamak '
        'about "${message.subject.isEmpty ? 'your enquiry' : message.subject}".';
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(text)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp could not open — call ${message.phone}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _messages
        : _messages
            .where((message) =>
                message.name.toLowerCase().contains(query) ||
                message.subject.toLowerCase().contains(query) ||
                message.message.toLowerCase().contains(query) ||
                message.phone.contains(query))
            .toList();

    return AdminShell(
      session: _session,
      currentPath: '/admin/messages',
      title: 'Messages',
      searchHint: 'Search messages…',
      onSearch: (value) => setState(() => _query = value),
      child: ListView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        children: <Widget>[
          AdminPageHeader(
            title: 'Messages',
            subtitle: 'Questions riders and applicants sent through the contact form.',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search by name, phone, subject or message',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('$_error', style: const TextStyle(color: TeamakColors.danger)),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No messages yet.')),
              ),
            )
          else ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${filtered.length} message${filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(color: TeamakColors.subtle, fontWeight: FontWeight.w600),
              ),
            ),
            for (final message in filtered)
              _MessageCard(message: message, onWhatsApp: () => _openWhatsApp(message)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.onWhatsApp});

  final ContactMessage message;
  final VoidCallback onWhatsApp;

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
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  shortDate(message.createdAt),
                  style: const TextStyle(color: TeamakColors.subtle, fontSize: 12.5),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            Text(message.message, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${message.phone}')),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text(message.phone),
                ),
                if (message.email.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('mailto:${message.email}'),
                    ),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(message.email),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Reply on WhatsApp'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
