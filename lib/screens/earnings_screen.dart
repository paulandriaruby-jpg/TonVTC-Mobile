import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/driver_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

// Gains : mois en cours, à recevoir, mois précédents et relevés mensuels (même calcul que "Mes gains" sur le site).
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Earnings? _earnings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final earnings = await context.read<DriverApi>().earnings();
      if (mounted) setState(() => _earnings = earnings);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnings = _earnings;
    return Scaffold(
      appBar: AppBar(title: const Text('Gains', style: TextStyle(fontWeight: FontWeight.w800))),
      body: earnings == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _hero(earnings),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _tile('À recevoir', money(earnings.toReceive), 'versé avec le relevé mensuel', AppColors.accentSoft)),
                  const SizedBox(width: 12),
                  Expanded(child: _tile('Attente client', money(earnings.awaitingClient), 'dû dès que le client a payé', Colors.white)),
                ]),
                const SizedBox(height: 12),
                SectionCard(
                  child: Row(children: [
                    Icon(Icons.schedule, color: (earnings.punctualityRate ?? 100) >= 90 ? AppColors.success : AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(earnings.punctualityRate == null ? 'Ponctualité : pas encore de course' : 'Ponctualité : ${earnings.punctualityRate} %', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(earnings.arrivals == 0
                            ? 'Calculée sur vos arrivées des 3 derniers mois.'
                            : '${earnings.lateArrivals} retard(s) sur ${earnings.arrivals} arrivée(s) - 3 derniers mois - retard à partir de ${earnings.lateToleranceMinutes} min',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                const Text('Mois précédents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ..._previous(earnings),
                const SizedBox(height: 20),
                const Text('Relevés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (earnings.payouts.isEmpty)
                  const SectionCard(child: Text('Aucun relevé pour l\'instant : il est établi chaque mois pour les courses terminées et payées.', style: TextStyle(color: AppColors.muted)))
                else
                  ...earnings.payouts.map(_payout),
              ]),
            ),
    );
  }

  Widget _hero(Earnings earnings) {
    final month = earnings.months.first;
    final keep = (100 - earnings.commissionRate).toStringAsFixed(earnings.commissionRate % 1 == 0 ? 0 : 1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${monthLabel(month.month)} (en cours)', style: const TextStyle(color: Color(0xFFE3E8FF))),
        const SizedBox(height: 6),
        Text(money(month.earned), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('${month.count} course(s) - vous touchez $keep % de chaque course', style: const TextStyle(color: Color(0xFFE3E8FF), fontSize: 13)),
      ]),
    );
  }

  Widget _tile(String label, String value, String hint, Color color) => SectionCard(
        color: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ]),
      );

  List<Widget> _previous(Earnings earnings) {
    final months = earnings.months.skip(1).where((m) => m.count > 0).toList();
    if (months.isEmpty) return [const SectionCard(child: Text('Pas encore de course les mois précédents.', style: TextStyle(color: AppColors.muted)))];
    return [
      SectionCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final month in months)
            ListTile(
              title: Text(monthLabel(month.month), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${month.count} course(s) - versé ${money(month.paid)}'),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(month.earned), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (month.toReceive > 0) Text('${money(month.toReceive)} à recevoir', style: const TextStyle(color: AppColors.accent, fontSize: 12)),
              ]),
            ),
        ]),
      ),
    ];
  }

  Widget _payout(Payout payout) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SectionCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(payout.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${payout.count} course(s)${payout.paidAt != null ? ' - versé le ${dateTime(payout.paidAt!).split(' à ').first}' : ''}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(payout.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              payout.paid
                  ? const Pill('Versé', color: AppColors.success, background: AppColors.successSoft)
                  : const Pill('En préparation'),
            ]),
          ]),
        ),
      );
}
