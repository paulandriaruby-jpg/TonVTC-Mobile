import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/driver_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

String points(int value) => '${value > 0 ? '+' : ''}$value pt${value.abs() > 1 ? 's' : ''}';

// Phrase qui explique la priorité (ou son absence).
String priorityExplanation(DriverPoints data) => data.priorityEnabled
    ? 'Les chauffeurs qui ont le plus de points reçoivent chaque nouvelle course ${data.priorityMinutes} min avant les autres.'
    : 'Les points mesurent votre participation. La priorité sur les nouvelles courses est désactivée pour le moment.';

// Carte du profil : score, rang et priorité ; ouvre le détail.
class PointsCard extends StatelessWidget {
  const PointsCard({super.key, required this.data, required this.onTap});

  final DriverPoints data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(color: AppColors.ink),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mes points', style: TextStyle(color: Color(0xFFC7D0FF), fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${data.score}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 4),
                Text(
                  data.rank == null ? 'Sur ${data.windowDays} jours' : '${data.rank == 1 ? '1er' : '${data.rank}e'} parmi les autres chauffeurs -${data.windowDays} derniers jours',
                  style: const TextStyle(color: Color(0xFFD3D9E4), fontSize: 13),
                ),
              ]),
            ),
            _PriorityBadge(data: data, dark: true),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ]),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.data, this.dark = false});

  final DriverPoints data;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (!data.priorityEnabled) return const SizedBox.shrink();
    if (data.prioritized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFB400), borderRadius: BorderRadius.circular(8)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt, size: 16, color: AppColors.ink),
          SizedBox(width: 4),
          Text('Prioritaire', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      );
    }
    if (data.pointsToPriority == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: dark ? Colors.white12 : AppColors.brandSoft, borderRadius: BorderRadius.circular(8)),
      child: Text('Encore ${data.pointsToPriority} pts', style: TextStyle(color: dark ? Colors.white : AppColors.brand, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// Détail : statut de priorité, barème, historique.
class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  DriverPoints? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<DriverApi>().points();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes points')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                PointsCard(data: data, onTap: () {}),
                const SizedBox(height: 12),
                SectionCard(
                  color: data.prioritized ? const Color(0xFFFFF7E0) : AppColors.brandSoft,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(data.prioritized ? Icons.bolt : Icons.trending_up, color: data.prioritized ? const Color(0xFF8A6100) : AppColors.brand),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          !data.priorityEnabled
                              ? 'Votre participation'
                              : data.prioritized
                                  ? 'Vous êtes prioritaire'
                                  : data.pointsToPriority != null
                                      ? 'Encore ${data.pointsToPriority} points pour être prioritaire'
                                      : 'Gagnez des points pour être prioritaire',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(priorityExplanation(data), style: const TextStyle(color: AppColors.muted, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                const Text('Comment gagner des points', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(children: [
                    for (final rule in data.rules)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Expanded(child: Text(rule.label)),
                          _PointsPill(rule.points),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Text('Le score compte les points des ${data.windowDays} derniers jours.', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 20),
                const Text('Historique', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (data.entries.isEmpty)
                  const EmptyState(icon: Icons.emoji_events_outlined, title: 'Pas encore de points', message: 'Acceptez et terminez vos premières courses pour en gagner.')
                else
                  SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final (index, entry) in data.entries.indexed) ...[
                        if (index > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(entry.label, style: TextStyle(color: entry.counted ? AppColors.ink : AppColors.muted)),
                          subtitle: Text([dateTime(entry.createdAt), if (entry.bookingReference != null) entry.bookingReference!, if (!entry.counted) 'plus compté'].join(' - ')),
                          trailing: _PointsPill(entry.points, faded: !entry.counted),
                        ),
                      ],
                    ]),
                  ),
              ]),
            ),
    );
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill(this.value, {this.faded = false});

  final int value;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final positive = value > 0;
    return Opacity(
      opacity: faded ? .5 : 1,
      child: Pill(points(value), color: positive ? AppColors.success : AppColors.danger, background: positive ? AppColors.successSoft : AppColors.dangerSoft),
    );
  }
}
