import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../auth/auth_controller.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/stars.dart';
import 'feedback_screen.dart';
import 'login_sheet.dart';

// Mes courses : à venir et passées ; détail avec le chauffeur confirmé, l'annulation (frais affichés avant),
// la note du chauffeur une fois la course terminée et un message à l'équipe.
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
                    Expanded(child: Text('${dayLabel(ride.departureAt)} - ${time(ride.departureAt)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    _statusPill(ride),
                  ]),
                  const SizedBox(height: 10),
                  RouteLines(pickup: shortAddress(ride.pickup), destination: shortAddress(ride.destination), dense: true),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(money(ride.quotedPrice), style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (ride.rating != null)
                      StarRating(value: ride.rating!.stars, size: 16)
                    else if (ride.canRate)
                      const Pill('Notez votre chauffeur', color: Color(0xFF8A6100), background: Color(0xFFFFF4D6)),
                  ]),
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
          content: Text(preview.fee > 0 ? 'Des frais de ${money(preview.fee)} s\'appliquent.' : 'L\'annulation est gratuite.'),
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

  // Note du chauffeur : étoiles puis commentaire facultatif, dans une feuille en bas de l'écran.
  Future<void> _rate([int initial = 0]) async {
    final ride = _ride!;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RatingSheet(rideId: ride.id!, driverName: ride.driverName ?? 'votre chauffeur', initialStars: initial, api: context.read<ClientApi>()),
    );
    if (sent != true) return;
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci pour votre avis !')));
  }

  void _write(Ride ride, {String category = 'problem'}) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FeedbackScreen(bookingId: ride.id, bookingLabel: '${dayLabel(ride.departureAt)} à ${time(ride.departureAt)}', initialCategory: category),
      ));

  Widget _ratingCard(Ride ride) {
    final rating = ride.rating;
    if (rating != null) {
      return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Votre avis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Row(children: [
            StarRating(value: rating.stars, size: 24),
            const SizedBox(width: 8),
            Text(StarRating.labels[rating.stars - 1], style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
          if (rating.comment != null) ...[
            const SizedBox(height: 8),
            Text('"${rating.comment}"', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4)),
          ],
        ]),
      );
    }
    return SectionCard(
      color: const Color(0xFFFFFBEF),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Comment s\'est passée votre course avec ${ride.driverName ?? 'votre chauffeur'} ?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Votre note aide l\'équipe à garder un service de qualité.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        Center(child: StarRating(value: 0, size: 36, onChanged: _rate)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    return Scaffold(
      appBar: AppBar(title: Text(ride == null ? 'Course' : '${dayLabel(ride.departureAt)} - ${time(ride.departureAt)}')),
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
                      const SizedBox(height: 6),
                      Row(children: [
                        DriverAvatar(url: ride.driverPhotoUrl == null ? null : '${context.read<ClientApi>().client.baseUrl}${ride.driverPhotoUrl}', radius: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(ride.driverName!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            if (ride.carName != null) Text('${ride.carName}${ride.carPlate != null ? ' - ${ride.carPlate}' : ''}', style: const TextStyle(color: AppColors.muted)),
                          ]),
                        ),
                      ]),
                      if (ride.status != 'completed' && ride.status != 'cancelled') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(8)),
                          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.verified_user_outlined, size: 18, color: AppColors.brand),
                            SizedBox(width: 8),
                            Expanded(child: Text('Avant de monter, vérifiez que le chauffeur, la plaque et le véhicule correspondent. En cas de doute, ne montez pas et contactez-nous.', style: TextStyle(fontSize: 13, height: 1.35))),
                          ]),
                        ),
                      ],
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
                    if (ride.promoDiscount > 0) _line('Code promo', '-${money(ride.promoDiscount)}'),
                    if (ride.creditUsed > 0) _line('Avoir', '-${money(ride.creditUsed)}'),
                    _line('Paiement', ride.paymentStatus == 'paid' ? 'Payée' : 'À régler : ${money(ride.amountDue)}'),
                  ]),
                ),
                if (ride.rating != null || ride.canRate) ...[
                  const SizedBox(height: 12),
                  _ratingCard(ride),
                ],
                if (ride.status == 'completed' || ride.status == 'in_progress') ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: () => _write(ride), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Signaler un problème ou nous écrire')),
                ],
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

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.rideId, required this.driverName, required this.initialStars, required this.api});

  final int rideId;
  final String driverName;
  final int initialStars;
  final ClientApi api;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  late int _stars = widget.initialStars;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.api.rate(widget.rideId, stars: _stars, comment: _comment.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        handleError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Notez ${widget.driverName}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Center(child: StarRating(value: _stars, size: 40, onChanged: (value) => setState(() => _stars = value))),
        SizedBox(
          height: 24,
          child: Center(child: Text(_stars == 0 ? 'Touchez une étoile' : StarRating.labels[_stars - 1], style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _comment,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Commentaire (facultatif)',
            alignLabelWithHint: true,
            hintText: _stars > 0 && _stars <= 2 ? 'Que s\'est-il passé ?' : 'Ponctualité, conduite, véhicule...',
          ),
        ),
        const SizedBox(height: 4),
        const Text('Votre note est définitive et transmise à l\'équipe TonVTC.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _stars == 0 || _sending ? null : _send, child: Text(_sending ? 'Envoi...' : 'Envoyer mon avis')),
      ]),
    );
  }
}
