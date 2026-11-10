// Données reçues de l'API (mêmes champs que le site).

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value');
double _num(Object? value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;

class Proposal {
  Proposal.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        bookingId = json['booking_id'] as int,
        driverShare = _num(json['driver_share']),
        pickup = (json['booking'] as Map<String, dynamic>)['pickup_address'] as String,
        destination = (json['booking'] as Map<String, dynamic>)['destination_address'] as String,
        departureAt = _date((json['booking'] as Map<String, dynamic>)['departure_at'])!,
        roundTrip = (json['booking'] as Map<String, dynamic>)['trip_type'] == 'round_trip',
        distanceKm = _num((json['booking'] as Map<String, dynamic>)['outbound_distance_km']),
        durationMinutes = _num((json['booking'] as Map<String, dynamic>)['outbound_duration_minutes']),
        babySeats = ((json['booking'] as Map<String, dynamic>)['baby_seats_count'] as int?) ?? 0,
        boosterSeats = ((json['booking'] as Map<String, dynamic>)['booster_seats_count'] as int?) ?? 0,
        transportNumber = (json['booking'] as Map<String, dynamic>)['transport_number'] as String?;

  final int id;
  final int bookingId;
  final double driverShare;
  final String pickup;
  final String destination;
  final DateTime departureAt;
  final bool roundTrip;
  final double distanceKm;
  final double durationMinutes;
  final int babySeats;
  final int boosterSeats;
  final String? transportNumber;
}

// Remarque (information) ou signalement (à traiter par l'équipe) envoyé par le chauffeur sur sa course.
class DriverNote {
  DriverNote.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        remark = json['remark'] == true,
        label = json['label'] as String?,
        body = json['body'] as String?,
        handled = json['status'] == 'resolved',
        createdAt = _date(json['created_at'])!;

  final int id;
  final bool remark;
  final String? label;
  final String? body;
  final bool handled;
  final DateTime createdAt;
}

// Étape de la course côté chauffeur (dans l'ordre de l'app).
enum RideStep { toAccept, accepted, onTheWay, arrived, inProgress, completed, cancelled }

class Ride {
  Ride.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        reference = json['reference'] as String,
        status = json['status'] as String,
        paymentStatus = json['payment_status'] as String,
        pickup = json['pickup_address'] as String,
        destination = json['destination_address'] as String,
        departureAt = _date(json['departure_at'])!,
        returnAt = _date(json['return_at']),
        roundTrip = json['trip_type'] == 'round_trip',
        customerName = '${json['customer_first_name'] ?? ''} ${json['customer_last_name'] ?? ''}'.trim(),
        customerPhone = json['customer_phone'] as String?,
        babySeats = (json['baby_seats_count'] as int?) ?? 0,
        boosterSeats = (json['booster_seats_count'] as int?) ?? 0,
        quotedPrice = _num(json['quoted_price']),
        driverShare = json['driver_share'] == null ? null : _num(json['driver_share']),
        expectedShare = json['expected_share'] == null ? null : _num(json['expected_share']),
        payoutStatus = json['payout_status'] as String?,
        departedAt = _date(json['departed_at']),
        arrivedAt = _date(json['arrived_at']),
        startedAt = _date(json['started_at']),
        finishedAt = _date(json['finished_at']),
        waitingFee = _num(json['waiting_fee']),
        carName = (json['car'] as Map<String, dynamic>?)?['name'] as String?,
        transportNumber = json['transport_number'] as String?,
        signName = json['sign_name'] as String?,
        arrivalDelayMinutes = json['arrival_delay_minutes'] as int?,
        late = json['late'] == true,
        freeWaitingMinutes = (json['free_waiting_minutes'] as int?) ?? 15,
        notes = ((json['driver_notes'] as List?) ?? []).map((n) => DriverNote.fromJson(n as Map<String, dynamic>)).toList(),
        permissions = ((json['permissions'] as Map<String, dynamic>?) ?? {}).map((key, value) => MapEntry(key, value == true));

  final int id;
  final String reference;
  final String status;
  final String paymentStatus;
  final String pickup;
  final String destination;
  final DateTime departureAt;
  final DateTime? returnAt;
  final bool roundTrip;
  final String customerName;
  final String? customerPhone;
  final int babySeats;
  final int boosterSeats;
  final double quotedPrice;
  final double? driverShare;
  // Gain prévu tant que la course n'est pas terminée.
  final double? expectedShare;
  final String? payoutStatus;
  final DateTime? departedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final double waitingFee;
  final String? carName;
  // Aéroport / gare : vol ou train à suivre, nom à écrire sur la pancarte.
  final String? transportNumber;
  final String? signName;
  // Retard à l'arrivée chez le client (minutes après l'heure annoncée) ; late selon la tolérance de la plateforme.
  final int? arrivalDelayMinutes;
  final bool late;
  // Attente offerte au client (plus longue à l'aéroport) ; au-delà, l'attente lui est facturée.
  final int freeWaitingMinutes;
  final List<DriverNote> notes;
  final Map<String, bool> permissions;

  bool can(String action) => permissions[action] ?? false;

  RideStep get step {
    switch (status) {
      case 'dispatched':
        return RideStep.toAccept;
      case 'in_progress':
        return RideStep.inProgress;
      case 'completed':
        return RideStep.completed;
      case 'cancelled':
        return RideStep.cancelled;
    }
    if (arrivedAt != null) return RideStep.arrived;
    if (departedAt != null) return RideStep.onTheWay;
    return RideStep.accepted;
  }
}

class EarningMonth {
  EarningMonth.fromJson(Map<String, dynamic> json)
      : month = json['month'] as String,
        count = json['bookings_count'] as int,
        earned = _num(json['earned']),
        paid = _num(json['paid']),
        toReceive = _num(json['to_receive']);

  final String month;
  final int count;
  final double earned;
  final double paid;
  final double toReceive;
}

class Payout {
  Payout.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        label = json['label'] as String,
        amount = _num(json['amount']),
        count = json['bookings_count'] as int,
        paid = json['status'] == 'paid',
        paidAt = _date(json['paid_at']),
        reference = json['reference'] as String?;

  final int id;
  final String label;
  final double amount;
  final int count;
  final bool paid;
  final DateTime? paidAt;
  final String? reference;
}

class Earnings {
  Earnings.fromJson(Map<String, dynamic> json)
      : commissionRate = _num(json['commission_rate']),
        months = (json['months'] as List).map((m) => EarningMonth.fromJson(m as Map<String, dynamic>)).toList(),
        due = _num(json['due']),
        awaitingClient = _num(json['awaiting_client']),
        payouts = (json['payouts'] as List).map((p) => Payout.fromJson(p as Map<String, dynamic>)).toList(),
        punctualityRate = (json['punctuality'] as Map<String, dynamic>?)?['rate'] as int?,
        arrivals = ((json['punctuality'] as Map<String, dynamic>?)?['arrivals'] as int?) ?? 0,
        lateArrivals = ((json['punctuality'] as Map<String, dynamic>?)?['late'] as int?) ?? 0,
        lateToleranceMinutes = (json['late_tolerance_minutes'] as int?) ?? 10;

  final double commissionRate;
  final List<EarningMonth> months;
  final double due;
  final double awaitingClient;
  final List<Payout> payouts;
  // Ponctualité sur 3 mois : part des arrivées à l'heure (null sans arrivée signalée).
  final int? punctualityRate;
  final int arrivals;
  final int lateArrivals;
  final int lateToleranceMinutes;

  // À recevoir : courses dues pas encore relevées + relevés en préparation.
  double get toReceive => due + payouts.where((p) => !p.paid).fold(0.0, (sum, p) => sum + p.amount);
}

class DriverProfile {
  DriverProfile.fromJson(Map<String, dynamic> json)
      : firstName = (json['user'] as Map<String, dynamic>)['first_name'] as String? ?? '',
        lastName = (json['user'] as Map<String, dynamic>)['last_name'] as String? ?? '',
        email = (json['user'] as Map<String, dynamic>)['email'] as String? ?? '',
        phone = (json['user'] as Map<String, dynamic>)['phone'] as String?,
        available = (json['driver'] as Map<String, dynamic>?)?['available'] as bool? ?? true,
        validationLabel = (json['driver'] as Map<String, dynamic>?)?['validation_label'] as String?,
        validationStatus = (json['driver'] as Map<String, dynamic>?)?['validation_status'] as String?,
        detailsMissing = _strings((json['driver'] as Map<String, dynamic>?)?['details_missing']),
        documentsMissing = _strings((json['driver'] as Map<String, dynamic>?)?['documents_missing']),
        locked = (json['driver'] as Map<String, dynamic>?)?['locked'] as bool? ?? false,
        details = DriverDetails.fromJson((json['driver'] as Map<String, dynamic>?) ?? const {}),
        documents = ((json['driver'] as Map<String, dynamic>?)?['documents'] as List? ?? const [])
            .map((d) => DriverDocument.fromJson(d as Map<String, dynamic>))
            .toList(),
        cars = ((json['driver'] as Map<String, dynamic>?)?['cars'] as List? ?? const []).map((c) => DriverCar.fromJson(c as Map<String, dynamic>)).toList(),
        photo = DriverPhoto.fromJson((json['driver'] as Map<String, dynamic>?) ?? const {});

  static List<String> _strings(Object? value) => (value as List?)?.map((e) => '$e').toList() ?? const [];

  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final bool available;
  final String? validationLabel;
  // Étape du recrutement (identified ... validated) ; null pour un compte sans fiche chauffeur.
  final String? validationStatus;
  final List<String> detailsMissing;
  final List<String> documentsMissing;
  // Dossier relu par l'équipe : les informations réglementées ne se modifient plus.
  final bool locked;
  final DriverDetails details;
  // Pièces personnelles déjà envoyées (celles des véhicules sont dans la fiche du véhicule).
  final List<DriverDocument> documents;
  final List<DriverCar> cars;
  final DriverPhoto photo;

  // L'accès aux courses et aux gains n'est ouvert qu'une fois le dossier validé.
  bool get validated => validationStatus == null || validationStatus == 'validated';
}

// Informations réglementées du dossier (statut, adresse, IBAN, SIRET, société).
class DriverDetails {
  DriverDetails.fromJson(Map<String, dynamic> json)
      : legalStatus = json['legal_status'] as String? ?? 'self_employed',
        address = json['address'] as String? ?? '',
        postcode = json['postcode'] as String? ?? '',
        city = json['city'] as String? ?? '',
        iban = json['iban'] as String? ?? '',
        siret = json['siret'] as String? ?? '',
        businessName = json['business_name'] as String? ?? '',
        rcsCode = json['rcs_code'] as String? ?? '',
        shareCapital = '${json['share_capital'] ?? ''}',
        identityType = json['identity_type'] as String?,
        identityExpiry = json['identity_expiry'] as String?,
        vtcCardNumber = json['vtc_card_number'] as String? ?? '',
        vtcExpiry = json['vtc_expiry'] as String?;

  // self_employed (auto-entrepreneur), company (société) ou taxi.
  final String legalStatus;
  final String address;
  final String postcode;
  final String city;
  final String iban;
  final String siret;
  final String businessName;
  final String rcsCode;
  final String shareCapital;
  // Pièce d'identité (passport, national_identity_card, residency_card), carte VTC ; dates au format AAAA-MM-JJ.
  final String? identityType;
  final String? identityExpiry;
  final String vtcCardNumber;
  final String? vtcExpiry;
}

class DriverDocument {
  DriverDocument.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        kind = json['kind'] as String,
        filename = json['filename'] as String? ?? '',
        byteSize = json['byte_size'] as int? ?? 0;

  final int id;
  // identity, driving_license, vtc_card, company_registration, car_registration, car_insurance, car_picture, car_rental_contract.
  final String kind;
  final String filename;
  final int byteSize;
}

// Véhicule du chauffeur et ses pièces (carte grise, assurance, photo, contrat de location).
class DriverCar {
  DriverCar.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        vehicleTypeId = json['vehicle_type_id'] as int?,
        vehicleTypeName = json['vehicle_type_name'] as String?,
        brand = json['brand'] as String? ?? '',
        model = json['model'] as String? ?? '',
        color = json['color'] as String? ?? '',
        plateNumber = json['plate_number'] as String? ?? '',
        motor = json['motor'] as String? ?? 'gas',
        seats = json['seats'] as int?,
        firstRegistrationOn = json['first_registration_on'] as String?,
        wifi = json['wifi'] as bool? ?? false,
        rental = json['rental'] as bool? ?? false,
        enabled = json['enabled'] as bool? ?? true,
        validationLabel = json['validation_label'] as String? ?? '',
        validated = json['validation_status'] == 'validated',
        locked = json['locked'] as bool? ?? false,
        documentsMissing = ((json['documents_missing'] as List?) ?? const []).map((e) => '$e').toList(),
        documents = ((json['documents'] as List?) ?? const []).map((d) => DriverDocument.fromJson(d as Map<String, dynamic>)).toList();

  final int id;
  final int? vehicleTypeId;
  final String? vehicleTypeName;
  final String brand;
  final String model;
  final String color;
  final String plateNumber;
  // gas (thermique), hybrid ou electric.
  final String motor;
  final int? seats;
  final String? firstRegistrationOn;
  final bool wifi;
  final bool rental;
  final bool enabled;
  final String validationLabel;
  final bool validated;
  // Véhicule validé par l'équipe : seuls l'activation, la couleur et le wifi restent modifiables.
  final bool locked;
  final List<String> documentsMissing;
  final List<DriverDocument> documents;

  String get name => '$brand $model'.trim();
}

class VehicleCategory {
  VehicleCategory.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String,
        passengers = json['passenger_capacity'] as int? ?? 4;

  final int id;
  final String name;
  final int passengers;
}

// Points du chauffeur : score sur la période glissante, rang, priorité sur les nouvelles courses, historique.
class DriverPoints {
  DriverPoints.fromJson(Map<String, dynamic> json)
      : score = json['score'] as int? ?? 0,
        rank = json['rank'] as int?,
        prioritized = json['prioritized'] == true,
        pointsToPriority = json['points_to_priority'] as int?,
        priorityEnabled = (json['priority'] as Map<String, dynamic>?)?['enabled'] == true,
        priorityMinutes = (json['priority'] as Map<String, dynamic>?)?['minutes'] == null ? null : ((json['priority'] as Map<String, dynamic>)['minutes'] as num).toInt(),
        windowDays = json['window_days'] as int? ?? 90,
        rules = ((json['rules'] as List?) ?? const []).map((r) => PointRule.fromJson(r as Map<String, dynamic>)).toList(),
        entries = ((json['entries'] as List?) ?? const []).map((e) => PointEntry.fromJson(e as Map<String, dynamic>)).toList();

  final int score;
  final int? rank;
  final bool prioritized;
  final int? pointsToPriority;
  // Priorité sur les nouvelles courses (désactivable par l'équipe). Le nombre de chauffeurs n'est jamais communiqué.
  final bool priorityEnabled;
  final int? priorityMinutes;
  final int windowDays;
  final List<PointRule> rules;
  final List<PointEntry> entries;
}

class PointRule {
  PointRule.fromJson(Map<String, dynamic> json)
      : label = json['label'] as String,
        points = json['points'] as int;

  final String label;
  final int points;
}

class PointEntry {
  PointEntry.fromJson(Map<String, dynamic> json)
      : label = json['label'] as String? ?? json['kind'] as String,
        points = json['points'] as int,
        createdAt = DateTime.parse(json['created_at'] as String).toLocal(),
        bookingReference = json['booking_reference'] as String?,
        counted = json['counted'] != false;

  final String label;
  final int points;
  final DateTime createdAt;
  final String? bookingReference;
  // Plus ancienne que la période : affichée mais plus comptée.
  final bool counted;
}

// Photo du chauffeur montrée aux clients : approuvée (url), en attente de vérification (pendingUrl), ou refusée (motif).
// Les adresses sont des liens temporaires de l'API (chemins à préfixer par son adresse).
class DriverPhoto {
  DriverPhoto.fromJson(Map<String, dynamic> json)
      : url = json['photo_url'] as String?,
        pendingUrl = json['pending_photo_url'] as String?,
        status = json['photo_status'] as String? ?? 'none',
        rejectionReason = json['photo_rejection_reason'] as String?;

  final String? url;
  final String? pendingUrl;
  // none (rien en attente), pending (en vérification), rejected (dernière photo refusée).
  final String status;
  final String? rejectionReason;

  bool get pending => status == 'pending';
  bool get rejected => status == 'rejected';
  bool get missing => url == null && pendingUrl == null;
}
