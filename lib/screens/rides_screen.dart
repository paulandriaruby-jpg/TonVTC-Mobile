import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/driver_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'ride_detail_screen.dart';

// Courses : propositions à accepter (le premier qui accepte l'obtient), courses à faire, historique.
class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => RidesScreenState();
}

class RidesScreenState extends State<RidesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  List<Proposal>? _proposals;
  List<Ride>? _upcoming;
  List<Ride>? _past;
  final Set<int> _busy = {};

  DriverApi get _api => context.read<DriverApi>();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // Ouverture depuis une notification « nouvelle course ».
  void showProposals() {
    _tabs.animateTo(0);
    _loadProposals();
  }

  Future<void> _loadAll() => Future.wait([_loadProposals(), _loadUpcoming(), _loadPast()]);

  Future<void> _loadProposals() async {
    try {
      final list = await _api.proposals();
      if (mounted) setState(() => _proposals = list);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  Future<void> _loadUpcoming() async {
    try {
      final list = await _api.rides('upcoming');
      if (mounted) setState(() => _upcoming = list);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  Future<void> _loadPast() async {
    try {
      final list = await _api.rides('past');
      if (mounted) setState(() => _past = list);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  Future<void> _accept(Proposal proposal) async {
    setState(() => _busy.add(proposal.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ride = await _api.acceptProposal(proposal.id);
      messenger.showSnackBar(const SnackBar(content: Text('Course acceptée : elle est dans « À venir ».')));
      await _loadAll();
      _tabs.animateTo(1);
      if (mounted) await _openRide(ride.id);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.status == 409 ? 'Trop tard : la course a déjà été attribuée.' : error.message)));
      await _loadProposals();
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _busy.remove(proposal.id));
    }
  }

  Future<void> _decline(Proposal proposal) async {
    setState(() => _busy.add(proposal.id));
    try {
      await _api.declineProposal(proposal.id);
      await _loadProposals();
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _busy.remove(proposal.id));
    }
  }

  Future<void> _openRide(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: id)));
    await Future.wait([_loadUpcoming(), _loadPast()]);
  }

  @override
  Widget build(BuildContext context) {
    final count = _proposals?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(controller: _tabs, tabs: [
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Propositions'),
            if (count > 0) ...[const SizedBox(width: 6), Badge(label: Text('$count'), backgroundColor: AppColors.accent)],
          ])),
          const Tab(text: 'À venir'),
          const Tab(text: 'Historique'),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _list(_proposals, _loadProposals, (p) => _ProposalCard(proposal: p, busy: _busy.contains(p.id), onAccept: () => _accept(p), onDecline: () => _decline(p)),
            const EmptyState(icon: Icons.notifications_none, title: 'Aucune course proposée', message: 'Vous recevez une notification dès qu’une course vous est proposée.')),
        _list(_upcoming, _loadUpcoming, (r) => _RideCard(ride: r, onTap: () => _openRide(r.id)),
            const EmptyState(icon: Icons.event_available, title: 'Aucune course à venir')),
        _list(_past, _loadPast, (r) => _RideCard(ride: r, onTap: () => _openRide(r.id)),
            const EmptyState(icon: Icons.history, title: 'Pas encore de course terminée')),
      ]),
    );
  }

  Widget _list<T>(List<T>? items, Future<void> Function() reload, Widget Function(T) card, Widget empty) {
    if (items == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.isEmpty ? 1 : items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => items.isEmpty ? empty : card(items[index]),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal, required this.busy, required this.onAccept, required this.onDecline});

  final Proposal proposal;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final extras = [
      '${proposal.distanceKm.toStringAsFixed(0)} km · ${proposal.durationMinutes.round()} min',
      if (proposal.transportNumber != null) 'Vol / train ${proposal.transportNumber}',
      if (proposal.roundTrip) 'Aller-retour',
      if (proposal.babySeats + proposal.boosterSeats > 0) '${proposal.babySeats + proposal.boosterSeats} siège(s) enfant',
    ].join(' · ');
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${dayLabel(proposal.departureAt)} · ${time(proposal.departureAt)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(proposal.driverShare), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.brand)),
            const Text('pour vous', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ]),
        const SizedBox(height: 12),
        RouteLines(pickup: proposal.pickup, destination: proposal.destination),
        const SizedBox(height: 10),
        Text(extras, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: busy ? null : onDecline, child: const Text('Refuser'))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(48)),
              onPressed: busy ? null : onAccept,
              child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Accepter'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = stepLabel(ride.step);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${dayLabel(ride.departureAt)} · ${time(ride.departureAt)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Pill(label, color: color, background: background),
            ]),
            const SizedBox(height: 10),
            RouteLines(pickup: shortAddress(ride.pickup), destination: shortAddress(ride.destination), dense: true),
            if (ride.driverShare != null) ...[
              const SizedBox(height: 8),
              Text('Gagné : ${money(ride.driverShare)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ]),
        ),
      ),
    );
  }
}

(String, Color, Color) stepLabel(RideStep step) => switch (step) {
      RideStep.toAccept => ('À accepter', AppColors.accent, AppColors.accentSoft),
      RideStep.accepted => ('Acceptée', AppColors.brand, AppColors.brandSoft),
      RideStep.onTheWay => ('En route', AppColors.brand, AppColors.brandSoft),
      RideStep.arrived => ('Sur place', AppColors.brand, AppColors.brandSoft),
      RideStep.inProgress => ('En cours', AppColors.success, AppColors.successSoft),
      RideStep.completed => ('Terminée', AppColors.success, AppColors.successSoft),
      RideStep.cancelled => ('Annulée', AppColors.danger, AppColors.dangerSoft),
    };
