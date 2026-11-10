import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../config.dart';
import '../legal/legal.dart';
import '../theme.dart';

// Connexion du client, en bas de l'écran : Google (compte retrouvé, ou créé s'il n'existe pas) ou e-mail et mot de
// passe. Pas de création de compte ici : sans Google, le compte est créé à la première réservation. `email` ouvre
// directement la connexion par e-mail (compte déjà existant). Renvoie true une fois connecté.
Future<bool> showLoginSheet(BuildContext context, {String? email, String? phone}) async {
  final result = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _LoginSheet(email: email, phone: phone));
  return result ?? false;
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet({this.email, this.phone});

  final String? email;
  final String? phone;

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  late bool _withEmail = widget.email != null;
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email ?? '');
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

  Future<void> _google() => _attempt(() => context.read<AuthController>().loginWithGoogle(phone: widget.phone));

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    await _attempt(() async {
      await auth.loginWithEmail(_email.text, _password.text);
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
          Text(widget.email != null ? 'Vous avez déjà un compte' : 'Se connecter', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            widget.email != null
                ? 'Connectez-vous pour réserver avec ce compte et retrouver vos courses.'
                : 'Vos coordonnées sont reprises automatiquement et vous retrouvez vos courses dans l\'app.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.line)),
            onPressed: _busy ? null : _google,
            icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
            label: Text(auth.googleAvailable ? 'Continuer avec Google' : 'Continuer avec Google (bientôt)'),
          ),
          const SizedBox(height: 10),
          if (!_withEmail)
            FilledButton(onPressed: _busy ? null : () => setState(() => _withEmail = true), child: const Text('Se connecter avec un e-mail'))
          else
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 4),
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (v) => (v ?? '').contains('@') ? null : 'E-mail invalide'),
                  const SizedBox(height: 12),
                  TextFormField(controller: _password, obscureText: true, autofocus: widget.email != null, autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) => (v ?? '').isEmpty ? 'Obligatoire' : null,
                      onFieldSubmitted: (_) => _submit()),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Se connecter'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => launchUrl(Uri.parse('$siteUrl/reinitialiser-mot-de-passe'), mode: LaunchMode.externalApplication),
                      child: const Text('Mot de passe oublié ou jamais choisi ?'),
                    ),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 6),
          const TermsLine(lead: 'En continuant avec Google, vous acceptez nos ', textAlign: TextAlign.center, fontSize: 12),
          if (widget.email == null) ...[
            const SizedBox(height: 10),
            const Text('Pas encore de compte ? Réservez simplement : il est créé avec vos coordonnées.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
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
