import 'package:flutter/material.dart';

import '../models/models.dart';
import '../recruitment/document_picker.dart';
import '../recruitment/recruitment.dart';
import '../theme.dart';
import 'common.dart';

// Appareil photo, galerie ou PDF.
Future<PickSource?> chooseDocumentSource(BuildContext context) => showModalBottomSheet<PickSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Prendre une photo'), onTap: () => Navigator.pop(context, PickSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(context, PickSource.gallery)),
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Choisir un PDF'), onTap: () => Navigator.pop(context, PickSource.file)),
        ]),
      ),
    );

Future<bool> confirmRemoveDocument(BuildContext context, DriverDocument document) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce fichier ?'),
        content: Text(document.filename),
        actions: [
          const DialogCancel('Garder'),
          const DialogConfirm('Supprimer', danger: true),
        ],
      ),
    ) ??
    false;

// Une pièce du dossier : état (à fournir / reçu), fichiers envoyés, ajout et suppression, et champs liés (`children`).
class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.spec,
    required this.files,
    required this.missing,
    required this.locked,
    required this.busy,
    required this.disabled,
    required this.onAdd,
    required this.onRemove,
    this.children = const [],
  });

  final DocumentSpec spec;
  final List<DriverDocument> files;
  final bool missing;
  final bool locked;
  // Envoi ou suppression en cours pour cette pièce ; `disabled` : une autre pièce est en cours.
  final bool busy;
  final bool disabled;
  final VoidCallback onAdd;
  final void Function(DriverDocument document) onRemove;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          if (missing) const Pill('À fournir', color: AppColors.accent, background: AppColors.accentSoft) else const Pill('Reçu', color: AppColors.success, background: AppColors.successSoft),
        ]),
        Text(spec.hint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 8),
        for (final file in files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(file.filename.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: AppColors.brand),
            title: Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(fileSize(file.byteSize)),
            trailing: locked ? null : IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: disabled || busy ? null : () => onRemove(file)),
          ),
        if (busy)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
        else if (!locked && files.length < spec.max)
          OutlinedButton.icon(onPressed: disabled ? null : onAdd, icon: const Icon(Icons.add_a_photo_outlined), label: Text(files.isEmpty ? 'Ajouter' : 'Ajouter le verso')),
        ...children,
      ]),
    );
  }
}
