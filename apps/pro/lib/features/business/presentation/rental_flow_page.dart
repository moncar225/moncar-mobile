import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/business_controller.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../widgets/signature_pad.dart';

enum _Step {
  dossier('Dossier', Icons.folder_open_rounded),
  client('Client', Icons.badge_rounded),
  vehicule('Véhicule', Icons.directions_car_rounded),
  comparaison('Avant / après', Icons.compare_rounded),
  photos('Photos', Icons.photo_camera_rounded),
  compteur('Km & carburant', Icons.speed_rounded),
  checklist('Checklist', Icons.checklist_rounded),
  anomalies('Anomalies & frais', Icons.report_problem_rounded),
  signature('Signature', Icons.draw_rounded),
  validation('Validation', Icons.verified_rounded);

  const _Step(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _photoSlots = [
  'Avant',
  'Arrière',
  'Côté gauche',
  'Côté droit',
  'Intérieur',
  'Compteur',
];

/// Agent BUSINESS · Remise ou restitution guidée (LOC-004).
/// Enchaînement du CDC : état avant/après, photos, km, carburant,
/// validation du client ; preuve et frais définitifs générés par le serveur.
class RentalFlowPage extends ConsumerStatefulWidget {
  const RentalFlowPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<RentalFlowPage> createState() => _RentalFlowPageState();
}

class _RentalFlowPageState extends ConsumerState<RentalFlowPage> {
  late final RentalTask task = ref
      .read(businessProvider.notifier)
      .byId(widget.taskId);
  late final bool _remise = task.type == RentalTaskType.remise;
  late final List<_Step> _steps = _remise
      ? const [
          _Step.dossier,
          _Step.client,
          _Step.vehicule,
          _Step.photos,
          _Step.compteur,
          _Step.checklist,
          _Step.signature,
          _Step.validation,
        ]
      : const [
          _Step.dossier,
          _Step.vehicule,
          _Step.comparaison,
          _Step.photos,
          _Step.compteur,
          _Step.anomalies,
          _Step.signature,
          _Step.validation,
        ];

  int _i = 0;
  bool _idChecked = false;
  bool _plateOk = false;
  bool _docsOk = false;
  final _idNote = TextEditingController();
  final Map<String, Uint8List?> _photos = {};
  late final _km = TextEditingController(
    text: _remise ? '${task.initialKm ?? ''}' : '',
  );
  late int _fuel = _remise ? (task.initialFuel ?? 100) : 60;
  late final List<bool?> _check = List<bool?>.filled(
    checklistLabels.length,
    null,
  );
  final _anomalies = TextEditingController();
  final _fees = TextEditingController();
  bool _signed = false;
  bool _submitting = false;
  String? _doneRef;
  bool _doneOffline = false;

  @override
  void initState() {
    super.initState();
    _km.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _idNote.dispose();
    _km.dispose();
    _anomalies.dispose();
    _fees.dispose();
    super.dispose();
  }

  _Step get _step => _steps[_i];
  int get _kmValue => int.tryParse(_km.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
  int get _kmDiff => _kmValue - (task.initialKm ?? 0);
  int get _anomalyCount => _check.where((c) => c == false).length;

  bool get _canContinue => switch (_step) {
    _Step.dossier => true,
    _Step.client => _idChecked,
    _Step.vehicule => _plateOk && _docsOk,
    _Step.comparaison || _Step.checklist => _check.every((c) => c != null),
    _Step.photos => _photoSlots.every(_photos.containsKey),
    _Step.compteur => _kmValue > 0 && (_remise || _kmDiff >= 0),
    _Step.anomalies => true,
    _Step.signature => _signed,
    _Step.validation => true,
  };

  Future<void> _takePhoto(String slot) async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() => _photos[slot] = bytes);
    } catch (_) {
      // Pas d'appareil photo (émulateur, navigateur) : photo de démonstration.
      if (!kDemoMode) return;
      setState(() => _photos[slot] = null);
      if (mounted) {
        showProToast(
          context,
          'Appareil photo indisponible — photo de démonstration.',
        );
      }
    }
    haptic(HapticKind.tap);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final report = RentalReport(
      km: _kmValue,
      fuel: _fuel,
      checklist: _check,
      photos: _photos.keys.toSet(),
      notes: _anomalies.text,
      idNote: _idNote.text,
      feesEstimate: int.tryParse(_fees.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
      clientSigned: _signed,
    );
    final proof = await ref
        .read(businessProvider.notifier)
        .submit(task.id, report);
    if (!mounted) return;
    haptic(HapticKind.success);
    setState(() {
      _submitting = false;
      _doneRef = proof ?? 'en attente';
      _doneOffline = proof == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = ProRole.agentBusiness.accent;
    if (_doneRef != null) return _done(accent);
    final last = _i == _steps.length - 1;
    return PopScope(
      canPop: _i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _i--);
      },
      child: ProPage(
        title: '${task.type.label} du véhicule',
        subtitle: '${task.vehiclePlate} · ${task.ref}',
        bottom: Row(
          children: [
            if (_i > 0) ...[
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => setState(() => _i--),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: BigActionButton(
                height: 56,
                label: last
                    ? (_remise
                          ? 'Valider la remise'
                          : 'Clôturer la restitution')
                    : 'Continuer',
                icon: last
                    ? Icons.verified_rounded
                    : Icons.arrow_forward_rounded,
                color: last ? MoncarColors.success : accent,
                loading: _submitting,
                onPressed: !_canContinue
                    ? null
                    : last
                    ? () async {
                        final ok = await confirmAction(
                          context,
                          title: _remise
                              ? 'Valider la remise ?'
                              : 'Clôturer la restitution ?',
                          message: _remise
                              ? 'L’heure réelle de départ et la preuve de remise seront enregistrées par le serveur.'
                              : 'Le rapport final et les frais définitifs sont calculés par le serveur.',
                          confirmLabel: 'Valider',
                          icon: Icons.verified_rounded,
                          color: MoncarColors.success,
                        );
                        if (ok) await _submit();
                      }
                    : () {
                        haptic(HapticKind.tap);
                        setState(() => _i++);
                      },
              ),
            ),
          ],
        ),
        children: [
          _Stepper(steps: _steps, index: _i, accent: accent),
          const SizedBox(height: 16),
          ..._content(accent),
        ],
      ),
    );
  }

  List<Widget> _content(Color accent) {
    switch (_step) {
      case _Step.dossier:
        return [
          MoncarCard(
            child: Column(
              children: [
                DetailRow(
                  label: 'Dossier',
                  value: task.ref,
                  icon: Icons.tag_rounded,
                ),
                DetailRow(
                  label: 'Type',
                  value: task.type.label,
                  icon: Icons.swap_horiz_rounded,
                ),
                DetailRow(
                  label: 'Prévu à',
                  value: fmtTime(task.scheduledAt),
                  icon: Icons.schedule_rounded,
                ),
                DetailRow(
                  label: 'Client',
                  value: task.clientName,
                  icon: Icons.person_rounded,
                ),
                DetailRow(
                  label: 'Téléphone',
                  value: task.clientPhone,
                  icon: Icons.call_rounded,
                ),
                DetailRow(
                  label: 'Véhicule',
                  value: '${task.vehicleModel}\n${task.vehiclePlate}',
                  icon: Icons.directions_car_rounded,
                ),
                DetailRow(
                  label: 'Formule',
                  value: task.withDriver
                      ? 'Avec chauffeur (VTC)'
                      : 'Sans chauffeur',
                  icon: Icons.badge_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoBanner(
            icon: Icons.account_balance_rounded,
            message: _remise
                ? 'Le paiement du client est en séquestre MON CAR : la location devient active à la validation de cette remise.'
                : 'Le règlement du fournisseur interviendra après clôture de la restitution et traitement des éventuels frais.',
          ),
        ];
      case _Step.client:
        return [
          _Toggle(
            title: 'Pièce d’identité vérifiée',
            subtitle: task.withDriver
                ? 'Identité du client titulaire de la réservation.'
                : 'Pièce + permis de conduire en cours de validité.',
            value: _idChecked,
            onChanged: (v) => setState(() => _idChecked = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idNote,
            decoration: const InputDecoration(
              hintText: 'Type et n° de pièce (ex. CNI C00123456)',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            icon: Icons.privacy_tip_rounded,
            message:
                'Données personnelles : ne photographiez pas la pièce d’identité, seule la vérification est enregistrée.',
          ),
        ];
      case _Step.vehicule:
        return [
          HeroCard(
            colors: ProRole.agentBusiness.gradient,
            child: Row(
              children: [
                const Icon(Icons.directions_car_filled_rounded, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.vehiclePlate,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        task.vehicleModel,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Toggle(
            title: 'Plaque conforme au dossier',
            subtitle:
                'Immatriculation lue sur le véhicule : ${task.vehiclePlate}',
            value: _plateOk,
            onChanged: (v) => setState(() => _plateOk = v),
          ),
          const SizedBox(height: 10),
          _Toggle(
            title: _remise
                ? 'Carte grise et assurance à bord'
                : 'Clés et documents restitués',
            subtitle: _remise
                ? 'Documents présents et en cours de validité.'
                : 'Clés, carte grise et assurance remises à l’agent.',
            value: _docsOk,
            onChanged: (v) => setState(() => _docsOk = v),
          ),
        ];
      case _Step.photos:
        return [
          Text(
            _remise
                ? 'Photographiez le véhicule avant de remettre les clés.'
                : 'Photographiez l’état actuel pour comparaison avec la remise.',
            style: TextStyle(color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (final s in _photoSlots)
                _PhotoSlot(
                  label: s,
                  taken: _photos.containsKey(s),
                  bytes: _photos[s],
                  accent: accent,
                  onTap: () => _takePhoto(s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_photos.length}/${_photoSlots.length} photos · horodatées et stockées sur le serveur (S3).',
            style: TextStyle(fontSize: 12.5, color: MoncarColors.inkMut),
          ),
        ];
      case _Step.compteur:
        return [
          Text(
            _remise ? 'Kilométrage au départ' : 'Kilométrage au retour',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _km,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              suffixText: 'km',
              prefixIcon: Icon(Icons.speed_rounded),
            ),
          ),
          if (!_remise) ...[
            const SizedBox(height: 8),
            InfoBanner(
              icon: _kmDiff < 0
                  ? Icons.error_outline_rounded
                  : Icons.route_rounded,
              color: _kmDiff < 0 ? MoncarColors.danger : MoncarColors.info,
              message: _kmDiff < 0
                  ? 'Le kilométrage ne peut pas être inférieur à celui de la remise (${fmtInt(task.initialKm ?? 0)} km).'
                  : 'Remise : ${fmtInt(task.initialKm ?? 0)} km · parcourus : ${fmtInt(_kmDiff)} km',
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'Carburant',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: MoncarColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                '$_fuel %',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: accent,
                ),
              ),
            ],
          ),
          Slider(
            value: _fuel.toDouble(),
            max: 100,
            divisions: 8,
            activeColor: accent,
            label: '$_fuel %',
            onChanged: (v) => setState(() => _fuel = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in const ['Vide', '1/4', '1/2', '3/4', 'Plein'])
                Text(
                  l,
                  style: TextStyle(fontSize: 11.5, color: MoncarColors.inkMut),
                ),
            ],
          ),
          if (!_remise) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.local_gas_station_rounded,
              color: _fuel < (task.initialFuel ?? 100)
                  ? MoncarColors.warn
                  : MoncarColors.success,
              message:
                  'Remise : ${task.initialFuel ?? 100} % · écart : ${_fuel - (task.initialFuel ?? 100)} %',
            ),
          ],
        ];
      case _Step.checklist:
      case _Step.comparaison:
        final compare = _step == _Step.comparaison;
        return [
          if (compare)
            Text(
              'État enregistré à la remise à gauche ; vérifiez chaque point maintenant.',
              style: TextStyle(color: MoncarColors.inkMut),
            ),
          if (compare) const SizedBox(height: 10),
          for (var k = 0; k < checklistLabels.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MoncarCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    if (compare) ...[
                      Icon(
                        (task.initialChecklist?[k] ?? true)
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 18,
                        color: (task.initialChecklist?[k] ?? true)
                            ? MoncarColors.success
                            : MoncarColors.danger,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        checklistLabels[k],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.ink,
                        ),
                      ),
                    ),
                    _OkKo(
                      value: _check[k],
                      onChanged: (v) => setState(() => _check[k] = v),
                    ),
                  ],
                ),
              ),
            ),
          if (_anomalyCount > 0)
            InfoBanner(
              icon: Icons.report_problem_rounded,
              color: MoncarColors.danger,
              message:
                  '$_anomalyCount point(s) non conforme(s) — détaillez-les '
                  '${compare ? 'à l’étape « Anomalies »' : 'dans les observations'}.',
            ),
        ];
      case _Step.anomalies:
        return [
          TextField(
            controller: _anomalies,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Décrivez les anomalies constatées (rayure portière AR gauche…)',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Frais indicatifs',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fees,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '0',
              suffixText: 'FCFA',
              prefixIcon: Icon(Icons.receipt_long_rounded),
            ),
          ),
          const SizedBox(height: 10),
          const InfoBanner(
            icon: Icons.gavel_rounded,
            message:
                'Le montant définitif (motif, justificatif, validation) est fixé par le serveur. '
                'Un désaccord du client ouvre un dossier litige.',
          ),
        ];
      case _Step.signature:
        return [
          Text(
            _remise
                ? 'Le client confirme l’état du véhicule et la prise en charge.'
                : 'Le client confirme la restitution et l’état constaté.',
            style: TextStyle(color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 12),
          SignaturePad(onChanged: (v) => setState(() => _signed = v)),
        ];
      case _Step.validation:
        return [
          MoncarCard(
            child: Column(
              children: [
                DetailRow(label: 'Dossier', value: task.ref),
                DetailRow(label: 'Véhicule', value: task.vehiclePlate),
                DetailRow(
                  label: 'Photos',
                  value: '${_photos.length}/${_photoSlots.length}',
                ),
                DetailRow(
                  label: 'Kilométrage',
                  value: '${fmtInt(_kmValue)} km',
                ),
                if (!_remise)
                  DetailRow(
                    label: 'Km parcourus',
                    value: '${fmtInt(_kmDiff)} km',
                  ),
                DetailRow(label: 'Carburant', value: '$_fuel %'),
                DetailRow(
                  label: 'Anomalies',
                  value: _anomalyCount == 0 ? 'Aucune' : '$_anomalyCount',
                  valueColor: _anomalyCount == 0
                      ? MoncarColors.success
                      : MoncarColors.danger,
                ),
                if (!_remise && _fees.text.isNotEmpty)
                  DetailRow(
                    label: 'Frais indicatifs',
                    value: '${_fees.text} FCFA',
                  ),
                DetailRow(
                  label: 'Signature client',
                  value: _signed ? 'Recueillie' : 'Manquante',
                  valueColor: _signed
                      ? MoncarColors.success
                      : MoncarColors.danger,
                ),
                DetailRow(
                  label: 'Heure réelle',
                  value: fmtTime(DateTime.now()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!ref.watch(networkProvider).online)
            InfoBanner(
              icon: Icons.cloud_off_rounded,
              color: MoncarColors.warn,
              message:
                  'Hors ligne : le relevé est conservé et la preuve sera générée à la synchronisation.',
            ),
        ];
    }
  }

  Widget _done(Color accent) {
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color:
                      (_doneOffline ? MoncarColors.warn : MoncarColors.success)
                          .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _doneOffline
                      ? Icons.cloud_upload_rounded
                      : Icons.verified_rounded,
                  size: 60,
                  color: _doneOffline
                      ? MoncarColors.warn
                      : MoncarColors.success,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _remise ? 'Remise validée' : 'Restitution clôturée',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: MoncarColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _doneOffline
                    ? 'Relevé enregistré hors ligne. La preuve sera générée à la synchronisation.'
                    : _remise
                    ? 'Location active. Preuve de remise générée par le serveur :'
                    : 'Rapport final généré par le serveur :',
                textAlign: TextAlign.center,
                style: TextStyle(color: MoncarColors.inkMut, height: 1.4),
              ),
              if (!_doneOffline) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _doneRef!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              BigActionButton(
                label: 'Retour aux missions',
                icon: Icons.car_rental_rounded,
                color: accent,
                onPressed: () => context.go('/biz/missions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.steps,
    required this.index,
    required this.accent,
  });

  final List<_Step> steps;
  final int index;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = steps[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(s.icon, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MoncarColors.ink,
                ),
              ),
            ),
            Text(
              'Étape ${index + 1}/${steps.length}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: MoncarColors.inkMut,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var k = 0; k < steps.length; k++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: k < index
                        ? MoncarColors.success
                        : k == index
                        ? accent
                        : MoncarColors.hairline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (k < steps.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: (v) {
            haptic(HapticKind.tap);
            onChanged(v);
          },
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}

class _OkKo extends StatelessWidget {
  const _OkKo({required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(bool v, String label, Color c) {
      final active = value == v;
      return GestureDetector(
        onTap: () {
          haptic(HapticKind.tap);
          onChanged(v);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 50,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active ? c : MoncarColors.hairline,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : MoncarColors.inkMut,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(true, 'OK', MoncarColors.success),
        const SizedBox(width: 6),
        btn(false, 'KO', MoncarColors.danger),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.taken,
    required this.bytes,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool taken;
  final Uint8List? bytes;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: taken ? accent.withValues(alpha: 0.08) : MoncarColors.muted,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null) Image.memory(bytes!, fit: BoxFit.cover),
            if (bytes == null)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    taken ? Icons.image_rounded : Icons.add_a_photo_rounded,
                    color: taken ? accent : MoncarColors.inkMut,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: taken ? accent : MoncarColors.inkMut,
                    ),
                  ),
                ],
              ),
            if (taken)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: MoncarColors.success,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            if (bytes != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black45,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
