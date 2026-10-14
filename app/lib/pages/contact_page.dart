import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/shell.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _submitting = false;
  String? _success;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      final response = await widget.api.submitContact(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = response;
        _nameCtrl.clear();
        _phoneCtrl.clear();
        _emailCtrl.clear();
        _subjectCtrl.clear();
        _messageCtrl.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;

    return AppShell(
      title: 'Contact us',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.all(wide ? 32 : 16),
            children: <Widget>[
              // Header.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF04122E), Color(0xFF072E68)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.mail_rounded, color: TeamakColors.accent, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Get in touch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Have a question? Send us a message and we\'ll get back to you shortly.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Success banner.
              if (_success != null) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _success!,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Error banner.
              if (_error != null) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.error_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Form card.
              Card(
                child: Padding(
                  padding: EdgeInsets.all(wide ? 28 : 20),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Your name *'),
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Name is required.' : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                decoration: const InputDecoration(labelText: 'Phone number *'),
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Phone is required.' : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtrl,
                                decoration: const InputDecoration(labelText: 'Email (optional)'),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null;
                                  if (!v.contains('@')) return 'Enter a valid email.';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _subjectCtrl,
                          decoration: const InputDecoration(labelText: 'Subject'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Subject is required.' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _messageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Your message *',
                            hintText: 'Type your message here...',
                          ),
                          maxLines: 5,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Message is required.' : null,
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(_submitting ? 'Sending…' : 'Send message'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Direct contact info.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Other ways to reach us',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 14),
                      _contactRow(Icons.phone_rounded, '+234 802 344 9126'),
                      _contactRow(Icons.email_rounded, 'Teamakgloblsolution33@gmail.com'),
                      _contactRow(Icons.location_on_rounded,
                          'Solution Gospel Complex, Aba Opa, Ojoo, Ibadan'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: TeamakColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
