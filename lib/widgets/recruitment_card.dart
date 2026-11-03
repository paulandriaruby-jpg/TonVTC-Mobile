import 'package:flutter/material.dart';

import '../models/models.dart';
import '../recruitment/recruitment.dart';
import '../theme.dart';
import 'common.dart';

// Avancement du dossier de recrutement : étape sur 5 et ce qu'il reste à fournir.
class RecruitmentCard extends StatelessWidget {
  const RecruitmentCard({super.key, required this.profile, this.onEditDetails, this.onEditDocuments, this.onEditCars});

  final DriverProfile profile;
  // Ouvre le formulaire des informations ; absent quand la fiche est seulement informative (Courses, Gains).
  final VoidCallback? onEditDetails;
  // Ouvre l'écran des documents (pièces, numéros et dates de validité).
  final VoidCallback? onEditDocuments;
  // Ouvre la liste des véhicules.
  final VoidCallback? onEditCars;

  @override
  Widget build(BuildContext context) {
    final status = profile.validationStatus ?? 'identified';
    final missing = [...profile.detailsMissing, ...profile.documentsMissing];
    final waiting = waitingForTeam(status);
    return SectionCard(
      color: waiting ? AppColors.successSoft : AppColors.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Dossier de recrutement', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Pill('${stepNumber(status)}/5', color: waiting ? AppColors.success : AppColors.accent, background: Colors.white),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stepNumber(status) / 5,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: waiting ? AppColors.success : AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(stepTitle(status), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (waiting)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Notre équipe vérifie votre dossier. Vous serez prévenu par e-mail dès que votre compte est activé.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Il reste à fournir :', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            for (final key in missing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.radio_button_unchecked, size: 14, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(missingLabel(key))),
                  ],
                ),
              ),
          ],
          if (onEditDetails != null) ...[
            const SizedBox(height: 12),
            if (profile.detailsMissing.isNotEmpty && !profile.locked)
              FilledButton(onPressed: onEditDetails, child: const Text('Compléter mes informations'))
            else
              OutlinedButton(onPressed: onEditDetails, child: Text(profile.locked ? 'Voir mes informations' : 'Modifier mes informations')),
          ],
          if (onEditDocuments != null) ...[
            const SizedBox(height: 8),
            // Les pièces personnelles, hors véhicule (étape suivante).
            if (profile.detailsMissing.isEmpty && !profile.locked && profile.documentsMissing.any((key) => key != 'car'))
              FilledButton(onPressed: onEditDocuments, child: const Text('Ajouter mes documents'))
            else
              OutlinedButton(onPressed: onEditDocuments, child: Text(profile.locked ? 'Voir mes documents' : 'Mes documents')),
          ],
          if (onEditCars != null) ...[
            const SizedBox(height: 8),
            // Le véhicule vient après les informations et les pièces personnelles.
            if (profile.detailsMissing.isEmpty && !profile.locked && profile.documentsMissing.every((key) => key == 'car') && profile.documentsMissing.contains('car'))
              FilledButton(onPressed: onEditCars, child: Text(profile.cars.isEmpty ? 'Ajouter mon véhicule' : 'Compléter mon véhicule'))
            else
              OutlinedButton(onPressed: onEditCars, child: Text(profile.cars.isEmpty ? 'Mon véhicule' : (profile.cars.length > 1 ? 'Mes véhicules' : 'Mon véhicule'))),
          ],
        ],
      ),
    );
  }
}

// Courses et Gains tant que le dossier n'est pas validé : explication à la place d'erreurs de l'API.
class RecruitmentPending extends StatelessWidget {
  const RecruitmentPending({super.key, required this.profile, required this.onOpenProfile, required this.onRefresh, required this.title});

  final DriverProfile profile;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onRefresh;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const EmptyState(
              icon: Icons.hourglass_top,
              title: 'Votre dossier n’est pas encore validé',
              message: 'Les courses et les gains s’ouvrent dès que votre compte est activé.',
            ),
            RecruitmentCard(profile: profile),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onOpenProfile, child: const Text('Voir mon profil')),
          ],
        ),
      ),
    );
  }
}
