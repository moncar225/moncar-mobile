// ============================================================
// MON CAR — Store mock mutable (portage de `src/lib/mock/store.ts`)
// ⚠️ MOCK : remplace PostgreSQL + Redis. Toutes les règles métier
// (exclusion de sièges, idempotence, machine à états paiement,
// montants calculés serveur) sont appliquées ICI, jamais dans
// les écrans. Les écrans finaux devront appeler l'API réelle.
// ============================================================

library;

import 'dart:math';

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../utils/format.dart';
import 'mock_data.dart';

class _SeatLock {
  _SeatLock({required this.seats, required this.expiresAt, this.bookingId});
  final List<String> seats;
  final DateTime expiresAt;
  final String? bookingId;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _OtpEntry {
  _OtpEntry({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
  int attempts = 0;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Store mock de l'application. Notifie ses auditeurs (Riverpod) à
/// chaque mutation pour rafraîchir les écrans qui l'écoutent.
class MockStore extends ChangeNotifier {
  final Random _rand = Random();

  List<Trip> trips;
  List<Booking> bookings;
  List<Payment> payments;
  List<Ticket> tickets;
  List<Parcel> parcels;
  List<Rental> rentals;
  List<Promotion> promotions;
  List<AppNotification> notifications;
  Loyalty loyalty;
  AppUser user;
  final List<City> cities;
  final List<Company> companies;
  final Map<String, _SeatLock> _seatLocks = {};
  final Map<String, _OtpEntry> _otpCodes = {};

  /// ⚠️ MOCK : comptes « numéro → SHA-256(numéro + mot de passe) ».
  /// Le compte démo (+225 07 00 11 22 33) a le mot de passe `Moncar2026`.
  final Map<String, String> _passwords = {
    '+2250700112233': _hashPassword('+2250700112233', 'Moncar2026'),
  };

  MockStore()
    : trips = List.of(TRIPS),
      bookings = List.of(DEMO_BOOKINGS),
      payments = List.of(DEMO_PAYMENTS),
      tickets = List.of(DEMO_TICKETS),
      parcels = List.of(DEMO_PARCELS),
      rentals = List.of(DEMO_RENTALS),
      promotions = List.of(PROMOTIONS),
      notifications = List.of(NOTIFICATIONS_SEED),
      loyalty = LOYALTY_SEED,
      user = DEMO_USER,
      cities = CITIES,
      companies = COMPANIES;

  // ----------------------------- Recherches -----------------------------

  // ⚠️ MOCK : équivalents des endpoints GET du prototype
  // (`/trips/search`, `/rentals/vehicles`, `/tickets/:id`, …).

  List<Trip> searchTrips({
    String origin = '',
    String destination = '',
    String date = '',
  }) {
    return trips.where((t) {
      if (origin.isNotEmpty &&
          t.originCityName.toLowerCase() != origin.toLowerCase()) {
        return false;
      }
      if (destination.isNotEmpty &&
          t.destinationCityName.toLowerCase() != destination.toLowerCase()) {
        return false;
      }
      if (date.isNotEmpty && t.date != date) return false;
      return true;
    }).toList();
  }

  Line? findLineForTrip(String tripId) {
    final trip = findTrip(tripId);
    if (trip == null) return null;
    for (final l in LINES) {
      if (l.id == trip.lineId) return l;
    }
    return null;
  }

  Booking? findBooking(String id) =>
      bookings.where((b) => b.id == id).firstOrNull;

  Payment? findPayment(String id) =>
      payments.where((p) => p.id == id).firstOrNull;

  Ticket? findTicket(String idOrNumber) => tickets
      .where((t) => t.id == idOrNumber || t.number == idOrNumber)
      .firstOrNull;

  Parcel? findParcel(String idOrTracking) => parcels
      .where((p) => p.id == idOrTracking || p.trackingNumber == idOrTracking)
      .firstOrNull;

  Rental? findRental(String id) => rentals.where((r) => r.id == id).firstOrNull;

  Trip? findTrip(String tripId) {
    for (final t in trips) {
      if (t.id == tripId) return t;
    }
    return null;
  }

  Vehicle? findVehicle(String vehicleId) {
    for (final v in VEHICLES) {
      if (v.id == vehicleId) return v;
    }
    return null;
  }

  Promotion? findPromotionById(String id) {
    for (final p in promotions) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ----------------------------- Sièges -----------------------------

  SeatMap? getSeatMap(
    String tripId,
    String boardingStopId,
    String alightingStopId,
  ) {
    final trip = findTrip(tripId);
    if (trip == null) return null;
    final vehicle = findVehicle(trip.vehicleId);
    if (vehicle == null) return null;
    // Sièges occupés par les réservations existantes + verrous actifs.
    final takenFromBookings = [
      for (final b in bookings)
        if (b.status != BookingStatus.annule &&
            b.status != BookingStatus.expire) ...[
          if (b.tripId == tripId) ...b.seats,
          if (b.returnLeg?.tripId == tripId) ...b.returnLeg!.seats,
        ],
    ];
    final lock = _seatLocks[tripId];
    final takenFromLock = lock != null && !lock.isExpired
        ? lock.seats
        : <String>[];
    return generateSeatMap(tripId, vehicle, boardingStopId, alightingStopId, [
      ...takenFromBookings,
      ...takenFromLock,
    ]);
  }

  /// Verrouille des sièges pour un brouillon de réservation (15 min).
  ({bool ok, List<String> conflict}) lockSeats(
    String tripId,
    List<String> seats,
  ) {
    final existing = _seatLocks[tripId];
    if (existing != null && !existing.isExpired) {
      final conflict = seats.where(existing.seats.contains).toList();
      if (conflict.isNotEmpty) return (ok: false, conflict: conflict);
    }
    _seatLocks[tripId] = _SeatLock(
      seats: seats,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    return (ok: true, conflict: const <String>[]);
  }

  void unlockSeats(String tripId) => _seatLocks.remove(tripId);

  // ----------------------------- Réservations -----------------------------

  /// Total calculé « serveur » — seule source de vérité.
  ({int amountXOF, int feesXOF, int discountXOF, int totalXOF})
  computeBookingTotal(
    Trip trip,
    List<Seat> seats,
    int passengerCount, {
    String? promoCode,
  }) {
    final seatTotal = seats.isNotEmpty
        ? seats.fold<int>(0, (sum, seat) => sum + seat.priceXOF)
        : trip.priceXOF * passengerCount;
    const feesXOF = 200;
    var discountXOF = 0;
    if (promoCode != null && promoCode.isNotEmpty) {
      Promotion? promo;
      for (final p in promotions) {
        if (p.code.toLowerCase() == promoCode.toLowerCase()) promo = p;
      }
      if (promo != null) {
        final valid = _validatePromoInternal(promo, seatTotal);
        if (valid.valid) discountXOF = valid.discountXOF;
      }
    }
    final totalXOF = seatTotal + feesXOF - discountXOF;
    return (
      amountXOF: seatTotal,
      feesXOF: feesXOF,
      discountXOF: discountXOF,
      totalXOF: totalXOF < 0 ? 0 : totalXOF,
    );
  }

  PromoValidation _validatePromoInternal(Promotion promo, int baseAmount) {
    final now = DateTime.now();
    final from = DateTime.parse('${promo.validFrom}T00:00:00');
    final until = DateTime.parse('${promo.validUntil}T23:59:59');
    if (now.isBefore(from) || now.isAfter(until)) {
      return PromoValidation(
        valid: false,
        reasonCode: PromoInvalidReason.expire,
        message: 'Ce code promotionnel a expiré.',
        discountXOF: 0,
        newTotalXOF: baseAmount,
      );
    }
    if (promo.usageCount >= promo.usageMax) {
      return PromoValidation(
        valid: false,
        reasonCode: PromoInvalidReason.usageAtteint,
        message: 'Cette promotion a atteint son quota d\'utilisation.',
        discountXOF: 0,
        newTotalXOF: baseAmount,
      );
    }
    if (loyaltyTierRank(user.loyaltyTier) < loyaltyTierRank(promo.minTier)) {
      return PromoValidation(
        valid: false,
        reasonCode: PromoInvalidReason.tierInsuffisant,
        message:
            'Réservé aux membres ${promo.minTier.label.toUpperCase()} et plus.',
        discountXOF: 0,
        newTotalXOF: baseAmount,
      );
    }
    final discount = promo.type == PromoType.pourcentage
        ? (baseAmount * promo.value / 100).round()
        : promo.value;
    return PromoValidation(
      valid: true,
      message: 'Code appliqué.',
      discountXOF: discount,
      newTotalXOF: baseAmount - discount,
    );
  }

  PromoValidation validatePromo(
    String code,
    int baseAmount,
    PromoService service,
  ) {
    Promotion? promo;
    for (final p in promotions) {
      if (p.code.toLowerCase() == code.toLowerCase()) promo = p;
    }
    if (promo == null) {
      return PromoValidation(
        valid: false,
        reasonCode: PromoInvalidReason.invalide,
        message: 'Code promotionnel invalide.',
        discountXOF: 0,
        newTotalXOF: baseAmount,
      );
    }
    if (promo.service != PromoService.tous && promo.service != service) {
      return PromoValidation(
        valid: false,
        reasonCode: PromoInvalidReason.mauvaisService,
        message: 'Ce code est valable pour ${promo.service.name}.',
        discountXOF: 0,
        newTotalXOF: baseAmount,
      );
    }
    return _validatePromoInternal(promo, baseAmount);
  }

  ({bool ok, Booking? booking, String? error}) createBooking({
    required String tripId,
    required String boardingStopId,
    required String alightingStopId,
    required List<String> seats,
    required List<Passenger> passengers,
    required TripType tripType,
    String? promoCode,
    required String idempotencyKey,
    // Aller-retour : segment retour (trajet, arrêts, sièges).
    String? returnTripId,
    String? returnBoardingStopId,
    String? returnAlightingStopId,
    List<String> returnSeats = const [],
  }) {
    final trip = findTrip(tripId);
    if (trip == null) {
      return (ok: false, booking: null, error: 'Trajet introuvable.');
    }
    final returnTrip = returnTripId == null ? null : findTrip(returnTripId);
    if (tripType == TripType.allerRetour && returnTrip == null) {
      return (ok: false, booking: null, error: 'Trajet retour introuvable.');
    }
    if (returnTrip != null && returnSeats.length != seats.length) {
      return (
        ok: false,
        booking: null,
        error: 'Choisissez autant de sièges au retour qu\'à l\'aller.',
      );
    }

    // Idempotence : même clé → même réservation.
    for (final b in bookings) {
      if (b.idempotencyKey == idempotencyKey) {
        return (ok: true, booking: b, error: null);
      }
    }

    // Revérification de la disponibilité des sièges (autorité serveur).
    final seatMap = getSeatMap(tripId, boardingStopId, alightingStopId);
    if (seatMap == null) {
      return (ok: false, booking: null, error: 'Plan de sièges indisponible.');
    }
    final conflict = seats.where((sn) {
      final s = seatMap.seats.where((x) => x.number == sn).firstOrNull;
      return s == null ||
          s.status == SeatStatus.taken ||
          s.status == SeatStatus.blocked;
    }).toList();
    if (conflict.isNotEmpty) {
      return (
        ok: false,
        booking: null,
        error: 'Sièges indisponibles : ${conflict.join(', ')}',
      );
    }

    // Segment retour : même revérification côté serveur.
    SeatMap? returnSeatMap;
    if (returnTrip != null) {
      returnSeatMap = getSeatMap(
        returnTrip.id,
        returnBoardingStopId ?? returnTrip.stops.first.id,
        returnAlightingStopId ?? returnTrip.stops.last.id,
      );
      if (returnSeatMap == null) {
        return (
          ok: false,
          booking: null,
          error: 'Plan de sièges du retour indisponible.',
        );
      }
      final returnConflict = returnSeats.where((sn) {
        final s = returnSeatMap!.seats.where((x) => x.number == sn).firstOrNull;
        return s == null ||
            s.status == SeatStatus.taken ||
            s.status == SeatStatus.blocked;
      }).toList();
      if (returnConflict.isNotEmpty) {
        return (
          ok: false,
          booking: null,
          error:
              'Sièges indisponibles au retour : ${returnConflict.join(', ')}',
        );
      }
    }

    final lock = lockSeats(tripId, seats);
    if (!lock.ok) {
      return (
        ok: false,
        booking: null,
        error: 'Conflit de réservation : ${lock.conflict.join(', ')}',
      );
    }
    if (returnTrip != null) {
      final returnLock = lockSeats(returnTrip.id, returnSeats);
      if (!returnLock.ok) {
        unlockSeats(tripId);
        return (
          ok: false,
          booking: null,
          error:
              'Conflit de réservation au retour : ${returnLock.conflict.join(', ')}',
        );
      }
    }

    // Le serveur calcule le montant (aller + retour, frais une fois).
    final selectedSeats = [
      ...seatMap.seats.where((s) => seats.contains(s.number)),
      if (returnSeatMap != null)
        ...returnSeatMap.seats.where((s) => returnSeats.contains(s.number)),
    ];
    final totals = computeBookingTotal(
      trip,
      selectedSeats,
      passengers.length,
      promoCode: promoCode,
    );

    final id = 'b_${_randBase36(6)}';
    final reference = 'MON-RSV-${_randBase36(4).toUpperCase()}';
    final originStop = trip.stops
        .where((s) => s.id == boardingStopId)
        .firstOrNull;
    final destStop = trip.stops
        .where((s) => s.id == alightingStopId)
        .firstOrNull;

    final booking = Booking(
      id: id,
      reference: reference,
      tripId: tripId,
      tripSummary: '${trip.originCityName} → ${trip.destinationCityName}',
      companyName: trip.companyName,
      date: trip.date,
      departureTime: trip.departureTime,
      arrivalTime: trip.arrivalTime,
      originStop: originStop?.label ?? trip.stops.first.label,
      destinationStop: destStop?.label ?? trip.stops.last.label,
      passengers: List.generate(
        passengers.length,
        (i) => Passenger(
          id: 'ps_${id}_$i',
          firstName: passengers[i].firstName,
          lastName: passengers[i].lastName,
          phone: passengers[i].phone,
          type: passengers[i].type,
          seatNumber: passengers[i].seatNumber,
          idDocument: passengers[i].idDocument,
        ),
      ),
      seats: seats,
      tripType: tripType,
      amountXOF: totals.amountXOF,
      feesXOF: totals.feesXOF,
      discountXOF: totals.discountXOF,
      totalXOF: totals.totalXOF,
      status: BookingStatus.enAttente,
      idempotencyKey: idempotencyKey,
      cancellationPolicy: trip.cancellationPolicy,
      createdAt: isoNow(),
      expiresAt: isoOffsetMs(15 * 60 * 1000),
      returnLeg: returnTrip == null
          ? null
          : ReturnLeg(
              tripId: returnTrip.id,
              tripSummary:
                  '${returnTrip.originCityName} → ${returnTrip.destinationCityName}',
              companyName: returnTrip.companyName,
              date: returnTrip.date,
              departureTime: returnTrip.departureTime,
              arrivalTime: returnTrip.arrivalTime,
              originStop: _stopLabel(
                returnTrip,
                returnBoardingStopId,
                first: true,
              ),
              destinationStop: _stopLabel(
                returnTrip,
                returnAlightingStopId,
                first: false,
              ),
              seats: returnSeats,
            ),
    );

    bookings.insert(0, booking);
    _seatLocks[tripId] = _SeatLock(
      seats: seats,
      expiresAt: DateTime.parse(booking.expiresAt),
      bookingId: id,
    );
    if (returnTrip != null) {
      _seatLocks[returnTrip.id] = _SeatLock(
        seats: returnSeats,
        expiresAt: DateTime.parse(booking.expiresAt),
        bookingId: id,
      );
    }

    if (promoCode != null && promoCode.isNotEmpty) {
      for (final p in promotions) {
        if (p.code.toLowerCase() == promoCode.toLowerCase()) {
          promotions[promotions.indexOf(p)] = Promotion(
            id: p.id,
            code: p.code,
            title: p.title,
            description: p.description,
            type: p.type,
            value: p.value,
            service: p.service,
            minTier: p.minTier,
            validFrom: p.validFrom,
            validUntil: p.validUntil,
            usageMax: p.usageMax,
            usageCount: p.usageCount + 1,
            terms: p.terms,
            imageColor: p.imageColor,
            featured: p.featured,
          );
        }
      }
    }

    notifyListeners();
    return (ok: true, booking: booking, error: null);
  }

  static String _stopLabel(Trip trip, String? stopId, {required bool first}) =>
      trip.stops.where((s) => s.id == stopId).firstOrNull?.label ??
      (first ? trip.stops.first.label : trip.stops.last.label);

  ({bool ok, Booking? booking}) cancelBooking(String bookingId) {
    Booking? b;
    for (final x in bookings) {
      if (x.id == bookingId) b = x;
    }
    if (b == null) return (ok: false, booking: null);
    final updated = _copyBookingWith(b, status: BookingStatus.annule);
    bookings[bookings.indexOf(b)] = updated;
    unlockSeats(updated.tripId);
    final returnLeg = updated.returnLeg;
    if (returnLeg != null) unlockSeats(returnLeg.tripId);
    if (updated.paymentId != null) {
      _updatePayment(updated.paymentId!, (p) {
        if (p.status == PaymentStatus.enAttente) {
          return _copyPaymentWith(p, status: PaymentStatus.annule);
        }
        return p;
      });
    }
    for (final ticketId in [updated.ticketId, returnLeg?.ticketId]) {
      if (ticketId == null) continue;
      _updateTicket(
        ticketId,
        (t) => _copyTicketWith(t, status: TicketStatus.annule),
      );
    }
    notifyListeners();
    return (ok: true, booking: updated);
  }

  // ----------------------------- Paiements -----------------------------

  ({bool ok, Payment? payment, String? error}) createPayment({
    String? bookingId,
    String? parcelId,
    String? rentalId,
    required PaymentMethod method,
    required String idempotencyKey,
  }) {
    for (final p in payments) {
      if (p.idempotencyKey == idempotencyKey) {
        return (ok: true, payment: p, error: null);
      }
    }

    int amount = 0;
    if (bookingId != null) {
      final b = bookings.where((x) => x.id == bookingId).firstOrNull;
      if (b == null) {
        return (ok: false, payment: null, error: 'Réservation introuvable.');
      }
      amount = b.totalXOF;
    } else if (parcelId != null) {
      final p = parcels.where((x) => x.id == parcelId).firstOrNull;
      if (p == null) {
        return (ok: false, payment: null, error: 'Colis introuvable.');
      }
      amount = p.amountXOF;
    } else if (rentalId != null) {
      final r = rentals.where((x) => x.id == rentalId).firstOrNull;
      if (r == null) {
        return (ok: false, payment: null, error: 'Location introuvable.');
      }
      // Règles 9-10 : paiement uniquement après confirmation du
      // fournisseur (ou facture complémentaire émise).
      if (r.status == RentalStatus.confirmee) {
        amount = r.quote.totalXOF;
      } else if (r.pendingCharge != null) {
        amount = r.pendingCharge!.amountXOF;
      } else {
        return (
          ok: false,
          payment: null,
          error: 'Aucun paiement possible : location non confirmée.',
        );
      }
    }

    final payment = Payment(
      id: 'pm_${_randBase36(6)}',
      reference: 'PMT-${_randBase36(4).toUpperCase()}',
      bookingId: bookingId,
      parcelId: parcelId,
      rentalId: rentalId,
      amountXOF: amount,
      method: method,
      status: PaymentStatus.enAttente,
      idempotencyKey: idempotencyKey,
      createdAt: isoNow(),
      expiresAt: isoOffsetMs(5 * 60 * 1000),
    );
    payments.insert(0, payment);
    notifyListeners();
    return (ok: true, payment: payment, error: null);
  }

  /// Simule le webhook du PSP : confirme après un court délai.
  /// Le premier paiement réussit toujours (démo).
  ({bool ok, Payment? payment}) processPayment(String paymentId) {
    Payment? payment;
    for (final p in payments) {
      if (p.id == paymentId) payment = p;
    }
    if (payment == null) return (ok: false, payment: null);
    if (payment.status != PaymentStatus.enAttente) {
      return (ok: true, payment: payment);
    }
    final isFirst = payment == payments.last;
    final success = isFirst || _rand.nextDouble() > 0.1;
    if (success) {
      var updated = _copyPaymentWith(
        payment,
        status: PaymentStatus.paye,
        gatewayRef:
            '${payment.method.name.substring(0, 2).toUpperCase()}-${_randBase36(6)}',
        confirmedAt: isoNow(),
      );
      payments[payments.indexOf(payment)] = updated;

      if (updated.bookingId != null) {
        Booking? booking;
        for (final b in bookings) {
          if (b.id == updated.bookingId) booking = b;
        }
        if (booking != null) {
          var newBooking = _copyBookingWith(
            booking,
            status: BookingStatus.paye,
            paymentId: updated.id,
          );
          // Émission du billet.
          final trip = findTrip(newBooking.tripId);
          if (trip != null && newBooking.ticketId == null) {
            final ticket = Ticket(
              id: 'tkt_${_randBase36(6)}',
              number: 'MON-BLT-${_randBase36(4).toUpperCase()}',
              bookingId: newBooking.id,
              passengerName:
                  '${newBooking.passengers.first.firstName} ${newBooking.passengers.first.lastName}',
              companyName: trip.companyName,
              originCity: trip.originCityName,
              destinationCity: trip.destinationCityName,
              boardingStop: newBooking.originStop,
              alightingStop: newBooking.destinationStop,
              date: trip.date,
              departureTime: trip.departureTime,
              arrivalTime: trip.arrivalTime,
              seatNumber: newBooking.seats.join(', '),
              vehicleModel: trip.vehicleModel,
              qrPayload:
                  'MONCAR|${newBooking.id}|${trip.id}|${newBooking.seats.join('-')}|${trip.date}|${trip.departureTime}',
              signature: _randBase36(32),
              keyVersion: 1,
              status: TicketStatus.emis,
              issuedAt: isoNow(),
              tripId: trip.id,
            );
            tickets.insert(0, ticket);
            newBooking = _copyBookingWith(newBooking, ticketId: ticket.id);
            // Aller-retour : billet distinct pour le retour (propre QR).
            final leg = newBooking.returnLeg;
            final returnTrip = leg == null ? null : findTrip(leg.tripId);
            if (leg != null && returnTrip != null) {
              final returnTicket = Ticket(
                id: 'tkt_${_randBase36(6)}',
                number: 'MON-BLT-${_randBase36(4).toUpperCase()}',
                bookingId: newBooking.id,
                passengerName: ticket.passengerName,
                companyName: returnTrip.companyName,
                originCity: returnTrip.originCityName,
                destinationCity: returnTrip.destinationCityName,
                boardingStop: leg.originStop,
                alightingStop: leg.destinationStop,
                date: returnTrip.date,
                departureTime: returnTrip.departureTime,
                arrivalTime: returnTrip.arrivalTime,
                seatNumber: leg.seats.join(', '),
                vehicleModel: returnTrip.vehicleModel,
                qrPayload:
                    'MONCAR|${newBooking.id}|${returnTrip.id}|${leg.seats.join('-')}|${returnTrip.date}|${returnTrip.departureTime}|R',
                signature: _randBase36(32),
                keyVersion: 1,
                status: TicketStatus.emis,
                issuedAt: isoNow(),
                tripId: returnTrip.id,
                leg: TicketLeg.retour,
              );
              tickets.insert(0, returnTicket);
              newBooking = _copyBookingWith(
                newBooking,
                returnLeg: leg.withTicket(returnTicket.id),
              );
            }
            // Points de fidélité attribués côté serveur.
            loyalty = _copyLoyaltyWith(
              loyalty,
              points: loyalty.points + newBooking.totalXOF ~/ 100,
            );
          }
          bookings[bookings.indexOf(booking)] = newBooking;
        }
      }
      if (updated.parcelId != null) {
        _updateParcel(
          updated.parcelId!,
          (p) => Parcel(
            id: p.id,
            trackingNumber: p.trackingNumber,
            senderName: p.senderName,
            senderPhone: p.senderPhone,
            recipientName: p.recipientName,
            recipientPhone: p.recipientPhone,
            originCity: p.originCity,
            destinationCity: p.destinationCity,
            originStop: p.originStop,
            destinationStop: p.destinationStop,
            tripId: p.tripId,
            weightKg: p.weightKg,
            dimensions: p.dimensions,
            description: p.description,
            photoUrl: p.photoUrl,
            payeeIsSender: p.payeeIsSender,
            amountXOF: p.amountXOF,
            status: p.status,
            timeline: p.timeline,
            createdAt: p.createdAt,
            paymentId: updated.id,
          ),
        );
      }
      if (updated.rentalId != null) {
        _applyRentalPayment(updated.rentalId!, updated.id);
      }
      payment = updated;
    } else {
      final updated = _copyPaymentWith(
        payment,
        status: PaymentStatus.echoue,
        failureReason:
            "Transaction refusée par l'opérateur. Vérifiez votre solde ou réessayez.",
      );
      payments[payments.indexOf(payment)] = updated;
      payment = updated;
    }
    notifyListeners();
    return (ok: true, payment: payment);
  }

  // ----------------------------- Colis -----------------------------

  ({bool ok, Parcel? parcel, String? error}) createParcel({
    required String senderName,
    required String senderPhone,
    required String recipientName,
    required String recipientPhone,
    required String originCity,
    required String destinationCity,
    required String originStop,
    required String destinationStop,
    String? tripId,
    required double weightKg,
    required String dimensions,
    required String description,
    required bool payeeIsSender,
  }) {
    // Montant calculé « serveur ».
    const base = 1500;
    const perKg = 350;
    final amount = base + (weightKg * perKg).round();

    final id = 'col_${_randBase36(6)}';
    final trackingNumber = 'MON-COL-${_randBase36(4).toUpperCase()}';
    final now = isoNow();

    final parcel = Parcel(
      id: id,
      trackingNumber: trackingNumber,
      senderName: senderName,
      senderPhone: senderPhone,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      originCity: originCity,
      destinationCity: destinationCity,
      originStop: originStop,
      destinationStop: destinationStop,
      tripId: tripId,
      weightKg: weightKg,
      dimensions: dimensions,
      description: description,
      payeeIsSender: payeeIsSender,
      amountXOF: amount,
      status: ParcelStatus.depose,
      timeline: [
        ParcelTimelineEntry(
          status: ParcelStatus.depose,
          label: 'Colis déposé',
          location: originStop,
          at: now,
          done: true,
        ),
        ParcelTimelineEntry(
          status: ParcelStatus.enTransit,
          label: 'En transit',
          location: '$originCity → $destinationCity',
          at: isoOffsetMs(3600000),
          done: false,
        ),
        ParcelTimelineEntry(
          status: ParcelStatus.arriveGare,
          label: 'Arrivé à la gare',
          location: destinationStop,
          at: isoOffsetMs(86400000),
          done: false,
        ),
        ParcelTimelineEntry(
          status: ParcelStatus.attenteRetrait,
          label: 'En attente de retrait',
          location: destinationStop,
          at: isoOffsetMs(86400000 + 3600000),
          done: false,
        ),
        ParcelTimelineEntry(
          status: ParcelStatus.livre,
          label: 'Livré',
          location: destinationCity,
          at: isoOffsetMs(2 * 86400000),
          done: false,
        ),
      ],
      createdAt: now,
    );
    parcels.insert(0, parcel);
    notifyListeners();
    return (ok: true, parcel: parcel, error: null);
  }

  // ----------------------------- Locations -----------------------------
  // ⚠️ MOCK : équivalents de l'API LOC-001 à LOC-005. Toutes les règles
  // métier (filtrage, tarifs, statuts, séquestre) sont appliquées ici,
  // jamais dans les écrans.

  /// Frais d'opération MON CAR (Y) : 5 % du brut, 500 FCFA minimum.
  static const rentalFeesPct = 5;
  static const rentalFeesMinXOF = 500;

  RentalVehicle? findRentalVehicle(String vehicleId) {
    for (final v in RENTAL_VEHICLES) {
      if (v.id == vehicleId) return v;
    }
    return null;
  }

  /// Statuts qui bloquent le véhicule sur leur période (règle 8).
  static const _blockingRentalStatuses = {
    RentalStatus.confirmee,
    RentalStatus.payee,
    RentalStatus.remise,
    RentalStatus.active,
  };

  /// Le véhicule est-il libre sur [start, end[ ? (hors [ignoreRentalId]).
  bool isRentalVehicleFree(
    String vehicleId,
    DateTime start,
    DateTime end, {
    String? ignoreRentalId,
  }) {
    for (final r in rentals) {
      if (r.vehicleId != vehicleId || r.id == ignoreRentalId) continue;
      if (!_blockingRentalStatuses.contains(r.status)) continue;
      final a = DateTime.parse(r.plannedStart);
      final b = DateTime.parse(r.plannedEnd);
      if (start.isBefore(b) && a.isBefore(end)) return false;
    }
    return true;
  }

  /// GET /rentals/vehicles — filtrage §33 : localisation, intérieur /
  /// extérieur, capacité, catégorie, chauffeur (règle VTC), disponibilité.
  List<RentalVehicle> searchRentalVehicles(RentalCriteria c) {
    final start = DateTime.parse(c.start);
    final end = DateTime.parse(c.end);
    return RENTAL_VEHICLES.where((v) {
      if (!v.available) return false;
      if (v.city.toLowerCase() != c.pickupCity.toLowerCase()) return false;
      if (c.area == RentalArea.exterieur && !v.allowsExterior) return false;
      if (v.seats < c.persons) return false;
      if (c.collective != null && v.isCollective != c.collective) return false;
      if (c.type != null && v.type != c.type) return false;
      if (c.withDriver && !v.canBeWithDriver) return false;
      if (!c.withDriver && !v.canBeWithoutDriver) return false;
      return isRentalVehicleFree(v.id, start, end);
    }).toList();
  }

  /// Durée facturable : demi-journée (≤ 12 h, 60 % du tarif jour) ou
  /// nombre de jours entamés.
  ({double units, String label}) _billableDays(DateTime start, DateTime end) {
    final hours = end.difference(start).inMinutes / 60;
    if (hours <= 12) return (units: 0.6, label: 'Demi-journée');
    final days = (hours / 24).ceil();
    return (units: days.toDouble(), label: '$days jour${days > 1 ? 's' : ''}');
  }

  /// Devis serveur (§35 tarification, §38 facture) : X + Y + Z.
  RentalQuote quoteRental(
    RentalVehicle v,
    RentalCriteria c, {
    List<String> optionIds = const [],
  }) {
    final billable = _billableDays(
      DateTime.parse(c.start),
      DateTime.parse(c.end),
    );
    final units = billable.units;
    final lines = <RentalQuoteLine>[];
    final base = (v.pricePerDayXOF * units).round();
    lines.add(RentalQuoteLine('Location · ${billable.label}', base));
    if (c.area == RentalArea.exterieur && v.exteriorSurchargePct > 0) {
      lines.add(
        RentalQuoteLine(
          'Tarif extérieur (+${v.exteriorSurchargePct} %)',
          (base * v.exteriorSurchargePct / 100).round(),
        ),
      );
    }
    if (c.withDriver && v.driverFeePerDayXOF > 0) {
      lines.add(
        RentalQuoteLine(
          'Chauffeur · ${billable.label}',
          (v.driverFeePerDayXOF * units).round(),
        ),
      );
    }
    for (final o in v.options.where((o) => optionIds.contains(o.id))) {
      lines.add(
        RentalQuoteLine(
          '${o.label} · ${billable.label}',
          (o.pricePerDayXOF * units).round(),
        ),
      );
    }
    final brut = lines.fold<int>(0, (s, l) => s + l.amountXOF);
    final pct = (brut * rentalFeesPct / 100).round();
    final fees = pct < rentalFeesMinXOF ? rentalFeesMinXOF : pct;
    final other = <RentalQuoteLine>[
      if (!c.withDriver)
        const RentalQuoteLine('Vérification des documents', 1000),
      if (c.area == RentalArea.exterieur)
        const RentalQuoteLine('Assistance hors localité', 2000),
    ];
    final otherTotal = other.fold<int>(0, (s, l) => s + l.amountXOF);
    return RentalQuote(
      brutLines: lines,
      brutXOF: brut,
      feesXOF: fees,
      otherFees: other,
      otherFeesXOF: otherTotal,
      totalXOF: brut + fees + otherTotal,
      billableLabel: billable.label,
    );
  }

  List<RentalEvent> _withEvent(Rental r, String label) => [
    ...r.timeline,
    RentalEvent(label, isoNow()),
  ];

  /// POST /rentals — DEMANDER UNE RÉSERVATION (§36). Aucun paiement :
  /// statut EN ATTENTE DE CONFIRMATION.
  ({bool ok, Rental? rental, String? error}) createRentalRequest({
    required String vehicleId,
    required RentalCriteria criteria,
    List<String> optionIds = const [],
    String? licenseNumber,
    String? idDocumentNumber,
  }) {
    final v = findRentalVehicle(vehicleId);
    if (v == null || !v.available) {
      return (ok: false, rental: null, error: 'Véhicule non disponible.');
    }
    if (criteria.withDriver && !v.canBeWithDriver) {
      return (
        ok: false,
        rental: null,
        error: 'Ce véhicule est proposé sans chauffeur.',
      );
    }
    if (!criteria.withDriver && !v.canBeWithoutDriver) {
      return (
        ok: false,
        rental: null,
        error: v.isVtc
            ? 'Un VTC est obligatoirement loué avec chauffeur.'
            : 'Ce véhicule est proposé uniquement avec chauffeur.',
      );
    }
    if (criteria.area == RentalArea.exterieur &&
        (criteria.destinationCity ?? '').isEmpty) {
      return (
        ok: false,
        rental: null,
        error: 'Indiquez le lieu de destination.',
      );
    }
    if (!criteria.withDriver &&
        ((licenseNumber ?? '').trim().isEmpty ||
            (idDocumentNumber ?? '').trim().isEmpty)) {
      return (
        ok: false,
        rental: null,
        error:
            'Permis et pièce d\'identité requis pour une location sans chauffeur.',
      );
    }
    final start = DateTime.parse(criteria.start);
    final end = DateTime.parse(criteria.end);
    if (!end.isAfter(start)) {
      return (ok: false, rental: null, error: 'Période invalide.');
    }
    if (!isRentalVehicleFree(v.id, start, end)) {
      return (
        ok: false,
        rental: null,
        error: 'Véhicule déjà réservé sur cette période.',
      );
    }
    final rental = Rental(
      id: 'r_${_randBase36(6)}',
      reference: 'MON-LOC-${_randBase36(4).toUpperCase()}',
      vehicleId: v.id,
      vehicleSummary: v.summary,
      providerName: v.partner,
      providerKind: v.providerKind,
      criteria: criteria,
      optionLabels: [
        for (final o in v.options)
          if (optionIds.contains(o.id)) o.label,
      ],
      quote: quoteRental(v, criteria, optionIds: optionIds),
      status: RentalStatus.demandee,
      createdAt: isoNow(),
      timeline: [RentalEvent('Demande envoyée à ${v.partner}', isoNow())],
      licenseNumber: licenseNumber,
      idDocumentNumber: idDocumentNumber,
    );
    rentals.insert(0, rental);
    notifyListeners();
    return (ok: true, rental: rental, error: null);
  }

  /// Annulation par le client — possible avant la remise du véhicule.
  ({bool ok, String? error}) cancelRental(String rentalId) {
    final r = findRental(rentalId);
    if (r == null) return (ok: false, error: 'Location introuvable.');
    if (!{
      RentalStatus.demandee,
      RentalStatus.confirmee,
      RentalStatus.payee,
    }.contains(r.status)) {
      return (ok: false, error: 'Cette location ne peut plus être annulée.');
    }
    final paid = r.status == RentalStatus.payee;
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        status: RentalStatus.annulee,
        timeline: _withEvent(
          x,
          paid
              ? 'Annulée par le client — remboursement selon les conditions'
              : 'Annulée par le client',
        ),
      ),
    );
    notifyListeners();
    return (ok: true, error: null);
  }

  // --- Actions du fournisseur (app PRO / espace BUSINESS) — ⚠️ MOCK :
  // simulées ici tant que l'espace fournisseur n'existe pas.

  /// CONFIRMER / REFUSER la demande (§37).
  void providerRespond(
    String rentalId, {
    required bool accept,
    String? reason,
  }) {
    final r = findRental(rentalId);
    if (r == null || r.status != RentalStatus.demandee) return;
    _updateRental(
      rentalId,
      (x) => accept
          ? x.copyWith(
              status: RentalStatus.confirmee,
              timeline: _withEvent(x, 'Confirmée par ${x.providerName}'),
            )
          : x.copyWith(
              status: RentalStatus.refusee,
              refusalReason: reason ?? 'Véhicule indisponible à ces dates.',
              timeline: _withEvent(x, 'Refusée par ${x.providerName}'),
            ),
    );
    notifyListeners();
  }

  /// VÉHICULE REMIS (§40) : l'heure de remise devient le début réel (§41).
  void providerHandover(String rentalId) {
    final r = findRental(rentalId);
    if (r == null || r.status != RentalStatus.payee) return;
    final now = DateTime.now();
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        status: RentalStatus.remise,
        handoverAt: now.toIso8601String(),
        handoverLocation: x.criteria.pickupLabel,
        driverName: x.withDriver ? 'Yao Kouassi' : null,
        timeline: _withEvent(x, 'Véhicule remis par ${x.providerName}'),
      ),
    );
    notifyListeners();
  }

  /// VÉHICULE RÉCUPÉRÉ / RETOURNÉ (§47) : enregistre la restitution et
  /// calcule les heures supplémentaires éventuelles (§46).
  void providerRecordReturn(String rentalId, {int lateHours = 0}) {
    final r = findRental(rentalId);
    if (r == null || r.status != RentalStatus.active) return;
    final v = findRentalVehicle(r.vehicleId);
    final start = r.startCondition;
    final returnedAt = DateTime.now();
    final overtime = lateHours > 0 && v != null
        ? RentalCharge(
            kind: RentalChargeKind.heuresSupplementaires,
            label: 'Heures supplémentaires',
            lines: [
              RentalQuoteLine(
                '$lateHours h × ${v.extraHourXOF} FCFA',
                lateHours * v.extraHourXOF,
              ),
            ],
            amountXOF: lateHours * v.extraHourXOF,
          )
        : null;
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        status: RentalStatus.restituee,
        returnedAt: returnedAt.toIso8601String(),
        returnCondition: VehicleCondition(
          recordedAt: returnedAt.toIso8601String(),
          mileageKm: (start?.mileageKm ?? 0) + 184,
          fuelEighths: ((start?.fuelEighths ?? 8) - 2).clamp(0, 8),
          photos: const [
            'avant',
            'arriere',
            'cote_gauche',
            'cote_droit',
            'tableau_bord',
          ],
          recordedBy: 'fournisseur',
        ),
        pendingCharge: overtime,
        timeline: _withEvent(
          x,
          overtime == null
              ? 'Véhicule restitué — contrôle en cours'
              : 'Véhicule restitué avec $lateHours h de retard',
        ),
      ),
    );
    notifyListeners();
  }

  /// Contrôle du retour conforme (§48) → location terminée (§50).
  ({bool ok, String? error}) providerCloseRental(String rentalId) {
    final r = findRental(rentalId);
    if (r == null || r.status != RentalStatus.restituee) {
      return (ok: false, error: 'Location non restituée.');
    }
    if (r.pendingCharge != null) {
      return (ok: false, error: 'Facture complémentaire non réglée.');
    }
    if (r.hasOpenIncident) {
      return (ok: false, error: 'Un dossier d\'incident est en cours.');
    }
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        status: RentalStatus.terminee,
        timeline: _withEvent(x, 'État contrôlé — location terminée'),
      ),
    );
    notifyListeners();
    return (ok: true, error: null);
  }

  /// Réponse du fournisseur à une demande de prolongation (§45).
  void providerRespondExtension(
    String rentalId,
    String extensionId, {
    required bool accept,
  }) {
    final r = findRental(rentalId);
    if (r == null) return;
    final ext = r.extensions.where((e) => e.id == extensionId).firstOrNull;
    if (ext == null || ext.status != RentalExtensionStatus.demandee) return;
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        extensions: [
          for (final e in x.extensions)
            e.id == extensionId
                ? RentalExtension(
                    id: e.id,
                    extraLabel: e.extraLabel,
                    newEnd: e.newEnd,
                    amountXOF: e.amountXOF,
                    status: accept
                        ? RentalExtensionStatus.acceptee
                        : RentalExtensionStatus.refusee,
                    requestedAt: e.requestedAt,
                  )
                : e,
        ],
        pendingCharge: accept ? _extensionCharge(ext) : null,
        timeline: _withEvent(
          x,
          accept
              ? 'Prolongation acceptée — facture complémentaire émise'
              : 'Prolongation refusée par le fournisseur',
        ),
      ),
    );
    notifyListeners();
  }

  RentalCharge _extensionCharge(RentalExtension e) => RentalCharge(
    kind: RentalChargeKind.prolongation,
    label: 'Prolongation (${e.extraLabel})',
    lines: [RentalQuoteLine('Prolongation · ${e.extraLabel}', e.amountXOF)],
    amountXOF: e.amountXOF,
    extensionId: e.id,
  );

  // --- Actions du client.

  /// État initial : VÉHICULE CONFORME ou SIGNALER UNE ANOMALIE (§42).
  /// La location devient active ; une anomalie ouvre un dossier.
  ({bool ok, String? error}) submitStartCondition(
    String rentalId,
    VehicleCondition condition,
  ) {
    final r = findRental(rentalId);
    if (r == null || r.status != RentalStatus.remise) {
      return (ok: false, error: 'Le véhicule n\'a pas encore été remis.');
    }
    if (condition.mileageKm <= 0) {
      return (ok: false, error: 'Indiquez le kilométrage.');
    }
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        status: RentalStatus.active,
        startCondition: condition,
        incidents: condition.conforme
            ? x.incidents
            : [
                ...x.incidents,
                RentalIncident(
                  id: 'inc_${_randBase36(5)}',
                  nature: RentalIncidentNature.anomalie,
                  description: condition.anomaly,
                  at: isoNow(),
                  location: x.handoverLocation ?? x.criteria.pickupLabel,
                  status: RentalIncidentStatus.enExamen,
                  photoCount: condition.photos.length,
                ),
              ],
        timeline: _withEvent(
          x,
          condition.conforme
              ? 'Véhicule conforme — location active'
              : 'Anomalie signalée à la remise — location active',
        ),
      ),
    );
    notifyListeners();
    return (ok: true, error: null);
  }

  /// Aperçu serveur d'une prolongation : nouvelle échéance, montant et
  /// disponibilité du véhicule (vérifiée immédiatement, §45).
  ({bool available, int amountXOF, String newEnd, String? error})
  previewExtension(String rentalId, int extraDays) {
    final r = findRental(rentalId);
    final v = r == null ? null : findRentalVehicle(r.vehicleId);
    if (r == null || v == null) {
      return (
        available: false,
        amountXOF: 0,
        newEnd: '',
        error: 'Location introuvable.',
      );
    }
    final oldEnd = DateTime.parse(r.plannedEnd);
    final newEnd = oldEnd.add(Duration(days: extraDays));
    final free = isRentalVehicleFree(
      v.id,
      oldEnd,
      newEnd,
      ignoreRentalId: r.id,
    );
    final perDay = v.pricePerDayXOF + (r.withDriver ? v.driverFeePerDayXOF : 0);
    return (
      available: free,
      amountXOF: perDay * extraDays,
      newEnd: newEnd.toIso8601String(),
      error: free ? null : 'Véhicule déjà réservé sur cette période.',
    );
  }

  /// PROLONGER MA LOCATION (§45) : disponibilité vérifiée immédiatement,
  /// jamais de conflit avec la réservation suivante.
  ({bool ok, RentalExtension? extension, String? error}) requestExtension(
    String rentalId, {
    required int extraDays,
  }) {
    final r = findRental(rentalId);
    if (r == null || r.status != RentalStatus.active) {
      return (ok: false, extension: null, error: 'Location non active.');
    }
    if (r.pendingCharge != null ||
        r.extensions.any((e) => e.status == RentalExtensionStatus.demandee)) {
      return (
        ok: false,
        extension: null,
        error: 'Une prolongation est déjà en cours de traitement.',
      );
    }
    final v = findRentalVehicle(r.vehicleId);
    if (v == null) {
      return (ok: false, extension: null, error: 'Véhicule introuvable.');
    }
    final oldEnd = DateTime.parse(r.plannedEnd);
    final newEnd = oldEnd.add(Duration(days: extraDays));
    if (!isRentalVehicleFree(v.id, oldEnd, newEnd, ignoreRentalId: r.id)) {
      return (
        ok: false,
        extension: null,
        error:
            'Véhicule déjà réservé après votre location : prolongation impossible.',
      );
    }
    final perDay = v.pricePerDayXOF + (r.withDriver ? v.driverFeePerDayXOF : 0);
    final label = '+$extraDays jour${extraDays > 1 ? 's' : ''}';
    final ext = RentalExtension(
      id: 'ext_${_randBase36(5)}',
      extraLabel: label,
      newEnd: newEnd.toIso8601String(),
      amountXOF: perDay * extraDays,
      status: v.requiresExtensionApproval
          ? RentalExtensionStatus.demandee
          : RentalExtensionStatus.acceptee,
      requestedAt: isoNow(),
    );
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        extensions: [...x.extensions, ext],
        pendingCharge: v.requiresExtensionApproval
            ? null
            : _extensionCharge(ext),
        timeline: _withEvent(
          x,
          v.requiresExtensionApproval
              ? 'Demande de prolongation ($label) envoyée'
              : 'Prolongation ($label) disponible — facture complémentaire émise',
        ),
      ),
    );
    notifyListeners();
    return (ok: true, extension: ext, error: null);
  }

  /// Dossier d'incident (§49).
  RentalIncident? reportRentalIncident(
    String rentalId, {
    required RentalIncidentNature nature,
    required String description,
    int photoCount = 0,
  }) {
    final r = findRental(rentalId);
    if (r == null) return null;
    final incident = RentalIncident(
      id: 'inc_${_randBase36(5)}',
      nature: nature,
      description: description,
      at: isoNow(),
      location: r.criteria.destination,
      status: RentalIncidentStatus.ouvert,
      photoCount: photoCount,
    );
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        incidents: [...x.incidents, incident],
        timeline: _withEvent(x, 'Incident déclaré : ${nature.label}'),
      ),
    );
    notifyListeners();
    return incident;
  }

  /// Évaluation après clôture (§50).
  void rateRental(String rentalId, int stars, String review) {
    _updateRental(
      rentalId,
      (x) => x.copyWith(
        rating: stars.clamp(1, 5),
        review: review,
        timeline: _withEvent(x, 'Évaluation envoyée'),
      ),
    );
    notifyListeners();
  }

  /// Paiement confirmé (webhook PSP) : location, prolongation ou
  /// heures supplémentaires.
  void _applyRentalPayment(String rentalId, String paymentId) {
    final r = findRental(rentalId);
    if (r == null) return;
    if (r.status == RentalStatus.confirmee) {
      _updateRental(
        rentalId,
        (x) => x.copyWith(
          status: RentalStatus.payee,
          paymentId: paymentId,
          timeline: _withEvent(
            x,
            'Paiement confirmé — fonds sécurisés jusqu\'à la remise',
          ),
        ),
      );
      return;
    }
    final charge = r.pendingCharge;
    if (charge == null) return;
    _updateRental(rentalId, (x) {
      final isExt = charge.kind == RentalChargeKind.prolongation;
      final ext = x.extensions
          .where((e) => e.id == charge.extensionId)
          .firstOrNull;
      return x.copyWith(
        clearPendingCharge: true,
        extraCharges: [...x.extraCharges, charge],
        plannedEndOverride: isExt ? ext?.newEnd : null,
        extensions: [
          for (final e in x.extensions)
            e.id == charge.extensionId
                ? RentalExtension(
                    id: e.id,
                    extraLabel: e.extraLabel,
                    newEnd: e.newEnd,
                    amountXOF: e.amountXOF,
                    status: RentalExtensionStatus.payee,
                    requestedAt: e.requestedAt,
                  )
                : e,
        ],
        timeline: _withEvent(
          x,
          isExt
              ? 'Prolongation payée — nouvelle échéance'
              : 'Heures supplémentaires réglées',
        ),
      );
    });
  }

  // ----------------------------- Suivi GPS -----------------------------

  final Map<
    String,
    ({
      double progress,
      TrackingState state,
      int currentStopIndex,
      String lastUpdate,
    })
  >
  _trackingSeed = {};

  BusPosition? getTracking(String tripId) {
    final trip = findTrip(tripId);
    if (trip == null) return null;
    var seed = _trackingSeed[tripId];
    seed ??= (
      progress: 40.0,
      state: trip.status == TripStatus.termine
          ? TrackingState.termine
          : TrackingState.disponible,
      currentStopIndex: (trip.stops.length * 0.4).floor(),
      lastUpdate: isoNow(),
    );
    var progress = seed.progress;
    var state = seed.state;
    var currentStopIndex = seed.currentStopIndex;
    if (state == TrackingState.disponible && progress < 100) {
      progress = (progress + _rand.nextDouble() * 4).clamp(0, 100);
      currentStopIndex = (progress / 100 * (trip.stops.length - 1)).floor();
      if (progress >= 100) state = TrackingState.termine;
    }
    _trackingSeed[tripId] = (
      progress: progress,
      state: state,
      currentStopIndex: currentStopIndex,
      lastUpdate: isoNow(),
    );

    final stops = List.generate(trip.stops.length, (i) {
      final isPast = i < currentStopIndex;
      final isCurrent = i == currentStopIndex;
      return TrackingStopState(
        id: trip.stops[i].id,
        name: trip.stops[i].label,
        arrivalTime: i == 0 ? trip.departureTime : null,
        status: isPast
            ? 'passe'
            : isCurrent
            ? 'actuel'
            : 'a_venir',
        reachedAt: isPast || isCurrent
            ? isoOffsetMs(-(currentStopIndex - i) * 1800000)
            : null,
      );
    });
    final nextStop = currentStopIndex + 1 < trip.stops.length
        ? trip.stops[currentStopIndex + 1]
        : null;
    final cur = trip.stops[currentStopIndex];
    final nxt = nextStop ?? cur;
    final segLen = 100 / (trip.stops.length - 1);
    final segProgress = (progress % segLen) / segLen;
    final lat = cur.latitude + (nxt.latitude - cur.latitude) * segProgress;
    final lng = cur.longitude + (nxt.longitude - cur.longitude) * segProgress;
    final heading =
        (_atan2Deg(nxt.longitude - cur.longitude, nxt.latitude - cur.latitude) +
            360) %
        360;
    return BusPosition(
      tripId: tripId,
      latitude: lat,
      longitude: lng,
      heading: heading.roundToDouble(),
      speedKmh: state == TrackingState.disponible ? 75 : 0,
      lastUpdate: _trackingSeed[tripId]!.lastUpdate,
      state: state,
      currentStopIndex: currentStopIndex,
      nextStopId: nextStop?.id,
      nextStopName: nextStop?.label,
      etaToNextStopMin: nextStop != null
          ? ((nextStop.minutesFromOrigin - cur.minutesFromOrigin) *
                    (1 - segProgress))
                .round()
          : 0,
      progressPct: progress.round(),
      stops: stops,
    );
  }

  static double _atan2Deg(double dy, double dx) {
    if (dx == 0 && dy == 0) return 0;
    return atan2(dy, dx) * 180 / pi;
  }

  // ----------------------------- Notifications -----------------------------

  void markNotificationRead(String id) {
    for (var i = 0; i < notifications.length; i++) {
      final n = notifications[i];
      if (n.id == id && !n.read) {
        notifications[i] = AppNotification(
          id: n.id,
          category: n.category,
          title: n.title,
          body: n.body,
          read: true,
          linkTarget: n.linkTarget,
          createdAt: n.createdAt,
          iconColor: n.iconColor,
          muted: n.muted,
        );
      }
    }
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (var i = 0; i < notifications.length; i++) {
      final n = notifications[i];
      if (!n.read) {
        notifications[i] = AppNotification(
          id: n.id,
          category: n.category,
          title: n.title,
          body: n.body,
          read: true,
          linkTarget: n.linkTarget,
          createdAt: n.createdAt,
          iconColor: n.iconColor,
          muted: n.muted,
        );
      }
    }
    notifyListeners();
  }

  // ----------------------------- Auth / OTP -----------------------------

  /// ⚠️ MOCK : le code OTP est renvoyé à l'écran (dans la vraie API il
  /// serait envoyé par SMS). Affiché explicitement comme code de démo.
  ({String code, String expiresAt}) requestOtp(String phone) {
    final code = (100000 + _rand.nextInt(900000)).toString();
    final expiresAt = isoOffsetMs(8 * 60 * 1000);
    _otpCodes[phone] = _OtpEntry(
      code: code,
      expiresAt: DateTime.parse(expiresAt),
    );
    return (code: code, expiresAt: expiresAt);
  }

  bool verifyOtp(String phone, String code) {
    final entry = _otpCodes[phone];
    if (entry == null) return false;
    if (entry.isExpired) return false;
    if (entry.attempts >= 5) return false;
    entry.attempts += 1;
    if (entry.code == code) {
      _otpCodes.remove(phone);
      return true;
    }
    return false;
  }

  static String _hashPassword(String phone, String password) =>
      sha256.convert(utf8.encode('$phone:$password')).toString();

  /// ⚠️ MOCK : un compte existe-t-il pour ce numéro (+225…) ?
  bool hasAccount(String phone) => _passwords.containsKey(phone);

  /// ⚠️ MOCK : POST /auth/login — vérifie le couple numéro/mot de passe.
  bool checkPassword(String phone, String password) =>
      _passwords[phone] == _hashPassword(phone, password);

  /// ⚠️ MOCK : POST /auth/register et POST /auth/password/reset —
  /// enregistre (ou remplace) le mot de passe du numéro.
  void setPassword(String phone, String password) {
    _passwords[phone] = _hashPassword(phone, password);
  }

  /// Connexion mock : crée une session de démo avec l'utilisateur démo.
  AuthSession loginDemo() {
    return AuthSession(
      user: user,
      accessToken: 'mock_access_${_randBase36(12)}',
      refreshToken: 'mock_refresh_${_randBase36(12)}',
      expiresAt: isoOffsetMs(3600 * 1000),
    );
  }

  // ----------------------------- Copie d'entités immuables -----------------------------

  static Booking _copyBookingWith(
    Booking b, {
    BookingStatus? status,
    String? paymentId,
    String? ticketId,
    ReturnLeg? returnLeg,
  }) {
    return Booking(
      id: b.id,
      reference: b.reference,
      tripId: b.tripId,
      tripSummary: b.tripSummary,
      companyName: b.companyName,
      date: b.date,
      departureTime: b.departureTime,
      arrivalTime: b.arrivalTime,
      originStop: b.originStop,
      destinationStop: b.destinationStop,
      passengers: b.passengers,
      seats: b.seats,
      tripType: b.tripType,
      amountXOF: b.amountXOF,
      feesXOF: b.feesXOF,
      discountXOF: b.discountXOF,
      totalXOF: b.totalXOF,
      status: status ?? b.status,
      idempotencyKey: b.idempotencyKey,
      cancellationPolicy: b.cancellationPolicy,
      createdAt: b.createdAt,
      expiresAt: b.expiresAt,
      paymentId: paymentId ?? b.paymentId,
      ticketId: ticketId ?? b.ticketId,
      returnLeg: returnLeg ?? b.returnLeg,
    );
  }

  static Payment _copyPaymentWith(
    Payment p, {
    PaymentStatus? status,
    String? gatewayRef,
    String? failureReason,
    String? confirmedAt,
  }) {
    return Payment(
      id: p.id,
      reference: p.reference,
      bookingId: p.bookingId,
      parcelId: p.parcelId,
      rentalId: p.rentalId,
      amountXOF: p.amountXOF,
      method: p.method,
      status: status ?? p.status,
      idempotencyKey: p.idempotencyKey,
      gatewayRef: gatewayRef ?? p.gatewayRef,
      failureReason: failureReason ?? p.failureReason,
      createdAt: p.createdAt,
      confirmedAt: confirmedAt ?? p.confirmedAt,
      expiresAt: p.expiresAt,
    );
  }

  static Ticket _copyTicketWith(Ticket t, {TicketStatus? status}) {
    return Ticket(
      id: t.id,
      number: t.number,
      bookingId: t.bookingId,
      passengerName: t.passengerName,
      companyName: t.companyName,
      originCity: t.originCity,
      destinationCity: t.destinationCity,
      boardingStop: t.boardingStop,
      alightingStop: t.alightingStop,
      date: t.date,
      departureTime: t.departureTime,
      arrivalTime: t.arrivalTime,
      seatNumber: t.seatNumber,
      vehicleModel: t.vehicleModel,
      qrPayload: t.qrPayload,
      signature: t.signature,
      keyVersion: t.keyVersion,
      status: status ?? t.status,
      issuedAt: t.issuedAt,
      tripId: t.tripId,
      leg: t.leg,
    );
  }

  static Loyalty _copyLoyaltyWith(Loyalty l, {int? points}) {
    return Loyalty(
      userId: l.userId,
      tier: l.tier,
      points: points ?? l.points,
      pointsToNextTier: l.pointsToNextTier,
      nextTier: l.nextTier,
      progressPct: l.progressPct,
      tierBenefits: l.tierBenefits,
      expiryDate: l.expiryDate,
      rewards: l.rewards,
      history: l.history,
    );
  }

  void _updatePayment(String id, Payment Function(Payment) updater) {
    for (var i = 0; i < payments.length; i++) {
      if (payments[i].id == id) payments[i] = updater(payments[i]);
    }
  }

  void _updateTicket(String id, Ticket Function(Ticket) updater) {
    for (var i = 0; i < tickets.length; i++) {
      if (tickets[i].id == id) tickets[i] = updater(tickets[i]);
    }
  }

  void _updateParcel(String id, Parcel Function(Parcel) updater) {
    for (var i = 0; i < parcels.length; i++) {
      if (parcels[i].id == id) parcels[i] = updater(parcels[i]);
    }
  }

  void _updateRental(String id, Rental Function(Rental) updater) {
    for (var i = 0; i < rentals.length; i++) {
      if (rentals[i].id == id) rentals[i] = updater(rentals[i]);
    }
  }

  String _randBase36(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => chars[_rand.nextInt(chars.length)],
    ).join();
  }
}
