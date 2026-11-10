import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/driver_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'rides_screen.dart';

// Fiche d'une course : étapes du chauffeur (en route, arrivé, démarrer, terminer), itinéraire, appel du client,
// signalement et désistement.
class RideDetailScreen extends StatefulWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final int rideId;

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  Ride? _ride;
  String? _busy;

  DriverApi get _api => context.read<DriverApi>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ride = await _api.ride(widget.rideId);
      if (mounted) setState(() => _ride = ride);
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  Future<void> _act(String action, String done) async {
    setState(() => _busy = action);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ride = await _api.rideAction(widget.rideId, action);
      if (!mounted) return;
      setState(() => _ride = ride);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      if (action == 'arrive' && ride.late) await _explainLate(ride);
      if ((action == 'decline' || action == 'withdraw') && mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) handleError(context, error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _confirm(String action, String question, String done) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok == true) await _act(action, done);
  }

  // Itinéraire vers le client tant qu'il n'est pas à bord, puis vers la destination.
  Future<void> _navigate(Ride ride) async {
    final target = ride.step == RideStep.inProgress ? ride.destination : ride.pickup;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(target)}&travelmode=driving');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _report(Ride ride) async {
    const categories = {
      'customer_late': 'Retard du client',
      'customer_absent': 'Absence du client',
      'additional_stops': 'Arrêt(s) supplémentaire(s)',
      'route_change': "Changement d'itinéraire",
      'other': 'Autre',
    };
    var category = 'customer_late';
    final body = TextEditingController();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Signaler un problème', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Motif'),
              items: categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (value) => setSheet(() => category = value ?? category),
            ),
            const SizedBox(height: 12),
            TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'Précisions (facultatif)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
          ]),
        ),
      ),
    );
    if (sent != true || !mounted) return;
    try {
      await _api.report(ride.id, category: category, body: body.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé : notre équipe le traite.')));
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  // Arrivée en retard : on propose tout de suite d'en donner la raison (bouchons, accident...).
  Future<void> _explainLate(Ride ride) async {
    final explain = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrivée en retard'),
        content: Text('Vous êtes arrivé ${ride.arrivalDelayMinutes} min après l\'heure prévue. Voulez-vous expliquer pourquoi ? L\'équipe en tiendra compte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(context, true), child: const Text('Expliquer')),
        ],
      ),
    );
    if (explain == true && mounted) await _addRemark(ride, prefix: 'Retard de ${ride.arrivalDelayMinutes} min : ');
  }

  // Remarque libre sur la course (bagages, accès, comportement...) : visible par l'équipe dans le journal.
  Future<void> _addRemark(Ride ride, {String prefix = ''}) async {
    final text = TextEditingController(text: prefix);
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ajouter une remarque', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Visible par l\'équipe. Pour un problème à régler, utilisez "Signaler un problème".', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: text, autofocus: true, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'Ex. : client avec deux grosses valises, accès par le parking...')),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(context, text.text.trim()), child: const Text('Enregistrer')),
        ]),
      ),
    );
    if (body == null || body.isEmpty || !mounted) return;
    try {
      await _api.remark(ride.id, body);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remarque enregistrée.')));
    } catch (error) {
      if (mounted) handleError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    return Scaffold(
      appBar: AppBar(
        title: Text(ride == null ? 'Course' : '${dayLabel(ride.departureAt)} - ${time(ride.departureAt)}'),
        actions: [
          if (ride != null)
            PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'report' => _report(ride),
                'withdraw' => _confirm('withdraw', 'Vous désister de cette course ? Elle sera reproposée aux autres chauffeurs.', 'Désistement enregistré.'),
                _ => null,
              },
              itemBuilder: (_) => [
                if (ride.step != RideStep.cancelled) const PopupMenuItem(value: 'report', child: Text('Signaler un problème')),
                if (ride.can('withdraw')) const PopupMenuItem(value: 'withdraw', child: Text('Me désister')),
              ],
            ),
        ],
      ),
      body: ride == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _StepTracker(step: ride.step),
                const SizedBox(height: 12),
                if (ride.transportNumber != null || ride.signName != null) ...[
                  SectionCard(
                    color: AppColors.brandSoft,
                    child: Row(children: [
                      const Icon(Icons.flight_land, color: AppColors.brand),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (ride.transportNumber != null) Text('Vol / train ${ride.transportNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if (ride.signName != null) Text('Pancarte : ${ride.signName}', style: const TextStyle(fontSize: 15)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                if (ride.late)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SectionCard(color: AppColors.accentSoft, child: Text('Arrivé avec ${ride.arrivalDelayMinutes} min de retard sur l\'heure prévue.', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600))),
                  ),
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    RouteLines(pickup: ride.pickup, destination: ride.destination),
                    if (ride.roundTrip && ride.returnAt != null) ...[
                      const SizedBox(height: 10),
                      Text('Retour : ${dateTime(ride.returnAt!)}', style: const TextStyle(color: AppColors.muted)),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => _navigate(ride), icon: const Icon(Icons.navigation_outlined), label: const Text('Itinéraire'))),
                      if (ride.customerPhone != null && ride.step != RideStep.completed && ride.step != RideStep.cancelled) ...[
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${ride.customerPhone}')), icon: const Icon(Icons.call_outlined), label: const Text('Appeler'))),
                      ],
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(children: [
                    _Line('Client', ride.customerName.isEmpty ? '-' : ride.customerName),
                    if (ride.babySeats + ride.boosterSeats > 0) _Line('Enfants', '${ride.babySeats} siège(s) bébé - ${ride.boosterSeats} rehausseur(s)'),
                    if (ride.carName != null) _Line('Véhicule', ride.carName!),
                    _Line('Référence', ride.reference.substring(0, ride.reference.length.clamp(0, 12))),
                    if (ride.driverShare != null) _Line('Votre gain', money(ride.driverShare), strong: true)
                    else if (ride.expectedShare != null && ride.step != RideStep.cancelled) _Line('Votre gain prévu', money(ride.expectedShare), strong: true)
                    else _Line('Prix de la course', money(ride.quotedPrice)),
                    if (ride.waitingFee > 0) _Line('Attente facturée', money(ride.waitingFee)),
                  ]),
                ),
                const SizedBox(height: 12),
                _Notes(notes: ride.notes, onAdd: ride.step == RideStep.cancelled ? null : () => _addRemark(ride)),
                const SizedBox(height: 16),
                ..._actions(ride),
              ]),
            ),
    );
  }

  // Le bouton principal correspond à l'étape suivante ; un seul à la fois pour éviter les erreurs au volant.
  List<Widget> _actions(Ride ride) {
    Widget primary(String action, String label, String done, {IconData? icon}) => FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _busy == null ? () => _act(action, done) : null,
          icon: _busy == action ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Icon(icon ?? Icons.arrow_forward),
          label: Text(label),
        );
    return switch (ride.step) {
      RideStep.toAccept => [
          if (ride.can('accept')) primary('accept', 'Accepter la course', 'Course acceptée.', icon: Icons.check),
          const SizedBox(height: 10),
          if (ride.can('decline')) OutlinedButton(onPressed: _busy == null ? () => _confirm('decline', 'Refuser cette course ? Elle sera proposée aux autres chauffeurs.', 'Course refusée.') : null, child: const Text('Refuser')),
        ],
      RideStep.accepted => [
          if (ride.can('depart')) primary('depart', 'Je pars vers le client', 'Vous êtes en route.', icon: Icons.navigation),
          const SizedBox(height: 10),
          if (ride.can('arrive')) OutlinedButton(onPressed: _busy == null ? () => _act('arrive', 'Arrivée enregistrée : l\'attente du client commence.') : null, child: const Text('Je suis déjà arrivé')),
        ],
      RideStep.onTheWay => [if (ride.can('arrive')) primary('arrive', 'Je suis arrivé', 'Arrivée enregistrée : l\'attente du client commence.', icon: Icons.place)],
      RideStep.arrived => [if (ride.can('start')) primary('start', 'Démarrer la course', 'Course démarrée.', icon: Icons.play_arrow)],
      RideStep.inProgress => [if (ride.can('finish')) primary('finish', 'Terminer la course', 'Course terminée. Merci !', icon: Icons.flag)],
      RideStep.completed => [
          SectionCard(
            color: AppColors.successSoft,
            child: Text(ride.payoutStatus == 'paid' ? 'Course terminée - gain versé.' : 'Course terminée - le gain sera versé chaque semaine, après le paiement du client.',
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ],
      RideStep.cancelled => [const SectionCard(color: AppColors.dangerSoft, child: Text('Course annulée.', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)))],
    };
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.notes, required this.onAdd});

  final List<DriverNote> notes;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Remarques', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          if (onAdd != null) TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_comment_outlined, size: 18), label: const Text('Ajouter')),
        ]),
        if (notes.isEmpty)
          const Text('Aucune remarque. Ajoutez une information utile pour l\'équipe (bagages, accès, attente...).', style: TextStyle(color: AppColors.muted, fontSize: 13))
        else
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(note.remark ? 'Remarque' : (note.label ?? 'Signalement'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  if (!note.remark) note.handled ? const Pill('Traité', color: AppColors.success, background: AppColors.successSoft) : const Pill('Envoyé à l\'équipe', color: AppColors.accent, background: AppColors.accentSoft),
                  const Spacer(),
                  Text(time(note.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
                if (note.body != null && note.body!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note.body!)),
              ]),
            ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: strong ? AppColors.brand : AppColors.ink))),
        ]),
      );
}

// Avancement : Acceptée -> En route -> Sur place -> En cours -> Terminée.
class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.step});

  final RideStep step;

  static const _steps = [RideStep.accepted, RideStep.onTheWay, RideStep.arrived, RideStep.inProgress, RideStep.completed];

  @override
  Widget build(BuildContext context) {
    if (step == RideStep.cancelled || step == RideStep.toAccept) {
      final (label, color, background) = stepLabel(step);
      return Align(alignment: Alignment.centerLeft, child: Pill(label, color: color, background: background));
    }
    final current = _steps.indexOf(step);
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(children: [
        for (var i = 0; i < _steps.length; i++)
          Expanded(
            child: Column(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: i <= current ? AppColors.brand : AppColors.surface,
                child: i < current
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i == current ? Colors.white : AppColors.muted)),
              ),
              const SizedBox(height: 6),
              Text(stepLabel(_steps[i]).$1, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: i == current ? FontWeight.w800 : FontWeight.w500, color: i <= current ? AppColors.ink : AppColors.muted)),
            ]),
          ),
      ]),
    );
  }
}
