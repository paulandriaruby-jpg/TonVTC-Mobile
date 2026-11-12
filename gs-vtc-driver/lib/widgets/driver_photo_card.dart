import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/driver_api.dart';
import '../models/models.dart';
import '../recruitment/document_picker.dart';
import '../theme.dart';
import 'common.dart';

// Photo du chauffeur, montrée au client qui fait la course pour qu'il le reconnaisse (et ne monte pas avec un faux
// chauffeur). Selfie avec l'appareil de face, ou photo de la galerie ; l'équipe la vérifie avant de l'afficher.
class DriverPhotoCard extends StatefulWidget {
  const DriverPhotoCard({super.key, required this.photo, required this.onChanged});

  final DriverPhoto photo;
  final ValueChanged<DriverPhoto> onChanged;

  @override
  State<DriverPhotoCard> createState() => _DriverPhotoCardState();
}

class _DriverPhotoCardState extends State<DriverPhotoCard> {
  bool _sending = false;

  Future<void> _change() async {
    final source = await showModalBottomSheet<PickSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Votre photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('De face, visage bien visible et éclairé, sans lunettes de soleil ni casquette. Le client la voit pour vous reconnaître.', style: TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.camera_front_outlined, color: AppColors.brand), title: const Text('Prendre un selfie'), onTap: () => Navigator.pop(context, PickSource.selfie)),
            ListTile(leading: const Icon(Icons.photo_library_outlined, color: AppColors.brand), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(context, PickSource.gallery)),
          ]),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final api = context.read<DriverApi>();
    final picked = await context.read<DocumentPicker>().pick(source);
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final photo = await api.uploadPhoto(bytes: picked.bytes, filename: picked.filename);
      widget.onChanged(photo);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo envoyée : l\'équipe la vérifie avant de la montrer aux clients.')));
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final base = context.read<DriverApi>().client.baseUrl;
    final shown = photo.pendingUrl ?? photo.url;
    final (title, message, color, background) = photo.pending
        ? ('Photo en cours de vérification', 'Les clients verront cette photo dès que l\'équipe l\'aura validée.${photo.url != null ? ' En attendant, ils voient l\'ancienne.' : ''}', AppColors.brand, AppColors.brandSoft)
        : photo.rejected
            ? ('Photo refusée', '${photo.rejectionReason ?? 'Elle ne permet pas de vous reconnaître.'} Envoyez-en une nouvelle.', AppColors.danger, AppColors.dangerSoft)
            : photo.url != null
                ? ('Votre photo', 'Le client la voit avant la course pour vous reconnaître.', AppColors.success, AppColors.successSoft)
                : ('Ajoutez votre photo', 'Obligatoire : le client la voit pour vous reconnaître et éviter les faux chauffeurs.', AppColors.accent, AppColors.accentSoft);
    return SectionCard(
      color: background,
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            foregroundImage: shown == null ? null : NetworkImage('$base$shown'),
            child: const Icon(Icons.person, size: 40, color: AppColors.muted),
          ),
          if (photo.pending)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_top, size: 16, color: AppColors.brand),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(message, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), backgroundColor: Colors.white, foregroundColor: AppColors.ink),
                onPressed: _sending ? null : _change,
                icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_front_outlined, size: 18),
                label: Text(photo.missing ? 'Ajouter ma photo' : 'Changer ma photo'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
