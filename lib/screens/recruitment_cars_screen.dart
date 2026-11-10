import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'recruitment_car_screen.dart';

// Véhicules du chauffeur : au moins un, avec ses pièces complètes, est nécessaire pour avancer à 4/5.
class RecruitmentCarsScreen extends StatefulWidget {
  const RecruitmentCarsScreen({super.key, required this.profile});

  final DriverProfile profile;

  @override
  State<RecruitmentCarsScreen> createState() => _RecruitmentCarsScreenState();
}

class _RecruitmentCarsScreenState extends State<RecruitmentCarsScreen> {
  late DriverProfile _profile = widget.profile;

  Future<void> _open({DriverCar? car}) async {
    final updated = await Navigator.of(context).push<DriverProfile>(MaterialPageRoute(builder: (_) => RecruitmentCarScreen(profile: _profile, carId: car?.id)));
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    final cars = _profile.cars;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_profile);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mon véhicule')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (cars.isEmpty)
            const EmptyState(icon: Icons.directions_car_outlined, title: 'Aucun véhicule', message: 'Ajoutez le véhicule avec lequel vous prendrez les courses, puis ses documents.'),
          for (final car in cars)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _open(car: car),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.directions_car_filled, color: AppColors.brand),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(car.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text([car.plateNumber, if (car.vehicleTypeName != null) car.vehicleTypeName!].join(' - '), style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 6),
                          if (car.documentsMissing.isEmpty)
                            Pill(car.validationLabel, color: car.validated ? AppColors.success : AppColors.brand, background: car.validated ? AppColors.successSoft : AppColors.brandSoft)
                          else
                            Pill('${car.documentsMissing.length} document${car.documentsMissing.length > 1 ? 's' : ''} à fournir', color: AppColors.accent, background: AppColors.accentSoft),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ]),
                  ),
                ),
              ),
            ),
          // Même dossier figé (5/5), le chauffeur peut ajouter ou changer de véhicule : seuls ses informations et ses pièces sont figées.
          OutlinedButton.icon(onPressed: () => _open(), icon: const Icon(Icons.add), label: Text(cars.isEmpty ? 'Ajouter mon véhicule' : 'Ajouter un autre véhicule')),
        ]),
      ),
    );
  }
}
