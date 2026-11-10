import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../auth/auth_controller.dart';
import '../models/models.dart';
import '../theme.dart';
import 'feedback_screen.dart';
import 'legal_screen.dart';
import '../widgets/common.dart';
import 'login_sheet.dart';

// Compte : coordonnées utilisées pour réserver (modifiables), déconnexion de ce téléphone.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Profile? _profile;
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthController>().state == AuthState.signedIn) _load();
  }

  Future<void> _load() async {
    try {
      final profile = await context.read<ClientApi>().profile();
      if (!mounted) return;
      _first.text = profile.firstName;
      _last.text = profile.lastName;
      _phone.text = profile.phone;
      setState(() => _profile = profile);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final profile = await context.read<ClientApi>().updateProfile(firstName: _first.text.trim(), lastName: _last.text.trim(), phone: _phone.text.trim());
      if (!mounted) return;
      setState(() => _profile = profile);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordonnées enregistrées.')));
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Compte', style: TextStyle(fontWeight: FontWeight.w800))),
      body: auth.state != AuthState.signedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const EmptyState(icon: Icons.person_outline, title: 'Pas encore connecté', message: 'Connectez-vous avec Google ou votre e-mail. Pas encore de compte ? Il est créé à votre première réservation.'),
                  FilledButton(onPressed: () async {
                    if (await showLoginSheet(context)) await _load();
                  }, child: const Text('Se connecter')),
                  const SizedBox(height: 12),
                  const _LegalTile(),
                ]),
              ),
            )
          : _profile == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  SectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(_profile!.email, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 12),
                      TextField(controller: _first, decoration: const InputDecoration(labelText: 'Prénom')),
                      const SizedBox(height: 10),
                      TextField(controller: _last, decoration: const InputDecoration(labelText: 'Nom')),
                      const SizedBox(height: 10),
                      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined))),
                      const SizedBox(height: 14),
                      FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline, color: AppColors.brand),
                      title: const Text('Nous écrire'),
                      subtitle: const Text('Une suggestion, un souci, un compliment'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _LegalTile(),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: dangerOutline(),
                    onPressed: auth.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter de ce téléphone'),
                  ),
                ]),
    );
  }
}

// Accès aux informations légales (mentions légales, CGV, confidentialité).
class _LegalTile extends StatelessWidget {
  const _LegalTile();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.gavel_outlined, color: AppColors.brand),
        title: const Text('Informations légales'),
        subtitle: const Text('Mentions légales, CGV, confidentialité'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen())),
      ),
    );
  }
}
