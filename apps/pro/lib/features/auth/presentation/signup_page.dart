import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/pro_api.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/role_card.dart';

const _stepNames = [
  'Poste',
  'Identité',
  'Rattachement',
  'Sécurité',
  'Confirmation',
];

/// Inscription agent en 5 étapes (même parcours que l'app client) :
/// **choix du poste**, identité, rattachement (compagnie + gare, ou
/// agence de location), numéro + mot de passe, confirmation → code SMS.
///
/// ⚠ Le CDC prévoit des comptes créés par la compagnie : l'inscription
/// est donc une demande rattachée à une structure, que la compagnie
/// valide côté serveur (en démonstration : validation immédiate).
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  int _step = 1;
  ProRole? _role;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _matricule = TextEditingController();
  final _email = TextEditingController();
  Structure? _structure;
  String? _site;
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acceptCgu = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _password,
      _confirm,
    ]) {
      c.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _matricule,
      _email,
      _phone,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isBusiness => _role == ProRole.agentBusiness;
  List<Structure> get _structures =>
      _isBusiness ? businessStructures : transportCompanies;

  bool get _emailOk {
    final e = _email.text.trim();
    return e.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  bool get _stepValid => switch (_step) {
    1 => _role != null,
    2 =>
      _firstName.text.trim().length >= 2 &&
          _lastName.text.trim().length >= 2 &&
          _emailOk,
    3 => _structure != null && _site != null,
    4 =>
      phoneDigits(_phone.text).length == 10 &&
          isPasswordValid(_password.text) &&
          _password.text == _confirm.text,
    _ => _acceptCgu,
  };

  void _next() {
    if (!_stepValid) return;
    FocusScope.of(context).unfocus();
    haptic(HapticKind.tap);
    setState(() => _step++);
  }

  void _prev() {
    if (_step == 1) {
      context.canPop() ? context.pop() : context.go('/login');
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_stepValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final phone = phoneDigits(_phone.text);
    try {
      await ref
          .read(proApiProvider)
          .register(
            SignupRequest(
              role: _role!,
              firstName: _firstName.text,
              lastName: _lastName.text,
              phone: phone,
              email: _email.text.trim(),
              company: _structure!.name,
              station: _site!,
              matricule: _matricule.text.trim(),
              password: _password.text,
            ),
          );
      if (!mounted) return;
      ref.read(pendingAuthProvider.notifier).start(OtpPurpose.signup, phone);
      context.push('/otp');
    } on ProApiException catch (e) {
      haptic(HapticKind.error);
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _role?.accent ?? MoncarColors.accent;
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prev();
      },
      child: Scaffold(
        backgroundColor: MoncarColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ProHeader(title: 'Inscription', onBack: _prev),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    const Center(child: ProLogo(size: 52)),
                    const SizedBox(height: 10),
                    Text(
                      'Créer votre compte agent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MoncarColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rejoignez l’équipe terrain en quelques minutes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'ÉTAPE $_step / ${_stepNames.length}',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _stepNames[_step - 1],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StepProgress(current: _step, total: _stepNames.length),
                    const SizedBox(height: 18),
                    if (_error != null) ...[
                      AuthErrorBanner(_error!),
                      const SizedBox(height: 12),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          1 => _stepRole(),
                          2 => _stepIdentity(),
                          3 => _stepStructure(),
                          4 => _stepSecurity(),
                          _ => _stepRecap(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
              StickyActionBar(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_step < _stepNames.length)
                      MoncarButton(
                        label: 'Continuer',
                        icon: Icons.arrow_forward,
                        variant: MoncarButtonVariant.primary,
                        size: MoncarButtonSize.xl,
                        expand: true,
                        onPressed: _stepValid ? _next : null,
                      )
                    else
                      MoncarButton(
                        label: 'Créer mon compte',
                        icon: Icons.arrow_forward,
                        variant: MoncarButtonVariant.primary,
                        size: MoncarButtonSize.xl,
                        expand: true,
                        isLoading: _submitting,
                        onPressed: _stepValid ? _submit : null,
                      ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Déjà un compte ? Se connecter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------- Étapes -----------------------------

  Widget _stepRole() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const StepHeader(
        index: 1,
        title: 'Choisissez votre poste',
        subtitle:
            'Votre poste détermine les écrans et les droits de votre compte. '
            'Seule votre compagnie peut en ajouter d’autres ensuite.',
      ),
      for (final r in ProRole.values) ...[
        RoleCard(
          role: r,
          selected: _role == r,
          onTap: () {
            haptic(HapticKind.tap);
            setState(() {
              if (_role != null &&
                  (_role == ProRole.agentBusiness) !=
                      (r == ProRole.agentBusiness)) {
                // Changement transport ↔ location : rattachement à refaire.
                _structure = null;
                _site = null;
              }
              _role = r;
            });
          },
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _stepIdentity() => MoncarCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepHeader(
          index: 2,
          title: 'Votre identité',
          subtitle:
              'Nom affiché sur les manifestes et dans le journal des actions.',
        ),
        const FieldLabel('Prénom'),
        TextField(
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          decoration: const InputDecoration(hintText: 'ex. Aminata'),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Nom'),
        TextField(
          controller: _lastName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.familyName],
          decoration: const InputDecoration(hintText: 'ex. Koné'),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Matricule (facultatif)'),
        TextField(
          controller: _matricule,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Fourni par votre compagnie',
          ),
        ),
        const SizedBox(height: 14),
        const FieldLabel('E-mail (facultatif)'),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            hintText: 'nom@exemple.ci',
            errorText: _emailOk ? null : 'Adresse e-mail invalide',
          ),
        ),
      ],
    ),
  );

  Widget _stepStructure() {
    final accent = _role!.accent;
    return MoncarCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(
            index: 3,
            title: _isBusiness ? 'Votre agence de location' : 'Votre compagnie',
            subtitle: _isBusiness
                ? 'Vos missions de remise et de restitution viennent de cette agence.'
                : 'Vos voyages et manifestes sont ceux de votre gare de rattachement.',
          ),
          FieldLabel(_isBusiness ? 'Structure' : 'Compagnie'),
          for (final s in _structures) ...[
            _ChoiceTile(
              label: s.name,
              icon: _isBusiness
                  ? Icons.car_rental_rounded
                  : Icons.directions_bus_rounded,
              selected: _structure == s,
              accent: accent,
              onTap: () => setState(() {
                _structure = s;
                _site = null;
              }),
            ),
            const SizedBox(height: 8),
          ],
          if (_structure != null) ...[
            const SizedBox(height: 8),
            FieldLabel(_isBusiness ? 'Agence' : 'Gare de rattachement'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final site in _structure!.sites)
                  ChoiceChip(
                    label: Text(site),
                    selected: _site == site,
                    selectedColor: accent,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _site == site ? Colors.white : MoncarColors.ink,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _site = site),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepSecurity() => MoncarCard(
    padding: const EdgeInsets.all(18),
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepHeader(
            index: 4,
            title: 'Sécurisez votre compte',
            subtitle:
                'Votre numéro sert d’identifiant ; il sera vérifié par SMS.',
          ),
          const FieldLabel('Numéro de téléphone'),
          PhoneField(controller: _phone, textInputAction: TextInputAction.next),
          const SizedBox(height: 14),
          const FieldLabel('Mot de passe'),
          PasswordField(
            controller: _password,
            hint: 'Créez un mot de passe',
            isNew: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirm,
            hint: 'Confirmez le mot de passe',
            isNew: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          PasswordChecklist(password: _password.text, confirm: _confirm.text),
        ],
      ),
    ),
  );

  Widget _stepRecap() {
    final role = _role!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoncarCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const StepHeader(
                index: 5,
                title: 'Vérifiez vos informations',
                subtitle: 'Un code SMS confirmera votre numéro.',
              ),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: role.gradient),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(role.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_firstName.text.trim()} ${_lastName.text.trim()}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.ink,
                          ),
                        ),
                        Text(
                          role.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: role.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('Modifier'),
                  ),
                ],
              ),
              const Divider(height: 24),
              DetailRow(
                label: 'Téléphone',
                value: formatCiPhone(phoneDigits(_phone.text)),
                icon: Icons.phone_iphone_rounded,
              ),
              if (_email.text.trim().isNotEmpty)
                DetailRow(
                  label: 'E-mail',
                  value: _email.text.trim(),
                  icon: Icons.mail_rounded,
                ),
              DetailRow(
                label: _isBusiness ? 'Structure' : 'Compagnie',
                value: _structure!.name,
                icon: Icons.business_rounded,
              ),
              DetailRow(
                label: _isBusiness ? 'Agence' : 'Gare',
                value: _site!,
                icon: Icons.place_rounded,
              ),
              if (_matricule.text.trim().isNotEmpty)
                DetailRow(
                  label: 'Matricule',
                  value: _matricule.text.trim(),
                  icon: Icons.badge_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          icon: Icons.verified_user_rounded,
          message:
              'Votre compte est rattaché à ${_structure!.name}, qui valide vos accès '
              'et peut les modifier. Toutes vos actions sont journalisées.',
        ),
        const SizedBox(height: 12),
        MoncarCard(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _acceptCgu,
              onChanged: (v) => setState(() => _acceptCgu = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'J’accepte les Conditions d’utilisation et la Politique de '
                'confidentialité de MON CAR PRO.',
                style: TextStyle(fontSize: 13.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.08) : MoncarColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? accent : MoncarColors.hairline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          haptic(HapticKind.tap);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: selected ? accent : MoncarColors.inkMut),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? accent : MoncarColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
