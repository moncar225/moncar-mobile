import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';

final _nameRe = RegExp(r"^[A-Za-zÀ-ÿ' -]{2,40}$");

/// Téléphone ivoirien : 10 chiffres locaux, avec ou sans +225.
bool _validPhone(String v) {
  var d = v.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('225') && d.length == 13) d = d.substring(3);
  return RegExp(r'^0\d{9}$').hasMatch(d);
}

class _PassengerForm {
  _PassengerForm({
    required this.seat,
    String firstName = '',
    String lastName = '',
    String phone = '',
    this.type = PassengerType.adulte,
  }) : firstName = TextEditingController(text: firstName),
       lastName = TextEditingController(text: lastName),
       phone = TextEditingController(text: phone);

  final String seat;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController phone;
  PassengerType type;

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
  }
}

/// Informations des passagers (un par siège choisi), puis création de
/// la réservation — montant calculé par le « serveur ».
class PassengersPage extends ConsumerStatefulWidget {
  const PassengersPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PassengersPage> createState() => _PassengersPageState();
}

class _PassengersPageState extends ConsumerState<PassengersPage> {
  late final List<_PassengerForm> _forms;
  bool _selfTravels = true;
  bool _submitted = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    final user = ref.read(authProvider).user;
    final seats = draft.selectedSeats;
    // Reprend les passagers déjà saisis (retour arrière) si les sièges
    // n'ont pas changé.
    final saved = {
      for (final p in draft.passengers)
        if (p.seatNumber != null) p.seatNumber!: p,
    };
    _forms = [
      for (var i = 0; i < seats.length; i++)
        if (saved[seats[i]] case final p?)
          _PassengerForm(
            seat: seats[i],
            firstName: p.firstName,
            lastName: p.lastName,
            phone: p.phone,
            type: p.type,
          )
        else if (i == 0 && user != null)
          _PassengerForm(
            seat: seats[i],
            firstName: user.firstName,
            lastName: user.lastName,
            phone: user.phone,
          )
        else
          _PassengerForm(seat: seats[i]),
    ];
  }

  @override
  void dispose() {
    for (final f in _forms) {
      f.dispose();
    }
    super.dispose();
  }

  void _setSelfTravels(bool v) {
    final user = ref.read(authProvider).user;
    final first = _forms.first;
    setState(() {
      _selfTravels = v;
      first.firstName.text = v ? (user?.firstName ?? '') : '';
      first.lastName.text = v ? (user?.lastName ?? '') : '';
      first.phone.text = v ? (user?.phone ?? '') : '';
    });
  }

  Map<String, String> _errorsFor(int i) {
    final f = _forms[i];
    final e = <String, String>{};
    if (!_nameRe.hasMatch(f.firstName.text.trim())) {
      e['firstName'] = 'Prénom requis (2 caractères min.).';
    }
    if (!_nameRe.hasMatch(f.lastName.text.trim())) {
      e['lastName'] = 'Nom requis (2 caractères min.).';
    }
    final phone = f.phone.text.trim();
    // Le 1er passager sert de contact : téléphone obligatoire.
    if ((i == 0 || phone.isNotEmpty) && !_validPhone(phone)) {
      e['phone'] = 'Numéro ivoirien à 10 chiffres (ex. 07 00 11 22 33).';
    }
    return e;
  }

  bool get _allValid =>
      List.generate(_forms.length, _errorsFor).every((e) => e.isEmpty);

  List<Passenger> _passengers() => [
    for (var i = 0; i < _forms.length; i++)
      Passenger(
        id: 'ps_${i + 1}',
        firstName: _forms[i].firstName.text.trim(),
        lastName: _forms[i].lastName.text.trim(),
        phone: _forms[i].phone.text.trim(),
        type: _forms[i].type,
        seatNumber: _forms[i].seat,
      ),
  ];

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_allValid) {
      showMoncarToast(
        context,
        'Complétez les informations des passagers.',
        error: true,
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    final passengers = _passengers();
    ref
        .read(bookingDraftProvider.notifier)
        .update((d) => d.copyWith(passengers: passengers));
    final draft = ref.read(bookingDraftProvider);
    final q = GoRouterState.of(context).uri.queryParameters;
    final trip = ref.read(mockStoreProvider).findTrip(widget.tripId);
    // ⚠️ MOCK : POST /bookings (latence simulée).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final r = ref
        .read(mockStoreProvider)
        .createBooking(
          tripId: widget.tripId,
          boardingStopId:
              q['boarding'] ??
              draft.boardingStopId ??
              trip?.stops.first.id ??
              '',
          alightingStopId:
              q['alighting'] ??
              draft.alightingStopId ??
              trip?.stops.last.id ??
              '',
          seats: draft.selectedSeats,
          passengers: passengers,
          tripType: draft.tripType,
          promoCode: draft.promoCode,
          idempotencyKey: generateIdempotencyKey(),
          returnTripId: draft.returnLeg?.trip.id,
          returnBoardingStopId: draft.returnLeg?.boardingStopId,
          returnAlightingStopId: draft.returnLeg?.alightingStopId,
          returnSeats: draft.returnLeg?.seats ?? const [],
        );
    setState(() => _submitting = false);
    final booking = r.booking;
    if (!r.ok || booking == null) {
      showMoncarToast(
        context,
        r.error ?? 'Réservation échouée. Sièges peut-être pris.',
        error: true,
      );
      return;
    }
    ref
        .read(bookingDraftProvider.notifier)
        .update(
          (d) => d.copyWith(
            amountXOF: booking.amountXOF,
            feesXOF: booking.feesXOF,
            discountXOF: booking.discountXOF,
            totalXOF: booking.totalXOF,
          ),
        );
    context.push('/voyager/recap/${booking.id}');
  }

  @override
  Widget build(BuildContext context) {
    final n = _forms.length;
    if (n == 0) {
      return Scaffold(
        appBar: const TopBar(title: 'Passagers', showBack: true),
        body: MoncarEmptyState(
          icon: Icons.event_seat_outlined,
          title: 'Aucun siège sélectionné',
          message: 'Choisissez vos sièges avant de renseigner les passagers.',
          actionLabel: 'Retour',
          onAction: () => context.mcBack(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Passagers',
        subtitle: '$n passager${n > 1 ? 's' : ''} · 1 siège chacun',
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          MoncarCard(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Je fais partie des voyageurs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                ),
                Switch(
                  value: _selfTravels,
                  activeTrackColor: MoncarColors.accent,
                  onChanged: _setSelfTravels,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < n; i++) ...[
            _PassengerCard(
              index: i,
              form: _forms[i],
              errors: _submitted ? _errorsFor(i) : const {},
              phoneRequired: i == 0,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 12, color: MoncarColors.inkFaint),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Les noms doivent correspondre aux pièces d’identité présentées à l’embarquement. '
                  'Le passager 1 reçoit les billets par SMS.',
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: StickyBottomBar(
        child: MoncarButton(
          label: 'Confirmer les passagers',
          icon: Icons.arrow_forward,
          variant: MoncarButtonVariant.primary,
          size: MoncarButtonSize.lg,
          expand: true,
          isLoading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ),
    );
  }
}

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({
    required this.index,
    required this.form,
    required this.errors,
    required this.phoneRequired,
    required this.onChanged,
  });

  final int index;
  final _PassengerForm form;
  final Map<String, String> errors;
  final bool phoneRequired;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.person_outline,
                background: MoncarColors.brandSoft,
                size: 32,
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Passager ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
              MoncarBadge(
                label: 'Siège ${form.seat}',
                tone: MoncarBadgeTone.accent,
                size: MoncarBadgeSize.sm,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (t, label) in const [
                (PassengerType.adulte, 'Adulte'),
                (PassengerType.enfant, 'Enfant (-12 ans)'),
              ]) ...[
                MoncarChip(
                  label: label,
                  active: form.type == t,
                  onTap: () {
                    form.type = t;
                    onChanged();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          MoncarTextField(
            label: 'Prénom',
            controller: form.firstName,
            hint: 'ex. Aïcha',
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            error: errors['firstName'],
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          MoncarTextField(
            label: 'Nom',
            controller: form.lastName,
            hint: 'ex. Koné',
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            error: errors['lastName'],
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          MoncarTextField(
            label: phoneRequired
                ? 'Téléphone (contact)'
                : 'Téléphone (optionnel)',
            controller: form.phone,
            hint: '07 00 11 22 33',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d +]')),
            ],
            error: errors['phone'],
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
