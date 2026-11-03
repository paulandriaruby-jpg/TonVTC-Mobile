import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../config.dart';
import '../theme.dart';

// Connexion du client, en bas de l'écran : Google (coordonnées reprises du compte), e-mail, ou création de compte.
// Renvoie true une fois connecté.
Future<bool> showLoginSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _LoginSheet());
  return result ?? false;
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet();

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

enum _Mode { choice, login, register }

class _LoginSheetState extends State<_LoginSheet> {
  _Mode _mode = _Mode.choice;
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _attempt(Future<bool> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await action() && mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Connexion impossible. Vérifiez votre réseau.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() => _attempt(() => context.read<AuthController>().loginWithGoogle());

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    await _attempt(() async {
      if (_mode == _Mode.login) {
        await auth.loginWithEmail(_email.text, _password.text);
      } else {
        await auth.register(firstName: _first.text, lastName: _last.text, email: _email.text, phone: _phone.text, password: _password.text);
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(switch (_mode) { _Mode.choice => 'Connectez-vous pour réserver', _Mode.login => 'Se connecter', _Mode.register => 'Créer mon compte' },
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Vos coordonnées sont reprises automatiquement et vous retrouvez vos courses dans l’app.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          if (_mode == _Mode.choice) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.line)),
              onPressed: _busy ? null : _google,
              icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
              label: Text(auth.googleAvailable ? 'Continuer avec Google' : 'Continuer avec Google (bientôt)'),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _busy ? null : () => setState(() => _mode = _Mode.login), child: const Text('Se connecter avec un e-mail')),
            const SizedBox(height: 6),
            TextButton(onPressed: _busy ? null : () => setState(() => _mode = _Mode.register), child: const Text('Créer un compte')),
          ] else
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_mode == _Mode.register) ...[
                    Row(children: [
                      Expanded(child: TextFormField(controller: _first, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.givenName],
                          decoration: const InputDecoration(labelText: 'Prénom'), validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null)),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _last, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.familyName],
                          decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null)),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(controller: _phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
                        validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? 'Numéro invalide' : null),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (v) => (v ?? '').contains('@') ? null : 'E-mail invalide'),
                  const SizedBox(height: 12),
                  TextFormField(controller: _password, obscureText: true,
                      autofillHints: [_mode == _Mode.register ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(labelText: 'Mot de passe', prefixIcon: const Icon(Icons.lock_outline), helperText: _mode == _Mode.register ? '8 caractères minimum' : null),
                      validator: (v) => (v ?? '').length < (_mode == _Mode.register ? 8 : 1) ? (_mode == _Mode.register ? '8 caractères minimum' : 'Obligatoire') : null,
                      onFieldSubmitted: (_) => _submit()),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(_mode == _Mode.login ? 'Se connecter' : 'Créer mon compte'),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton(onPressed: () => setState(() => _mode = _Mode.choice), child: const Text('Retour')),
                    if (_mode == _Mode.login)
                      TextButton(onPressed: () => launchUrl(Uri.parse('$siteUrl/reinitialiser-mot-de-passe'), mode: LaunchMode.externalApplication), child: const Text('Mot de passe oublié ?')),
                  ]),
                ]),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
    );
  }
}
