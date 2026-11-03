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
        validationLabel = (json['driver'] as Map<String, dynamic>?)?['validation_label'] as String?;

  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final bool available;
  final String? validationLabel;
}
