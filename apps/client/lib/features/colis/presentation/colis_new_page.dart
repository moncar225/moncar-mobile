import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';

class _Draft {
  String senderName = '';
  String senderPhone = '';
  String recipientName = '';
  String recipientPhone = '';
  String originCity = 'Abidjan';
  String destinationCity = 'Yamoussoukro';
  String originStop = "Gare d'Adjamé";
  String destinationStop = 'Gare centrale Yam';
  String weightKg = '1';
  String dimensions = '30x20x15';
  String description = '';
  bool payeeIsSender = true;
}

const _steps = [
  (label: 'Expéditeur', icon: Icons.person_outline),
  (label: 'Destinataire', icon: Icons.person_outline),
  (label: 'Trajet', icon: Icons.place_outlined),
  (label: 'Colis', icon: Icons.inventory_2_outlined),
  (label: 'Tarif', icon: Icons.account_balance_wallet_outlined),
];

/// Envoi de colis en 5 étapes. Invariant contractuel : le tarif est
/// calculé par le serveur (createParcel) à l'entrée de l'étape 5 —
/// jamais recalculé côté client.
class ColisNewPage extends ConsumerStatefulWidget {
  const ColisNewPage({super.key});

  @override
  ConsumerState<ColisNewPage> createState() => _ColisNewPageState();
}

class _ColisNewPageState extends ConsumerState<ColisNewPage> {
  final _d = _Draft();
  int _step = 1;
  Parcel? _created;
  bool _confirmed = false;
  bool _creating = false;
  String? _submitError;

  late final _senderName = TextEditingController(text: _d.senderName);
  late final _senderPhone = TextEditingController(text: _d.senderPhone);
  late final _recipientName = TextEditingController();
  late final _recipientPhone = TextEditingController();
  late final _originStop = TextEditingController(text: _d.originStop);
  late final _destinationStop = TextEditingController(text: _d.destinationStop);
  late final _weight = TextEditingController(text: _d.weightKg);
  late final _dimensions = TextEditingController(text: _d.dimensions);
  late final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _d.senderName = '${user.firstName} ${user.lastName}';
      _d.senderPhone = user.phone;
      _senderName.text = _d.senderName;
      _senderPhone.text = _d.senderPhone;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _senderName,
      _senderPhone,
      _recipientName,
      _recipientPhone,
      _originStop,
      _destinationStop,
      _weight,
      _dimensions,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(int s) {
    switch (s) {
      case 1:
        if (_d.senderName.trim().isEmpty) {
          return "Le nom de l'expéditeur est requis.";
        }
        if (_d.senderPhone.trim().isEmpty) {
          return "Le téléphone de l'expéditeur est requis.";
        }
      case 2:
        if (_d.recipientName.trim().isEmpty) {
          return 'Le nom du destinataire est requis.';
        }
        if (_d.recipientPhone.trim().isEmpty) {
          return 'Le téléphone du destinataire est requis.';
        }
      case 3:
        if (_d.originCity.isEmpty) return 'Ville de départ requise.';
        if (_d.destinationCity.isEmpty) return "Ville d'arrivée requise.";
        if (_d.originCity == _d.destinationCity) {
          return "Les villes de départ et d'arrivée doivent être différentes.";
        }
        if (_d.originStop.trim().isEmpty || _d.destinationStop.trim().isEmpty) {
          return 'Veuillez indiquer les gares de dépôt et de retrait.';
        }
      case 4:
        final w = double.tryParse(_d.weightKg.replaceAll(',', '.')) ?? 0;
        if (w <= 0) return 'Poids invalide (kg).';
        if (_d.dimensions.trim().isEmpty) {
          return 'Les dimensions sont requises.';
        }
    }
    return null;
  }

  Future<void> _createQuote() async {
    setState(() {
      _creating = true;
      _submitError = null;
    });
    // ⚠️ MOCK : POST /parcels (latence simulée).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final w = double.tryParse(_d.weightKg.replaceAll(',', '.')) ?? 1;
    final r = ref
        .read(mockStoreProvider)
        .createParcel(
          senderName: _d.senderName.trim(),
          senderPhone: _d.senderPhone.trim(),
          recipientName: _d.recipientName.trim(),
          recipientPhone: _d.recipientPhone.trim(),
          originCity: _d.originCity,
          destinationCity: _d.destinationCity,
          originStop: _d.originStop.trim().isEmpty
              ? "Gare d'Adjamé"
              : _d.originStop.trim(),
          destinationStop: _d.destinationStop.trim().isEmpty
              ? 'Gare centrale'
              : _d.destinationStop.trim(),
          weightKg: w < 0.5 ? 0.5 : w,
          dimensions: _d.dimensions.trim().isEmpty
              ? '30x20x15'
              : _d.dimensions.trim(),
          description: _d.description.trim(),
          payeeIsSender: _d.payeeIsSender,
        );
    setState(() {
      _creating = false;
      _created = r.parcel;
      _submitError = r.ok
          ? null
          : (r.error ?? 'Échec de la création du colis.');
    });
    if (!r.ok) showMoncarToast(context, _submitError!, error: true);
  }

  void _next() {
    final err = _validate(_step);
    if (err != null) {
      showMoncarToast(context, err, error: true);
      return;
    }
    if (_step == 4) {
      if (_created == null) _createQuote();
      setState(() => _step = 5);
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    if (_step == 1) {
      context.mcBack();
      return;
    }
    setState(() {
      // Quitter l'étape 5 invalide le devis serveur.
      if (_step == 5) {
        _created = null;
        _submitError = null;
      }
      _step -= 1;
    });
  }

  void _confirm() {
    if (_created == null) {
      showMoncarToast(
        context,
        'Tarif non disponible. Veuillez réessayer.',
        error: true,
      );
      return;
    }
    setState(() => _confirmed = true);
    showMoncarToast(
      context,
      'Colis confirmé. Suivez votre envoi en temps réel.',
      success: true,
    );
  }

  Future<void> _pickCity({required bool origin}) async {
    final city = await CityPicker.show(
      context,
      title: origin ? 'Ville de départ' : "Ville d'arrivée",
      selectedName: origin ? _d.originCity : _d.destinationCity,
      excludeCity: origin ? null : _d.originCity,
    );
    if (city == null) return;
    setState(
      () => origin ? _d.originCity = city.name : _d.destinationCity = city.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    if (_confirmed && created != null) {
      return Scaffold(
        backgroundColor: MoncarColors.background,
        appBar: const TopBar(
          title: 'Colis envoyé',
          showBack: true,
          showBell: false,
        ),
        body: MoncarSuccessState(
          title: 'Colis envoyé !',
          message:
              'Votre colis ${created.trackingNumber} a été enregistré. Suivez-le en temps réel.',
          actionLabel: 'Suivre ce colis',
          onAction: () => context.pushReplacement('/colis/${created.id}'),
          secondaryLabel: 'Retour à mes colis',
          onSecondary: () => context.go('/colis'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Envoyer un colis',
        showBack: true,
        showBell: false,
        onBack: _back,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _StepBar(step: _step),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
          ),
        ],
      ),
      bottomNavigationBar: StickyBottomBar(
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: 'Retour',
                onPressed: _back,
                icon: Icon(Icons.arrow_back, color: MoncarColors.brand),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _step < 5
                  ? MoncarButton(
                      label: 'Continuer',
                      icon: Icons.chevron_right,
                      variant: MoncarButtonVariant.primary,
                      size: MoncarButtonSize.xl,
                      expand: true,
                      onPressed: _next,
                    )
                  : MoncarButton(
                      label: 'Confirmer et payer',
                      icon: Icons.account_balance_wallet_outlined,
                      variant: MoncarButtonVariant.primary,
                      size: MoncarButtonSize.xl,
                      expand: true,
                      isLoading: _creating,
                      onPressed: created == null ? null : _confirm,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _StepCard(
          title: 'Expéditeur',
          subtitle: "Vos informations (l'envoyeur)",
          children: [
            MoncarTextField(
              label: 'Nom complet',
              controller: _senderName,
              hint: 'Kouadio Yavo',
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _d.senderName = v,
            ),
            MoncarTextField(
              label: 'Téléphone',
              controller: _senderPhone,
              hint: '+225 07 00 11 22 33',
              keyboardType: TextInputType.phone,
              onChanged: (v) => _d.senderPhone = v,
            ),
            const _Hint(
              "Renseignez le numéro Mobile Money du payeur si l'expéditeur paye.",
            ),
          ],
        );
      case 2:
        return _StepCard(
          title: 'Destinataire',
          subtitle: 'La personne qui recevra le colis',
          children: [
            MoncarTextField(
              label: 'Nom complet',
              controller: _recipientName,
              hint: 'Adjoa Koné',
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _d.recipientName = v,
            ),
            MoncarTextField(
              label: 'Téléphone',
              controller: _recipientPhone,
              hint: '+225 05 44 55 66 77',
              keyboardType: TextInputType.phone,
              onChanged: (v) => _d.recipientPhone = v,
            ),
            const _Hint(
              'Le destinataire recevra un SMS de notification à chaque étape.',
            ),
          ],
        );
      case 3:
        return _StepCard(
          title: 'Trajet',
          subtitle: 'Ville de dépôt et de retrait',
          children: [
            _CityField(
              label: 'Ville de départ',
              value: _d.originCity,
              onTap: () => _pickCity(origin: true),
            ),
            MoncarTextField(
              label: 'Gare de dépôt',
              controller: _originStop,
              hint: "Gare d'Adjamé",
              onChanged: (v) => _d.originStop = v,
            ),
            _CityField(
              label: "Ville d'arrivée",
              value: _d.destinationCity,
              onTap: () => _pickCity(origin: false),
            ),
            MoncarTextField(
              label: 'Gare de retrait',
              controller: _destinationStop,
              hint: 'Gare centrale Yam',
              onChanged: (v) => _d.destinationStop = v,
            ),
          ],
        );
      case 4:
        return _StepCard(
          title: 'Caractéristiques du colis',
          subtitle: 'Poids, dimensions et contenu',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoncarTextField(
                    label: 'Poids (kg)',
                    controller: _weight,
                    hint: '1',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    onChanged: (v) => _d.weightKg = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MoncarTextField(
                    label: 'Dimensions (cm)',
                    controller: _dimensions,
                    hint: '30x20x15',
                    onChanged: (v) => _d.dimensions = v,
                  ),
                ),
              ],
            ),
            MoncarTextField(
              label: 'Description du contenu',
              controller: _description,
              hint: 'Colis alimentaire, vêtements, documents…',
              maxLines: 3,
              onChanged: (v) => _d.description = v,
            ),
            const MoncarLabel('Qui paie les frais ?'),
            Row(
              children: [
                Expanded(
                  child: _PayeeOption(
                    label: 'Expéditeur',
                    desc: "Paie à l'envoi",
                    active: _d.payeeIsSender,
                    onTap: () => setState(() => _d.payeeIsSender = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PayeeOption(
                    label: 'Destinataire',
                    desc: 'Paie au retrait',
                    active: !_d.payeeIsSender,
                    onTap: () => setState(() => _d.payeeIsSender = false),
                  ),
                ),
              ],
            ),
            const _Hint(
              "Le colis est accepté sous réserve d'inspection à la gare de dépôt.",
            ),
          ],
        );
      default:
        return _buildRecap();
    }
  }

  Widget _buildRecap() {
    final created = _created;
    return Column(
      children: [
        MoncarCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_outlined,
                    size: 20,
                    color: MoncarColors.accent,
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Récapitulatif',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                        ),
                      ),
                      Text(
                        'Vérifiez avant de confirmer',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RecapItem(
                icon: Icons.person_outline,
                label: 'Expéditeur',
                value: '${_d.senderName} • ${_d.senderPhone}',
              ),
              _RecapItem(
                icon: Icons.person_outline,
                label: 'Destinataire',
                value: '${_d.recipientName} • ${_d.recipientPhone}',
              ),
              _RecapItem(
                icon: Icons.place_outlined,
                label: 'Trajet',
                value: '${_d.originCity} → ${_d.destinationCity}',
                sub: '${_d.originStop} → ${_d.destinationStop}',
              ),
              _RecapItem(
                icon: Icons.scale_outlined,
                label: 'Poids',
                value: '${_d.weightKg} kg',
              ),
              _RecapItem(
                icon: Icons.straighten,
                label: 'Dimensions',
                value: _d.dimensions,
              ),
              if (_d.description.isNotEmpty)
                _RecapItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Contenu',
                  value: _d.description,
                ),
              _RecapItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Payeur',
                value: _d.payeeIsSender
                    ? "Expéditeur (à l'envoi)"
                    : 'Destinataire (au retrait)',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MoncarCard(
          padding: const EdgeInsets.all(20),
          color: MoncarColors.brandSoft.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: MoncarColors.brand,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Tarif calculé',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Spacer(),
                  MoncarBadge(label: 'Serveur', size: MoncarBadgeSize.sm),
                ],
              ),
              const SizedBox(height: 12),
              if (_creating)
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoncarSkeleton(width: 160, height: 32),
                    SizedBox(height: 8),
                    MoncarSkeleton(height: 12),
                  ],
                )
              else if (created == null)
                MoncarInlineError(
                  message:
                      _submitError ?? 'Tarif indisponible. Veuillez réessayer.',
                  onRetry: _createQuote,
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OverlineText('Montant à payer'),
                        const SizedBox(height: 4),
                        Text(
                          formatXOF(created.amountXOF),
                          style: TextStyle(
                            fontSize: 28,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.brand,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(
                      Icons.send_outlined,
                      size: 28,
                      color: MoncarColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: MoncarColors.hairline),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Numéro de suivi attribué',
                      style: TextStyle(
                        fontSize: 12,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      created.trackingNumber,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tarif calculé par le serveur MON CAR (base + prix au kg). '
                  "Le montant ne sera confirmé qu'après paiement.",
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Builder(
            builder: (context) {
              final n = i + 1;
              final done = step > n;
              final active = step == n;
              final color = active
                  ? MoncarColors.accent
                  : done
                  ? MoncarColors.success
                  : MoncarColors.inkFaint;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: active
                        ? accentGradientDecoration().copyWith(
                            shape: BoxShape.circle,
                          )
                        : BoxDecoration(
                            shape: BoxShape.circle,
                            color: done
                                ? MoncarColors.success
                                : MoncarColors.muted,
                          ),
                    child: Icon(
                      done ? Icons.check : _steps[i].icon,
                      size: 16,
                      color: active || done
                          ? Colors.white
                          : MoncarColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _steps[i].label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              );
            },
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 17, left: 2, right: 2),
                decoration: BoxDecoration(
                  color: step > i + 1
                      ? MoncarColors.success
                      : MoncarColors.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MoncarColors.ink,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
            ),
          const SizedBox(height: 16),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MoncarColors.brandSoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
      ),
    );
  }
}

class _CityField extends StatelessWidget {
  const _CityField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MoncarLabel(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: MoncarColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MoncarColors.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: MoncarColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: MoncarColors.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PayeeOption extends StatelessWidget {
  const _PayeeOption({
    required this.label,
    required this.desc,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String desc;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? MoncarColors.accentSoft : MoncarColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? MoncarColors.accent : MoncarColors.hairline,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? MoncarColors.accent
                            : MoncarColors.inkFaint,
                        width: 2,
                      ),
                    ),
                    child: active
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: MoncarColors.accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? MoncarColors.accentInk : MoncarColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapItem extends StatelessWidget {
  const _RecapItem({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: MoncarColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverlineText(label),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
