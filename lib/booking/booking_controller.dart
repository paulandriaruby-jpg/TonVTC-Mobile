import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/client_api.dart';
import '../models/models.dart';
import 'rules.dart';

enum BookingStep { trip, vehicle, customer, done }

// Réservation en cours, comme sur le site : trajet → véhicule → coordonnées → confirmation.
// Le devis est demandé avant de quitter l'étape Trajet : un trajet hors forfait est refusé tout de suite.
class BookingController extends ChangeNotifier {
  BookingController(this.api, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    departure = minimumDeparture(_clock());
  }

  final ClientApi api;
  final DateTime Function() _clock;

  BookingStep step = BookingStep.trip;
  bool roundTrip = false;
  Place? pickup;
  Place? destination;
  late DateTime departure;
  DateTime? returning;

  Quote? quote;
  Offer? offer;
  int babySeats = 0;
  int boosterSeats = 0;

  String firstName = '';
  String lastName = '';
  String email = '';
  String phone = '';
  String transportNumber = '';
  String signName = '';

  String? promoCode;
  String? promoName;
  double promoDiscount = 0;
  double creditBalance = 0;
  bool useCredit = true;

  bool busy = false;
  String? error;
  Ride? created;

  DateTime get now => _clock();
  DateTime get earliestDeparture => minimumDeparture(_clock());

  String? get tripProblem => tripError(hasPickup: pickup != null, hasDestination: destination != null, departure: departure,
      roundTrip: roundTrip, returning: returning, now: _clock());

  double get total => offer == null
      ? 0
      : offerTotal(price: offer!.price, babySeats: babySeats, boosterSeats: boosterSeats, babyPrice: quote?.babySeatPrice ?? 0,
          boosterPrice: quote?.boosterSeatPrice ?? 0, roundTrip: roundTrip);

  ({double promo, double credit, double due}) get split => discounted(total, promoDiscount, creditBalance, useCredit);

  List<String> get missingDetails => customerProblems(firstName: firstName, lastName: lastName, email: email, phone: phone);

  // Le bouton « Confirmer » n'est actif qu'avec un compte connecté et des coordonnées complètes.
  bool canConfirm(bool signedIn) => signedIn && offer != null && missingDetails.isEmpty && tripProblem == null && !busy;

  void update(void Function(BookingController draft) change) {
    change(this);
    error = null;
    // Le trajet a changé : l'ancien prix ne vaut plus.
    if (step == BookingStep.trip) {
      quote = null;
      offer = null;
    }
    notifyListeners();
  }

  void swap() => update((draft) {
        final previous = draft.pickup;
        draft.pickup = draft.destination;
        draft.destination = previous;
      });

  // Aéroport ou gare au départ (sinon à l'arrivée) ; null : pas de bloc vol / train ni pancarte.
  String? get terminalKind => quote?.pickupKind ?? quote?.destinationKind;

  // Pancarte : le chauffeur accueille le client à l'aéroport / la gare, au départ ou au retour d'un aller-retour.
  bool get signNeeded => quote?.pickupKind != null || (terminalKind != null && roundTrip);

  Map<String, dynamic> tripRequest() => {
        'trip_type': roundTrip ? 'round_trip' : 'one_way',
        'pickup': {'place_id': pickup!.placeId},
        'destination': {'place_id': destination!.placeId},
        'departure_at': departure.toUtc().toIso8601String(),
        if (roundTrip && returning != null) 'return_at': returning!.toUtc().toIso8601String(),
      };

  // Étape 1 → 2 : prix calculé par le serveur ; un refus (hors forfait, itinéraire impossible) reste sur l'étape.
  Future<void> showPrices() async {
    error = tripProblem;
    if (error != null) return notifyListeners();
    await _run(() async {
      quote = await api.quote(tripRequest());
      if (quote!.offers.isEmpty) throw ApiException('Aucun véhicule disponible pour ce trajet.');
      offer = quote!.offers.length == 1 ? quote!.offers.first : offer;
      offer ??= quote!.offers.first;
      step = BookingStep.vehicle;
    });
  }

  void selectOffer(Offer value) => _set(() => offer = value);

  void changeSeats({int baby = 0, int booster = 0}) => _set(() {
        babySeats = (babySeats + baby).clamp(0, maxChildSeats);
        boosterSeats = (boosterSeats + booster).clamp(0, maxChildSeats);
        if (promoDiscount > 0) promoDiscount = promoDiscount.clamp(0, total).toDouble();
      });

  void toCustomer() => _set(() => step = BookingStep.customer);

  void back() => _set(() => step = switch (step) { BookingStep.customer => BookingStep.vehicle, _ => BookingStep.trip });

  // Préremplit les coordonnées depuis le compte (Google ou e-mail) ; le client peut les corriger.
  Future<void> loadAccount() async {
    try {
      final profile = await api.profile();
      firstName = profile.firstName;
      lastName = profile.lastName;
      email = profile.email;
      phone = profile.phone;
      if (signName.isEmpty) signName = '${profile.firstName} ${profile.lastName}'.trim();
      creditBalance = await api.creditBalance().catchError((_) => 0.0);
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  Future<void> applyPromo(String code) => _run(() async {
        final result = await api.checkPromo(code.trim(), total, email.trim());
        promoCode = result.code;
        promoName = result.name;
        promoDiscount = result.discount;
      });

  void removePromo() => _set(() {
        promoCode = null;
        promoName = null;
        promoDiscount = 0;
      });

  // Étape 3 → 4 : coordonnées enregistrées sur le compte (pour la prochaine fois), puis réservation.
  Future<void> confirm({required bool signedIn}) async {
    if (!canConfirm(signedIn)) {
      error = missingDetails.isEmpty ? 'Connectez-vous pour réserver.' : 'Complétez : ${missingDetails.join(', ')}.';
      return notifyListeners();
    }
    await _run(() async {
      await api.updateProfile(firstName: firstName.trim(), lastName: lastName.trim(), phone: phone.trim());
      created = await api.createBooking({
        ...tripRequest(),
        'pickup': {'place_id': pickup!.placeId, 'address': pickup!.address},
        'destination': {'place_id': destination!.placeId, 'address': destination!.address},
        'requested_vehicle_type_id': offer!.vehicleTypeId,
        'baby_seats_count': babySeats,
        'booster_seats_count': boosterSeats,
        'customer_first_name': firstName.trim(),
        'customer_last_name': lastName.trim(),
        'customer_email': email.trim(),
        'customer_phone': phone.trim(),
        if (promoCode != null && promoDiscount > 0) 'promo_code': promoCode,
        if (useCredit && creditBalance > 0) 'use_credit': true,
        if (terminalKind != null && transportNumber.trim().isNotEmpty) 'transport_number': transportNumber.trim(),
        if (signNeeded && signName.trim().isNotEmpty) 'sign_name': signName.trim(),
      });
      step = BookingStep.done;
    });
  }

  // Nouvelle réservation : on garde les coordonnées, on repart du trajet.
  void restart() => _set(() {
        step = BookingStep.trip;
        pickup = destination = null;
        roundTrip = false;
        departure = minimumDeparture(_clock());
        returning = null;
        quote = offer = created = null;
        babySeats = boosterSeats = 0;
        transportNumber = '';
        promoCode = promoName = null;
        promoDiscount = 0;
      });

  void _set(VoidCallback change) {
    change();
    error = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Connexion impossible. Vérifiez votre réseau.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
