import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../auth/auth_controller.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'login_sheet.dart';

// Mes courses : à venir et passées ; détail avec le chauffeur confirmé et l'annulation (frais affichés avant).
class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  List<Ride>? _upcoming;
  List<Ride>? _past;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthController>().state == AuthState.signedIn) _load();
  }

  Future<void> _load() async {
    final api = context.read<ClientApi>();
    try {
      final results = await Future.wait([api.rides('upcoming'), api.rides('past')]);
      if (mounted) {
        setState(() {
          _upcoming = results[0];
          _past = results[1];
        });
      }
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthController>().state == AuthState.signedIn;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes courses', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: signedIn ? const TabBar(tabs: [Tab(text: 'À venir'), Tab(text: 'Passées')]) : null,
        ),
        body: !signedIn
            ? EmptyState(icon: Icons.lock_outline, title: 'Connectez-vous pour voir vos courses', message: 'Avec Google ou votre e-mail.')
                .withAction(FilledButton(onPressed: () async {
                  if (await showLoginSheet(context)) await _load();
                }, child: const Text('Se connecter')))
            : TabBarView(children: [_list(_upcoming, 'Aucune course à venir'), _list(_past, 'Pas encore de course passée')]),
      ),
    );
  }

  Widget _list(List<Ride>? rides, String empty) {
    if (rides == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rides.isEmpty ? 1 : rides.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          if (rides.isEmpty) return EmptyState(icon: Icons.directions_car_outlined, title: empty);
          final ride = rides[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: ride.id!)));
                await _load();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${dayLabel(ride.departureAt)} · ${time(ride.departureAt)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    _statusPill(ride),
                  ]),
                  const SizedBox(height: 10),
                  RouteLines(pickup: shortAddress(ride.pickup), destination: shortAddress(ride.destination), dense: true),
                  const SizedBox(height: 8),
                  Text(money(ride.quotedPrice), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _statusPill(Ride ride) => switch (ride.status) {
      'accepted' || 'in_progress' => Pill(ride.statusLabel, color: AppColors.success, background: AppColors.successSoft),
      'completed' => Pill(ride.statusLabel, color: AppColors.muted, background: AppColors.surface),
      'cancelled' => Pill(ride.statusLabel, color: AppColors.danger, background: AppColors.dangerSoft),
      _ => Pill(ride.statusLabel, color: AppColors.accent, background: AppColors.accentSoft),
    };

extension on EmptyState {
  Widget withAction(Widget action) => Center(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [this, action])));
}

class RideDetailScreen extends StatefulWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final int rideId;

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  Ride? _ride;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ride = await context.read<ClientApi>().ride(widget.rideId);
      if (mounted) setState(() => _ride = ride);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  // Annulation : les frais éventuels sont annoncés avant de confirmer.
  Future<void> _cancel() async {
    final api = context.read<ClientApi>();
    try {
      final preview = await api.cancellationPreview(widget.rideId);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Annuler la course ?'),
          content: Text(preview.fee > 0 ? 'Des frais de ${money(preview.fee)} s’appliquent.' : 'L’annulation est gratuite.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Annuler la course')),
          ],
        ),
      );
      if (ok != true) return;
      await api.cancel(widget.rideId);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course annulée. Un e-mail vous confirme le détail.')));
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    return Scaffold(
      appBar: AppBar(title: Text(ride == null ? 'Course' : '${dayLabel(ride.departureAt)} · ${time(ride.departureAt)}')),
      body: ride == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Align(alignment: Alignment.centerLeft, child: _statusPill(ride)),
                const SizedBox(height: 12),
                SectionCard(child: RouteLines(pickup: ride.pickup, destination: ride.destination)),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Votre chauffeur', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    if (ride.driverName != null) ...[
                      Text(ride.driverName!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (ride.carName != null) Text('${ride.carName}${ride.carPlate != null ? ' · ${ride.carPlate}' : ''}', style: const TextStyle(color: AppColors.muted)),
                    ] else
                      const Text('Pas encore attribué : vous serez prévenu par e-mail.', style: TextStyle(color: AppColors.muted)),
                  ]),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _line('Référence', ride.reference.substring(0, ride.reference.length.clamp(0, 12))),
                    if (ride.returnAt != null) _line('Retour', '${dayLabel(ride.returnAt!)} à ${time(ride.returnAt!)}'),
                    if (ride.transportNumber != null) _line('Vol / train', ride.transportNumber!),
                    if (ride.signName != null) _line('Pancarte', ride.signName!),
                    _line('Prix', money(ride.quotedPrice)),
                    if (ride.promoDiscount > 0) _line('Code promo', '−${money(ride.promoDiscount)}'),
                    if (ride.creditUsed > 0) _line('Avoir', '−${money(ride.creditUsed)}'),
                    _line('Paiement', ride.paymentStatus == 'paid' ? 'Payée' : 'À régler : ${money(ride.amountDue)}'),
                  ]),
                ),
                if (ride.canCancel) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), onPressed: _cancel, icon: const Icon(Icons.close), label: const Text('Annuler la course')),
                ],
              ]),
            ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );
}
