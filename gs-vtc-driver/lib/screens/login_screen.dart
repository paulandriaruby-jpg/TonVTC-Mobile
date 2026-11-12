import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../config.dart';
import '../push/push_service.dart';
import '../theme.dart';

// Connexion réservée aux chauffeurs partenaires, dans le style de la page de connexion du site : la berline sur la
// route de montagne en haut, le formulaire dans une carte blanche. La session reste ouverte sur ce téléphone
// (renouvelée automatiquement) : pas de case "Se souvenir de moi". Mot de passe oublié et inscription : sur le site.
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
      setState(() {
        _error = error.message;
        _password.clear();
      });
    } catch (_) {
      setState(() => _error = 'Connexion impossible. Vérifiez votre réseau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String path) => launchUrl(Uri.parse('$siteUrl$path'), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Visual(height: (height * .36).clamp(240, 340)),
            Container(
              constraints: BoxConstraints(minHeight: height - (height * .36).clamp(240, 340) + 20),
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const Text('ESPACE CHAUFFEUR', style: TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          const Text('Heureux de vous retrouver', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1, letterSpacing: -.5)),
                          const SizedBox(height: 8),
                          const Text('Connectez-vous pour recevoir vos courses et suivre vos gains.', style: TextStyle(color: AppColors.muted, height: 1.5)),
                          const SizedBox(height: 24),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.dangerSoft, border: Border.all(color: const Color(0xFFF9C6CD)), borderRadius: BorderRadius.circular(6)),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                              ]),
                            ),
                            const SizedBox(height: 18),
                          ],
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Adresse e-mail', hintText: 'prenom.nom@exemple.fr'),
                            validator: (value) => (value ?? '').contains('@') ? null : 'Saisissez votre e-mail.',
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _password,
                            obscureText: _hidden,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              hintText: 'Votre mot de passe',
                              suffixIcon: IconButton(
                                tooltip: _hidden ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: const Color(0xFF667080)),
                                onPressed: () => setState(() => _hidden = !_hidden),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty ? 'Saisissez votre mot de passe.' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              onPressed: () => _open('/reinitialiser-mot-de-passe'),
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                                    SizedBox(width: 10),
                                    Text('Connexion en cours...'),
                                  ])
                                : const Text('Se connecter'),
                          ),
                          const SizedBox(height: 28),
                          const Divider(height: 1, color: Color(0xFFEAECF1)),
                          const SizedBox(height: 14),
                          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, spacing: 12, children: [
                            InkWell(
                              onTap: () => _open('/devenir-chauffeur'),
                              child: const Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: Color(0xFF667080)), children: [
                                TextSpan(text: 'Pas encore partenaire ? '),
                                TextSpan(text: 'Devenir chauffeur', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                              ])),
                            ),
                            const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF667080)),
                              SizedBox(width: 4),
                              Text('Connexion sécurisée', style: TextStyle(fontSize: 12, color: Color(0xFF667080))),
                            ]),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// La berline de nuit au-dessus d'Annecy, assombrie en bas pour le texte (comme le panneau gauche du site).
class _Visual extends StatelessWidget {
  const _Visual({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/accueil-nuit.webp', fit: BoxFit.cover, alignment: const Alignment(0, .35)),
        // Voile uni (pas de dégradé) pour lire le texte sur la photo.
        const ColoredBox(color: Color(0x99041325)),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Logo horizontal du kit, version fond sombre (fichier fourni, pas retapé dans une police).
              Image.asset('assets/images/logo-reversed.png', height: 34, semanticLabel: 'TonVTC'),
              const Spacer(),
              const Text('VOTRE VTC EN SAVOIE', style: TextStyle(color: Color(0xFFC7D0FF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('Les courses viennent à vous, au prix fixé à l\'avance.', style: TextStyle(color: Colors.white, fontSize: height < 280 ? 20 : 23, fontWeight: FontWeight.w800, height: 1.2)),
            ]),
          ),
        ),
      ]),
    );
  }
}
