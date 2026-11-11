import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../auth/auth_controller.dart';
import '../booking/recent_places.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'feedback_screen.dart';
import 'legal_screen.dart';
import '../widgets/common.dart';
import 'login_sheet.dart';

// Compte : coordonnées utilisées pour réserver (modifiables), déconnexion de ce téléphone, suppression du compte.
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

  // Suppression du compte : l'API dit d'abord ce qui l'empêche ou ce qui sera perdu, puis on confirme. Le compte est
  // anonymisé côté serveur (courses et reçus gardés sans les coordonnées) ; le téléphone oublie la session et les adresses.
  Future<void> _deleteAccount() async {
    final api = context.read<ClientApi>();
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final check = await api.deletionCheck();
      if (!mounted) return;
      if (!check.allowed) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Suppression impossible pour le moment'),
            content: Text(check.reason ?? 'Réessayez plus tard.'),
            actions: const [DialogCancel('Fermer')],
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Supprimer votre compte ?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cette action est définitive.'),
            const SizedBox(height: 10),
            const Text('- Votre nom, votre e-mail, votre téléphone et votre photo sont effacés.'),
            const SizedBox(height: 4),
            const Text('- Vous ne pourrez plus vous connecter à ce compte.'),
            const SizedBox(height: 4),
            const Text('- Vos courses passées et leurs reçus restent conservés pour la durée légale, de façon anonyme.'),
            if (check.creditBalance > 0) ...[
              const SizedBox(height: 10),
              Text('Votre avoir restant de ${money(check.creditBalance)} sera perdu.', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ],
          ]),
          actions: const [DialogCancel('Retour'), DialogConfirm('Supprimer', danger: true)],
        ),
      );
      if (confirmed != true) return;
      await api.deleteAccount();
      await RecentPlaces().clear();
      await auth.forget();
      messenger.showSnackBar(const SnackBar(content: Text('Votre compte a été supprimé.')));
    } catch (error) {
      if (mounted) handleError(context, error);
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
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: _deleteAccount,
                    child: const Text('Supprimer mon compte'),
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
