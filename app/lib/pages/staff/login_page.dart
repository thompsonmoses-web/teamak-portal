import 'package:flutter/material.dart';

import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final Session session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _error = null);

    final ok = await widget.session.signIn(
      username: _username.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Invalid username or password.');
      return;
    }
    // The router redirects to /staff once the session is signed in.
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Staff login',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/teamak_logo.png',
                          height: 72,
                          width: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Programme review console',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Teamak Global Solutions',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: TeamakColors.subtle),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(labelText: 'Username'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Username is required.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Password is required.'
                            : null,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: widget.session.busy ? null : _submit,
                        child: widget.session.busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
