import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../booking/booking_controller.dart';
import '../booking/rules.dart';
import '../models/models.dart';
import '../legal/legal.dart';
import '../theme.dart';
import '../widgets/pay_button.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'address_search_screen.dart';
import 'login_sheet.dart';

// Réservation en 4 étapes, comme sur le site : Trajet, Véhicule, Coordonnées, Confirmation.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.onShowRides});

  final VoidCallback onShowRides;

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingController>();
    final index = BookingStep.values.indexOf(booking.step);
    return PopScope(
      canPop: booking.step == BookingStep.trip || booking.step == BookingStep.done,
      onPopInvokedWithResult: (popped, _) => popped ? null : booking.back(),
      child: Scaffold(
        appBar: booking.step == BookingStep.trip ? null : AppBar(
          leading: booking.step == BookingStep.vehicle || booking.step == BookingStep.customer ? BackButton(onPressed: booking.back) : null,
          title: Text(['Trajet', 'Véhicule', 'Coordonnées', 'Réservation enregistrée'][index], style: const TextStyle(fontWeight: FontWeight.w800)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (index + 1) / 4, minHeight: 4, color: AppColors.brand, backgroundColor: AppColors.surface),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (booking.step) {
            // Icônes de la barre d'état en blanc sur la photo de l'accueil.
            BookingStep.trip => const AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: _TripStep(key: ValueKey('trip'))),
            BookingStep.vehicle => const _VehicleStep(key: ValueKey('vehicle')),
            BookingStep.customer => const _CustomerStep(key: ValueKey('customer')),
            BookingStep.done => _DoneStep(key: const ValueKey('done'), onShowRides: onShowRides),
          },
        ),
      ),
    );
  }
}

Widget _errorBox(String? message) => message == null
    ? const SizedBox.shrink()
    : Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

Widget _primary({required String label, required VoidCallback? onPressed, bool busy = false, IconData icon = Icons.arrow_forward}) => FilledButton.icon(
  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
  onPressed: busy ? null : onPressed,
  icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Icon(icon),
  label: Text(label),
);

// -- Étape 1 : trajet -----------------------------------------------------------
// Accueil de l'app : photo en grand, carte de réservation posée dessus (aller simple / aller-retour, adresses reliées
// par un trait, date et heure séparées), bouton orange, puis destinations fréquentes et garanties.
class _TripStep extends StatelessWidget {
  const _TripStep({super.key});

  // Destinations fréquentes : ouvrent la recherche d'adresse déjà remplie (le lieu exact vient de Google).
  static const _popular = [
    (Icons.flight_takeoff, 'Aéroport de Genève'),
    (Icons.train_outlined, 'Gare d\'Annecy'),
    (Icons.train_outlined, 'Gare de Genève Cornavin'),
    (Icons.downhill_skiing, 'Chamonix'),
  ];

  Future<void> _pickAddress(BuildContext context, bool isPickup, {String? query}) async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => AddressSearchScreen(title: isPickup ? 'Adresse de départ' : 'Adresse d\'arrivée', initialQuery: query)),
    );
    if (place == null || !context.mounted) return;
    context.read<BookingController>().update((draft) => isPickup ? draft.pickup = place : draft.destination = place);
  }

  DateTime _current(BookingController booking, bool isReturn) =>
      isReturn ? (booking.returning ?? booking.departure.add(const Duration(hours: 3))) : booking.departure;

  Future<void> _pickDay(BuildContext context, {required bool isReturn}) async {
    final booking = context.read<BookingController>();
    final current = _current(booking, isReturn);
    final first = isReturn ? booking.departure : booking.earliestDeparture;
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : current,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: booking.now.add(const Duration(days: 365)),
      helpText: isReturn ? 'Date du retour' : 'Date du départ',
    );
    if (date == null || !context.mounted) return;
    final chosen = roundToQuarter(DateTime(date.year, date.month, date.day, current.hour, current.minute));
    booking.update((draft) => isReturn ? draft.returning = chosen : draft.departure = chosen);
  }

  Future<void> _pickTime(BuildContext context, {required bool isReturn}) async {
    final booking = context.read<BookingController>();
    final current = _current(booking, isReturn);
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current), helpText: 'Heure (par quart d\'heure)');
    if (picked == null || !context.mounted) return;
    final chosen = roundToQuarter(DateTime(current.year, current.month, current.day, picked.hour, picked.minute));
    booking.update((draft) => isReturn ? draft.returning = chosen : draft.departure = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingController>();
    final top = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(children: [
          _Hero(height: 250 + top, top: top),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 190 + top, 16, 0),
            child: Material(
              color: Colors.white,
              elevation: 6,
              shadowColor: const Color(0x55041325),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _TripToggle(roundTrip: booking.roundTrip, onChanged: (value) => booking.update((draft) {
                  draft.roundTrip = value;
                  if (draft.roundTrip) draft.returning ??= draft.departure.add(const Duration(hours: 3));
                })),
                const SizedBox(height: 14),
                _AddressPair(
                  pickup: booking.pickup?.address,
                  destination: booking.destination?.address,
                  onPickup: () => _pickAddress(context, true),
                  onDestination: () => _pickAddress(context, false),
                  onSwap: booking.pickup != null || booking.destination != null ? booking.swap : null,
                ),
                const SizedBox(height: 12),
                _WhenRow(
                  label: 'Départ',
                  at: booking.departure,
                  onDay: () => _pickDay(context, isReturn: false),
                  onTime: () => _pickTime(context, isReturn: false),
                ),
                if (booking.roundTrip) ...[
                  const SizedBox(height: 10),
                  _WhenRow(
                    label: 'Retour',
                    at: booking.returning,
                    onDay: () => _pickDay(context, isReturn: true),
                    onTime: () => _pickTime(context, isReturn: true),
                  ),
                ],
                _errorBox(booking.error),
                const SizedBox(height: 16),
                _primary(label: 'Voir les prix', busy: booking.busy, onPressed: booking.showPrices),
              ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        const _SectionTitle('Où allez-vous ?'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _popular.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final (icon, label) = _popular[index];
              return ActionChip(
                avatar: Icon(icon, size: 18, color: AppColors.brand),
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                onPressed: () => _pickAddress(context, false, query: label),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Pourquoi TonVTC'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            for (final (icon, title, text, color, background) in const [
              (Icons.lock_outline, 'Prix fixe', 'Connu avant de réserver, il ne change plus, même dans les bouchons.', AppColors.brand, AppColors.brandSoft),
              (Icons.verified_user_outlined, 'Chauffeurs vérifiés', 'Carte VTC, permis, assurance et véhicule contrôlés par notre équipe.', AppColors.success, AppColors.successSoft),
              (Icons.event_available_outlined, 'Annulation gratuite', 'Jusqu\'à 24 h avant le départ, depuis l\'onglet Courses.', AppColors.accent, AppColors.accentSoft),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
  );
}

// Photo de nuit au-dessus d'Annecy, assombrie, avec le logo et l'accroche ; la carte de réservation la recouvre en bas.
class _Hero extends StatelessWidget {
  const _Hero({required this.height, required this.top});

  final double height;
  final double top;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(fit: StackFit.expand, children: [
      Image.asset('assets/images/accueil-nuit.webp', fit: BoxFit.cover, alignment: const Alignment(0, .5)),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99041325), Color(0x33041325), Color(0xCC041325)],
            stops: [0, .45, 1],
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(20, top + 14, 20, 0),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Logo(size: 34),
            SizedBox(width: 10),
            Text('TonVTC', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          SizedBox(height: 22),
          Text('Où allons-nous ?', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
          SizedBox(height: 6),
          Text('Haute-Savoie et Genève, au prix fixé à l\'avance.', style: TextStyle(color: Color(0xFFD3D9E4), fontSize: 15)),
        ]),
      ),
    ]),
  );
}

// Aller simple / aller-retour : deux pastilles, la choisie en bleu nuit (comme sur le site).
class _TripToggle extends StatelessWidget {
  const _TripToggle({required this.roundTrip, required this.onChanged});

  final bool roundTrip;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      for (final (value, label) in const [(false, 'Aller simple'), (true, 'Aller-retour')])
        Expanded(
          child: Semantics(
            selected: roundTrip == value,
            button: true,
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: roundTrip == value ? AppColors.ink : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: roundTrip == value ? Colors.white : AppColors.ink)),
              ),
            ),
          ),
        ),
    ]),
  );
}

// Départ et arrivée reliés par un trait (rond puis carré, comme sur le site), bouton pour inverser à droite.
class _AddressPair extends StatelessWidget {
  const _AddressPair({required this.pickup, required this.destination, required this.onPickup, required this.onDestination, this.onSwap});

  final String? pickup;
  final String? destination;
  final VoidCallback onPickup;
  final VoidCallback onDestination;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      const SizedBox(width: 16),
      Column(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 3))),
        Container(width: 2, height: 38, color: AppColors.line),
        Container(width: 12, height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), border: Border.all(color: AppColors.accent, width: 3))),
      ]),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _AddressLine(label: 'Départ', value: pickup, placeholder: 'D\'où partez-vous ?', onTap: onPickup),
          const Divider(height: 1, indent: 12),
          _AddressLine(label: 'Arrivée', value: destination, placeholder: 'Où allez-vous ?', onTap: onDestination),
        ]),
      ),
      if (onSwap != null)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton.filledTonal(
            tooltip: 'Inverser départ et arrivée',
            style: IconButton.styleFrom(backgroundColor: AppColors.brandSoft, foregroundColor: AppColors.brand),
            icon: const Icon(Icons.swap_vert),
            onPressed: onSwap,
          ),
        )
      else
        const SizedBox(width: 12),
    ]),
  );
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.label, required this.value, required this.placeholder, required this.onTap});

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value ?? placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, color: value == null ? AppColors.muted : AppColors.ink, fontWeight: value == null ? FontWeight.w500 : FontWeight.w700),
        ),
      ]),
    ),
  );
}

// Date et heure en deux cases côte à côte (la date ouvre le calendrier, l'heure l'horloge).
class _WhenRow extends StatelessWidget {
  const _WhenRow({required this.label, required this.at, required this.onDay, required this.onTime});

  final String label;
  final DateTime? at;
  final VoidCallback onDay;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(flex: 3, child: _Box(icon: Icons.event, label: '$label le', value: at == null ? 'Choisir' : dayLabel(at!), onTap: onDay)),
    const SizedBox(width: 10),
    Expanded(flex: 2, child: _Box(icon: Icons.schedule, label: 'Heure', value: at == null ? '--:--' : time(at!), onTap: onTime)),
  ]);
}

class _Box extends StatelessWidget {
  const _Box({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.line, width: 1.5)),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// -- Étape 2 : véhicule ---------------------------------------------------------
// Photos des gammes (mêmes que le site, gs-vtc-web/public/images) ; icône sinon.
const _vehicleImages = {'berline': 'assets/images/berline.webp'};

class _VehicleStep extends StatelessWidget {
  const _VehicleStep({super.key});

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingController>();
    final quote = booking.quote!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TripRecap(booking: booking),
        const SizedBox(height: 12),
        for (final offer in quote.offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: booking.offer == offer ? AppColors.brand : AppColors.line, width: 2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => booking.selectOffer(offer),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_vehicleImages[offer.slug] case final image?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Image.asset(image, height: 120, fit: BoxFit.contain, semanticLabel: offer.name),
                        ),
                      Row(
                        children: [
                          if (!_vehicleImages.containsKey(offer.slug)) ...[
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.directions_car_filled, size: 34, color: AppColors.brand),
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(offer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                if (offer.description != null) Text(offer.description!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('${offer.passengers} passagers - ${offer.luggage} bagages', style: const TextStyle(fontSize: 13)),
                                if (offer.pricingNote != null)
                                  Text(
                                    offer.pricingNote!,
                                    style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(money(offer.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              Text(booking.roundTrip ? 'aller-retour' : 'prix fixe', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vous voyagez avec un enfant ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                quote.babySeatPrice + quote.boosterSeatPrice > 0 ? 'Supplément par équipement et par trajet.' : 'Équipements fournis gratuitement.',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              _SeatRow(
                label: 'Siège bébé',
                help: 'Jusqu\'à 13 kg',
                price: quote.babySeatPrice,
                count: booking.babySeats,
                onChange: (d) => booking.changeSeats(baby: d),
              ),
              _SeatRow(
                label: 'Rehausseur',
                help: 'À partir de 15 kg',
                price: quote.boosterSeatPrice,
                count: booking.boosterSeats,
                onChange: (d) => booking.changeSeats(booster: d),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TotalBar(total: booking.total),
        const SizedBox(height: 12),
        _primary(label: 'Continuer', onPressed: booking.offer == null ? null : booking.toCustomer),
      ],
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({required this.label, required this.help, required this.price, required this.count, required this.onChange});

  final String label;
  final String help;
  final double price;
  final int count;
  final void Function(int delta) onChange;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(price > 0 ? '$help - ${money(price)}' : help, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        IconButton.outlined(onPressed: count > 0 ? () => onChange(-1) : null, icon: const Icon(Icons.remove), tooltip: 'Retirer : $label'),
        SizedBox(
          width: 32,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        IconButton.outlined(onPressed: count < maxChildSeats ? () => onChange(1) : null, icon: const Icon(Icons.add), tooltip: 'Ajouter : $label'),
      ],
    ),
  );
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total, this.label = 'Total TTC'});

  final double total;
  final String label;

  @override
  Widget build(BuildContext context) => SectionCard(
    color: AppColors.brandSoft,
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Text(
          money(total),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.brand),
        ),
      ],
    ),
  );
}

class _TripRecap extends StatelessWidget {
  const _TripRecap({required this.booking});

  final BookingController booking;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RouteLines(pickup: booking.pickup!.address, destination: booking.destination!.address, dense: true),
        const SizedBox(height: 8),
        Text(
          [
            '${dayLabel(booking.departure)} à ${time(booking.departure)}',
            if (booking.quote != null && booking.quote!.distanceKm > 0)
              '${booking.quote!.distanceKm.toStringAsFixed(1)} km - ${booking.quote!.durationMinutes.round()} min',
            if (booking.roundTrip && booking.returning != null) 'retour ${dayLabel(booking.returning!).toLowerCase()} à ${time(booking.returning!)}',
          ].join(' - '),
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    ),
  );
}

// -- Étape 3 : coordonnées (compte obligatoire) ---------------------------------
class _CustomerStep extends StatefulWidget {
  const _CustomerStep({super.key});

  @override
  State<_CustomerStep> createState() => _CustomerStepState();
}

class _CustomerStepState extends State<_CustomerStep> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _transport = TextEditingController();
  final _sign = TextEditingController();
  final _promo = TextEditingController();
  // Formulaire prêt : tout de suite sans compte (le client tape ses coordonnées), après lecture du compte sinon.
  bool _loaded = false;
  bool _googleBusy = false;

  @override
  void initState() {
    super.initState();
    final booking = context.read<BookingController>();
    _first.text = booking.firstName;
    _last.text = booking.lastName;
    _email.text = booking.email;
    _phone.text = booking.phone;
    if (context.read<AuthController>().state == AuthState.signedIn) {
      _loadAccount();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadAccount() async {
    final booking = context.read<BookingController>();
    await booking.loadAccount();
    if (!mounted) return;
    _first.text = booking.firstName;
    _last.text = booking.lastName;
    _email.text = booking.email;
    _phone.text = booking.phone;
    _sign.text = booking.signName;
    _transport.text = booking.transportNumber;
    setState(() => _loaded = true);
  }

  // Compte existant (e-mail déjà connu) : connexion par mot de passe ou Google, puis le formulaire se remplit.
  Future<void> _login({String? email}) async {
    if (await showLoginSheet(context, email: email, phone: context.read<BookingController>().phone) && mounted) await _loadAccount();
  }

  // "Continuer avec Google" : compte retrouvé (coordonnées reprises) ou créé avec le téléphone déjà tapé.
  Future<void> _google() async {
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _googleBusy = true);
    try {
      if (await auth.loginWithGoogle(phone: context.read<BookingController>().phone) && mounted) await _loadAccount();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Connexion impossible. Vérifiez votre réseau.')));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingController>();
    final signedIn = context.watch<AuthController>().state == AuthState.signedIn;
    final split = booking.split;
    final terminal = booking.terminalKind;
    final atPickup = booking.quote?.pickupKind != null;
    void bind(void Function(BookingController draft) change) {
      change(booking);
      setState(() {});
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TripRecap(booking: booking),
        const SizedBox(height: 12),
        if (!signedIn) ...[
          if (booking.accountExists)
            SectionCard(
              color: AppColors.accentSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Vous avez déjà un compte', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${booking.email.trim()} est déjà enregistré chez nous : connectez-vous pour réserver avec ce compte.', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: () => _login(email: booking.email.trim()), icon: const Icon(Icons.login), label: const Text('Me connecter')),
              ]),
            )
          else
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.line)),
                  onPressed: _googleBusy ? null : _google,
                  icon: _googleBusy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                  label: const Text('Continuer avec Google'),
                ),
                const SizedBox(height: 6),
                const Text('Vos coordonnées sont remplies pour vous. Sinon, complétez le formulaire : votre compte est créé à la réservation.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                TextButton(onPressed: _login, child: const Text('Déjà un compte ? Se connecter')),
              ]),
            ),
          const SizedBox(height: 12),
        ],
        if (signedIn && !_loaded)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Passager principal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _first,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        onChanged: (v) => bind((d) => d.firstName = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _last,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        onChanged: (v) => bind((d) => d.lastName = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    errorText: booking.missingDetails.contains('téléphone') ? 'Indispensable : le chauffeur vous appelle si besoin' : null,
                  ),
                  onChanged: (v) => bind((d) => d.phone = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _email,
                  readOnly: signedIn,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: signedIn ? 'E-mail (celui du compte)' : 'E-mail',
                    prefixIcon: const Icon(Icons.mail_outline),
                    helperText: signedIn ? null : 'Pour la confirmation et l\'accès à votre compte.',
                  ),
                  onChanged: (v) => bind((d) {
                    d.email = v;
                    d.accountExists = false;
                  }),
                ),
              ],
            ),
          ),
          if (terminal != null) ...[
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    terminal == 'station' ? (atPickup ? 'Arrivée en gare' : 'Départ en train') : (atPickup ? 'Arrivée à l\'aéroport' : 'Départ en avion'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    booking.signNeeded
                        ? 'Le chauffeur suit votre arrivée et vous attend avec une pancarte. Facultatif.'
                        : 'Le chauffeur connaît votre vol ou train pour vous déposer à temps. Facultatif.',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _transport,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: terminal == 'station' ? 'Numéro de train' : 'Numéro de vol',
                      counterText: '',
                      prefixIcon: Icon(terminal == 'station' ? Icons.train : (atPickup ? Icons.flight_land : Icons.flight_takeoff)),
                    ),
                    onChanged: (v) => bind((d) => d.transportNumber = v),
                  ),
                  if (booking.signNeeded) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sign,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Nom sur la pancarte', counterText: '', prefixIcon: Icon(Icons.badge_outlined)),
                      onChanged: (v) => bind((d) => d.signName = v),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Réductions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (booking.promoCode != null)
                  Row(
                    children: [
                      const Icon(Icons.verified, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${booking.promoCode} - ${booking.promoName} - -${money(booking.promoDiscount)}',
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(onPressed: booking.removePromo, child: const Text('Retirer')),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promo,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Code promo', prefixIcon: Icon(Icons.local_offer_outlined)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                        onPressed: booking.busy || _promo.text.trim().isEmpty ? null : () => booking.applyPromo(_promo.text),
                        child: const Text('Appliquer'),
                      ),
                    ],
                  ),
                if (booking.creditBalance > 0)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: booking.useCredit,
                    onChanged: (v) => bind((d) => d.useCredit = v ?? false),
                    title: const Text('Utiliser mon avoir'),
                    subtitle: Text('${money(booking.creditBalance)} disponibles'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          color: AppColors.brandSoft,
          child: Column(
            children: [
              _Line('${booking.offer!.name}${booking.roundTrip ? ' - aller-retour' : ''}', money(booking.offer!.price)),
              if (booking.babySeats + booking.boosterSeats > 0)
                _Line('Équipements enfant (${booking.babySeats + booking.boosterSeats})', money(booking.total - booking.offer!.price)),
              if (split.promo > 0) _Line('Code promo', '-${money(split.promo)}', color: AppColors.success),
              if (split.credit > 0) _Line('Avoir', '-${money(split.credit)}', color: AppColors.success),
              const Divider(),
              Row(
                children: [
                  const Expanded(
                    child: Text('Total TTC', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    money(split.due),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.brand),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_loaded && booking.missingDetails.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Pour confirmer, complétez : ${booking.missingDetails.join(', ')}.',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        TermsCheckbox(value: booking.termsAccepted, onChanged: (v) => bind((d) => d.termsAccepted = v)),
        _errorBox(booking.error),
        const SizedBox(height: 12),
        _primary(
          label: 'Confirmer la réservation',
          icon: Icons.check,
          busy: booking.busy,
          onPressed: booking.canConfirm() && _loaded && !booking.accountExists ? () => _confirm(context) : null,
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final booking = context.read<BookingController>();
    final auth = context.read<AuthController>();
    await booking.confirm(
      signedIn: auth.state == AuthState.signedIn,
      createAccount: () => auth.register(firstName: booking.firstName, lastName: booking.lastName, email: booking.email, phone: booking.phone, termsAccepted: booking.termsAccepted),
    );
    if (!context.mounted) return;
    if (booking.error == SessionExpired().message) context.read<AuthController>().expired();
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: color)),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

// -- Étape 4 : confirmation -----------------------------------------------------
class _DoneStep extends StatefulWidget {
  const _DoneStep({super.key, required this.onShowRides});

  final VoidCallback onShowRides;

  @override
  State<_DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends State<_DoneStep> {
  bool _paid = false;

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingController>();
    final ride = booking.created!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(Icons.check, color: AppColors.brand, size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'Merci, votre réservation est enregistrée',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Référence ${ride.reference.substring(0, ride.reference.length.clamp(0, 12))} - confirmation envoyée par e-mail.',
                style: const TextStyle(color: Color(0xFFE3E8FF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RouteLines(pickup: ride.pickup, destination: ride.destination),
              const SizedBox(height: 8),
              Text('${dayLabel(ride.departureAt)} à ${time(ride.departureAt)}', style: const TextStyle(color: AppColors.muted)),
              if (ride.transportNumber != null || ride.signName != null)
                Text(
                  [
                    if (ride.transportNumber != null) 'Vol / train ${ride.transportNumber}',
                    if (ride.signName != null) 'Pancarte : ${ride.signName}',
                  ].join(' - '),
                  style: const TextStyle(color: AppColors.muted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _TotalBar(total: ride.amountDue, label: ride.amountDue == 0 ? 'Réglé par votre avoir' : 'Montant à régler'),
        const SizedBox(height: 12),
        if (_paid)
          const SectionCard(
            color: AppColors.successSoft,
            child: Text(
              'Paiement reçu, merci ! Votre course est proposée à nos chauffeurs.',
              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
            ),
          )
        else if (ride.amountDue > 0)
          SectionCard(
            child: PayButton(api: booking.api, reference: ride.reference, amount: ride.amountDue, onPaid: () {
              if (mounted) setState(() => _paid = true);
            }),
          ),
        const SizedBox(height: 16),
        const Text('Et maintenant ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        for (final (index, title, text) in const [
          (1, 'Attribution d\'un chauffeur', 'Vous recevez son nom et son véhicule par e-mail dès qu\'il accepte.'),
          (2, 'Rappel la veille', 'Pour les courses réservées plus de 24 h à l\'avance.'),
          (3, 'Annulation gratuite', 'Jusqu\'à 24 h avant le départ, depuis "Mes courses".'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.brandSoft,
              child: Text(
                '$index',
                style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(text),
          ),
        const SizedBox(height: 12),
        _primary(
          label: 'Voir mes courses',
          onPressed: () {
            booking.restart();
            widget.onShowRides();
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: booking.restart, child: const Text('Nouvelle réservation')),
      ],
    );
  }
}
