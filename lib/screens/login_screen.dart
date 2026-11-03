import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../config.dart';
import '../push/push_service.dart';
import '../theme.dart';
import '../widgets/logo.dart';

// Connexion réservée aux chauffeurs partenaires. Mot de passe oublié et inscription restent sur le site.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final push = context.read<PushService>();
    try {
      await context.read<AuthController>().login(_email.text, _password.text, pushToken: push.token);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Connexion impossible. Vérifiez votre réseau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: Logo(size: 56)),
                    const SizedBox(height: 28),
                    const Text('Espace chauffeur', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    const Text('Recevez vos courses et suivez vos gains.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (value) => (value ?? '').contains('@') ? null : 'Saisissez votre e-mail.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidden,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _hidden ? 'Afficher' : 'Masquer',
                          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hidden = !_hidden),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty ? 'Saisissez votre mot de passe.' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: _loading ? null : _submit,
                      child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Se connecter'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse('$siteUrl/reinitialiser-mot-de-passe'), mode: LaunchMode.externalApplication),
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
