import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/foundation.dart';
import '../widgets/location_widgets.dart';

/// État initial et validation client (§42) : photos (plaque, carte
/// grise, faces, intérieur, tableau de bord), kilométrage, carburant,
/// dommages déjà présents, puis VÉHICULE CONFORME ou SIGNALER UNE
/// ANOMALIE. Crée la preuve numérique de l'état au début de la location.
class RentalConditionPage extends ConsumerStatefulWidget {
  const RentalConditionPage({super.key, required this.rentalId});

  final String rentalId;

  @override
  ConsumerState<RentalConditionPage> createState() =>
      _RentalConditionPageState();
}

class _RentalConditionPageState extends ConsumerState<RentalConditionPage> {
  final Map<String, Uint8List> _photos = {};
  final _mileage = TextEditingController();
  final _damages = TextEditingController();
  int _fuel = 8;
  bool _submitted = false;
  bool _saving = false;

  @override
  void dispose() {
    _mileage.dispose();
    _damages.dispose();
    super.dispose();
  }

  int get _km => int.tryParse(_mileage.text.replaceAll(' ', '')) ?? 0;

  Future<void> _shoot(String slot) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photos[slot] = bytes);
    } on PlatformException {
      if (!mounted) return;
      showMoncarToast(
        context,
        "Impossible d'ouvrir l'appareil photo. Vérifiez l'autorisation.",
        error: true,
      );
    }
  }

  Future<void> _submit({required bool conforme}) async {
    setState(() => _submitted = true);
    if (_km <= 0) {
      showMoncarToast(context, 'Indiquez le kilométrage.', error: true);
      return;
    }
    var anomaly = '';
    if (!conforme) {
      final text = await _askAnomaly();
      if (text == null || !mounted) return;
      anomaly = text;
    }
    setState(() => _saving = true);
    // ⚠️ MOCK : POST /rentals/:id/start-condition (latence simulée).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final r = ref
        .read(mockStoreProvider)
        .submitStartCondition(
          widget.rentalId,
          VehicleCondition(
            recordedAt: DateTime.now().toIso8601String(),
            mileageKm: _km,
            fuelEighths: _fuel,
            photos: _photos.keys.toList(),
            damages: _damages.text.trim(),
            conforme: conforme,
            anomaly: anomaly,
          ),
        );
    setState(() => _saving = false);
    if (!r.ok) {
      showMoncarToast(
        context,
        r.error ?? 'Enregistrement impossible.',
        error: true,
      );
      return;
    }
    showMoncarToast(
      context,
      conforme
          ? 'Véhicule conforme — votre location est active'
          : 'Anomalie enregistrée — votre location est active',
      success: true,
    );
    context.pop();
  }

  Future<String?> _askAnomaly() async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Signaler une anomalie'),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLines: 4,
            onChanged: (_) => setLocal(() {}),
            decoration: const InputDecoration(
              hintText: 'Ex. rayure portière avant droite, pneu usé…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: c.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(context, c.text.trim()),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final rental = ref.watch(mockStoreProvider).findRental(widget.rentalId);
    if (rental == null || rental.status != RentalStatus.remise) {
      return Scaffold(
        appBar: const TopBar(title: 'État des lieux', showBack: true),
        body: MoncarEmptyState(
          icon: Icons.fact_check_outlined,
          title: 'État des lieux indisponible',
          message:
              "Le véhicule n'a pas encore été remis, ou l'état a déjà été enregistré.",
          actionLabel: 'Retour',
          onAction: () => context.mcBack(),
        ),
      );
    }
    final kmError = _submitted && _km <= 0 ? 'Kilométrage obligatoire.' : null;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'État des lieux',
        subtitle: rental.vehicleSummary,
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Ces photos et relevés constituent la preuve de l\'état du véhicule '
              'au début de la location. Ils seront comparés à l\'état au retour.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: MoncarColors.inkMut,
              ),
            ),
          ),
          const SizedBox(height: 16),
          MoncarSectionHeader(
            title: 'Photos (${_photos.length}/${rentalPhotoSlots.length})',
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: [
              for (final (slot, label) in rentalPhotoSlots)
                _PhotoSlot(
                  label: label,
                  bytes: _photos[slot],
                  onTap: () => _shoot(slot),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Relevés'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoncarTextField(
                  label: 'Kilométrage au compteur',
                  controller: _mileage,
                  hint: 'ex. 48210',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.speed,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 7,
                  error: kmError,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Niveau de carburant',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ),
                    FuelGauge(eighths: _fuel),
                  ],
                ),
                Slider(
                  value: _fuel.toDouble(),
                  min: 0,
                  max: 8,
                  divisions: 8,
                  label: '$_fuel/8',
                  activeColor: MoncarColors.brand,
                  onChanged: (v) => setState(() => _fuel = v.round()),
                ),
                MoncarTextField(
                  label: 'Dommages déjà présents',
                  controller: _damages,
                  hint: 'Ex. rayure pare-choc arrière (facultatif)',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MoncarButton(
              label: 'Véhicule conforme',
              icon: Icons.check_circle_outline,
              variant: MoncarButtonVariant.success,
              size: MoncarButtonSize.lg,
              expand: true,
              isLoading: _saving,
              onPressed: _saving ? null : () => _submit(conforme: true),
            ),
            const SizedBox(height: 8),
            MoncarButton(
              label: 'Signaler une anomalie',
              icon: Icons.warning_amber_rounded,
              variant: MoncarButtonVariant.outline,
              size: MoncarButtonSize.md,
              expand: true,
              onPressed: _saving ? null : () => _submit(conforme: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.bytes,
    required this.onTap,
  });

  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taken = bytes != null;
    return Semantics(
      button: true,
      label: 'Photo $label${taken ? ', prise' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: MoncarColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: taken ? MoncarColors.success : MoncarColors.hairline,
                    width: taken ? 2 : 1,
                  ),
                ),
                child: taken
                    ? Image.memory(bytes!, fit: BoxFit.cover)
                    : Icon(
                        Icons.add_a_photo_outlined,
                        size: 22,
                        color: MoncarColors.inkFaint,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: taken ? FontWeight.w700 : FontWeight.w500,
                color: taken ? MoncarColors.success : MoncarColors.inkMut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
