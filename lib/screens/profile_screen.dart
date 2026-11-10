import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/driver_api.dart';
import '../auth/auth_controller.dart';
import '../config.dart';
import '../models/models.dart';
import '../push/push_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/driver_photo_card.dart';
import '../widgets/recruitment_card.dart';
import 'recruitment_details_screen.dart';
import 'legal_screen.dart';
import 'points_screen.dart';
import 'recruitment_cars_screen.dart';
import 'recruitment_documents_screen.dart';

// Profil : disponibilité (seuls les chauffeurs disponibles reçoivent les propositions), état des notifications,
// accès au dossier sur le site et déconnexion de cet appareil.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  DriverProfile? _profile;
  // Points : seulement une fois le dossier validé (les autres ne reçoivent pas encore de courses).
  DriverPoints? _points;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<DriverApi>();
      final profile = await api.profile();
      if (mounted) setState(() => _profile = profile);
      if (profile.validated) {
        final points = await api.points();
        if (mounted) setState(() => _points = points);
      }
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  Future<void> _editDetails() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<DriverProfile>(MaterialPageRoute(builder: (_) => RecruitmentDetailsScreen(profile: profile)));
    if (updated != null && mounted) {
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations enregistrées.')));
    }
  }

  Future<void> _editDocuments() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<DriverProfile>(MaterialPageRoute(builder: (_) => RecruitmentDocumentsScreen(profile: profile)));
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _editCars() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<DriverProfile>(MaterialPageRoute(builder: (_) => RecruitmentCarsScreen(profile: profile)));
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _setAvailable(bool value) async {
    setState(() => _saving = true);
    try {
      final profile = await context.read<DriverApi>().setAvailable(value);
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final push = context.read<PushService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.w800))),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              SectionCard(
                color: profile.available ? AppColors.successSoft : Colors.white,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: profile.available,
                  onChanged: _saving ? null : _setAvailable,
                  title: Text(profile.available ? 'Disponible' : 'Indisponible', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  subtitle: Text(profile.available ? 'Vous recevez les nouvelles courses.' : 'Aucune course ne vous sera proposée (pause, congés...).'),
                ),
              ),
              const SizedBox(height: 12),
              DriverPhotoCard(photo: profile.photo, onChanged: (_) => _load()),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${profile.firstName} ${profile.lastName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(profile.email, style: const TextStyle(color: AppColors.muted)),
                  if (profile.phone != null) Text(profile.phone!, style: const TextStyle(color: AppColors.muted)),
                  if (profile.validationLabel != null) ...[const SizedBox(height: 10), Pill(profile.validationLabel!)],
                ]),
              ),
              if (_points != null) ...[
                const SizedBox(height: 12),
                PointsCard(data: _points!, onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PointsScreen()));
                  await _load();
                }),
              ],
              if (!profile.validated) ...[
                const SizedBox(height: 12),
                RecruitmentCard(profile: profile, onEditDetails: _editDetails, onEditDocuments: _editDocuments, onEditCars: _editCars),
              ],
              const SizedBox(height: 12),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: Icon(push.available ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: push.available ? AppColors.success : AppColors.danger),
                    title: const Text('Notifications'),
                    subtitle: Text(push.available
                        ? (push.token != null ? 'Actives sur ce téléphone.' : 'Autorisez les notifications dans les réglages du téléphone.')
                        : 'Indisponibles dans cette version de test (Firebase non configuré).'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('Mon dossier et mes véhicules'),
                    subtitle: const Text('Sur le site'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => launchUrl(Uri.parse('$siteUrl/espace/recrutement'), mode: LaunchMode.externalApplication),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined),
                    title: const Text('Contacter l\'équipe TonVTC'),
                    subtitle: const Text('contact@tonvtc.com'),
                    trailing: const Icon(Icons.mail_outline, size: 18),
                    onTap: () => launchUrl(Uri(scheme: 'mailto', path: 'contact@tonvtc.com')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('Informations légales'),
                    subtitle: const Text('Mentions légales, CGV, confidentialité'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen())),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: dangerOutline(),
                onPressed: () => context.read<AuthController>().logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter de ce téléphone'),
              ),
            ]),
    );
  }
}
