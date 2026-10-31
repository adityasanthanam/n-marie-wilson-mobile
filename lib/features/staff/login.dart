import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'session.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});
  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false, _obscure = true;
  String? _error, _msg;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = _msg = null;
    });
    final err = await StaffSession.instance.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      context.go('/staff');
    }
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email above, then tap Forgot password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = _msg = null;
    });
    try {
      await Api.instance.forgotPassword(_email.text);
      _msg = 'Please inform the office administrator. A password reset request has been sent to the admin, who will set a new password for you.';
    } catch (_) {
      _error = 'Could not send the request. Check your connection and try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Staff sign in')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: MaxWidth(
                width: 420,
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Admin portal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Accounts are created by the office administrator.', style: TextStyle(color: Brand.muted)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v ?? '').length >= 8 ? null : 'At least 8 characters',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Brand.ink),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                            : const Text('Sign in'),
                      ),
                      TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                      if (_msg != null) Notice(_msg!, error: false),
                      if (_error != null) Notice(_error!),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
