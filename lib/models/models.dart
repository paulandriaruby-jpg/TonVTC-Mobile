// Données de l'API (mêmes champs que le site).

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value');
double _num(Object? value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;

// Adresse choisie dans les suggestions (Google Places côté serveur).
class Place {
  const Place({required this.placeId, required this.address, this.lat, this.lng});

  Place.fromJson(Map<String, dynamic> json)
      : placeId = json['place_id'] as String,
        address = json['address'] as String,
        lat = (json['lat'] as num?)?.toDouble(),
        lng = (json['lng'] as num?)?.toDouble();

  final String placeId;
  final String address;
  final double? lat;
  final double? lng;
}

class PlaceSuggestion {
  PlaceSuggestion.fromJson(Map<String, dynamic> json)
      : placeId = json['place_id'] as String,
        main = (json['main'] ?? json['text']) as String? ?? '',
        secondary = json['secondary'] as String?;

  final String placeId;
  final String main;
  final String? secondary;
}

class Offer {
  Offer.fromJson(Map<String, dynamic> json)
      : vehicleTypeId = json['vehicle_type_id'] as int,
        slug = json['slug'] as String? ?? '',
        name = json['name'] as String,
        description = json['description'] as String?,
        passengers = (json['passenger_capacity'] as int?) ?? 4,
        luggage = (json['luggage_capacity'] as int?) ?? 3,
        price = _num(json['price']),
        pricingNote = _note(json['pricing'] as Map<String, dynamic>?);

  final int vehicleTypeId;
  final String slug;
  final String name;
  final String? description;
  final int passengers;
  final int luggage;
  final double price;
  final String? pricingNote;

  // Forfait ou majoration appliqués (même mention que sur le site).
  static String? _note(Map<String, dynamic>? pricing) {
    final outbound = pricing?['outbound'] as Map<String, dynamic>?;
    if (outbound == null) return null;
    final surcharge = outbound['surcharge'] as Map<String, dynamic>?;
    final parts = [
      if (outbound['kind'] == 'fixed' && outbound['fixed_route'] != null) 'Forfait ${outbound['fixed_route']}',
      if (surcharge != null) '${surcharge['name']} +${_num(surcharge['percent']).toStringAsFixed(0)} %',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class Quote {
  Quote.fromJson(Map<String, dynamic> json)
      : offers = (json['offers'] as List).map((o) => Offer.fromJson(o as Map<String, dynamic>)).toList(),
        babySeatPrice = _num((json['seat_prices'] as Map<String, dynamic>?)?['baby_seat']),
        boosterSeatPrice = _num((json['seat_prices'] as Map<String, dynamic>?)?['booster_seat']),
        pickupKind = json['pickup_kind'] as String?,
        destinationKind = json['destination_kind'] as String?,
        distanceKm = _num(((json['route'] ?? json['outbound_route']) as Map<String, dynamic>?)?['distance_km']),
        durationMinutes = _num(((json['route'] ?? json['outbound_route']) as Map<String, dynamic>?)?['duration_minutes']);

  final List<Offer> offers;
  final double babySeatPrice;
  final double boosterSeatPrice;
  // « airport » ou « station » au départ / à l'arrivée : seulement alors, le formulaire demande le vol / train et la pancarte.
  final String? pickupKind;
  final String? destinationKind;
  final double distanceKm;
  final double durationMinutes;
}

class Profile {
  Profile.fromJson(Map<String, dynamic> json)
      : firstName = (json['user'] as Map<String, dynamic>)['first_name'] as String? ?? '',
        lastName = (json['user'] as Map<String, dynamic>)['last_name'] as String? ?? '',
        email = (json['user'] as Map<String, dynamic>)['email'] as String? ?? '',
        phone = (json['user'] as Map<String, dynamic>)['phone'] as String? ?? '';

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
}

// Course du client (réservation confirmée, ou dans « Mes courses »).
class Ride {
  Ride.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        reference = json['reference'] as String,
        status = json['status'] as String,
        paymentStatus = json['payment_status'] as String,
        pickup = json['pickup_address'] as String,
        destination = json['destination_address'] as String,
        departureAt = _date(json['departure_at'])!,
        returnAt = _date(json['return_at']),
        quotedPrice = _num(json['quoted_price']),
        amountDue = json['amount_due'] == null ? _num(json['quoted_price']) : _num(json['amount_due']),
        promoDiscount = _num(json['promo_discount']),
        creditUsed = _num(json['credit_used']),
        transportNumber = json['transport_number'] as String?,
        signName = json['sign_name'] as String?,
        driverName = (json['driver'] as Map<String, dynamic>?)?['name'] as String?,
        carName = (json['car'] as Map<String, dynamic>?)?['name'] as String?,
        carPlate = (json['car'] as Map<String, dynamic>?)?['plate_number'] as String?,
        canCancel = ((json['permissions'] as Map<String, dynamic>?)?['cancel']) == true;

  final int? id;
  final String reference;
  final String status;
  final String paymentStatus;
  final String pickup;
  final String destination;
  final DateTime departureAt;
  final DateTime? returnAt;
  final double quotedPrice;
  final double amountDue;
  final double promoDiscount;
  final double creditUsed;
  final String? transportNumber;
  final String? signName;
  final String? driverName;
  final String? carName;
  final String? carPlate;
  final bool canCancel;

  String get statusLabel => switch (status) {
        'pending' => 'En attente d’un chauffeur',
        'dispatched' => 'Chauffeur en cours d’attribution',
        'accepted' => 'Chauffeur confirmé',
        'in_progress' => 'En cours',
        'completed' => 'Terminée',
        'cancelled' => 'Annulée',
        _ => status,
      };
}
