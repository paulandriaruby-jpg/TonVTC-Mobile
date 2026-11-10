import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';

// Erreur d'appel : session perdue -> déconnexion (le client se reconnecte pour réserver) ; sinon message en bas de l'écran.
void handleError(BuildContext context, Object error) {
  if (error is SessionExpired) {
    context.read<AuthController>().expired();
    return;
  }
  final message = error is ApiException ? error.message : 'Connexion impossible. Vérifiez votre réseau.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(color: color, child: Padding(padding: padding, child: child));
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(children: [
        Icon(icon, size: 40, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ],
      ]),
    );
  }
}

// Petite étiquette de couleur (état de la course, versement).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = AppColors.brand, this.background = AppColors.brandSoft});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

// Départ -> arrivée, avec un point et un carré comme sur le site.
class RouteLines extends StatelessWidget {
  const RouteLines({super.key, required this.pickup, required this.destination, this.dense = false});

  final String pickup;
  final String destination;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: dense ? 14 : 15, fontWeight: FontWeight.w600, color: AppColors.ink);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 2.5))),
        const SizedBox(width: 10),
        Expanded(child: Text(pickup, style: style, maxLines: dense ? 1 : 3, overflow: TextOverflow.ellipsis)),
      ]),
      Padding(padding: const EdgeInsets.only(left: 4), child: Container(width: 2, height: dense ? 10 : 14, color: AppColors.line)),
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), border: Border.all(color: AppColors.accent, width: 2.5))),
        const SizedBox(width: 10),
        Expanded(child: Text(destination, style: style, maxLines: dense ? 1 : 3, overflow: TextOverflow.ellipsis)),
      ]),
    ]);
  }
}

// Photo du chauffeur (vérifiée par l'équipe), ou ses initiales à défaut ; touchée, elle s'agrandit.
class DriverAvatar extends StatelessWidget {
  const DriverAvatar({super.key, required this.url, this.radius = 28});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surface,
      foregroundImage: url == null ? null : NetworkImage(url!),
      child: Icon(Icons.person, size: radius, color: AppColors.muted),
    );
    if (url == null) return avatar;
    return Semantics(
      button: true,
      label: 'Agrandir la photo du chauffeur',
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.network(url!, fit: BoxFit.cover),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
            ]),
          ),
        ),
        child: avatar,
      ),
    );
  }
}
