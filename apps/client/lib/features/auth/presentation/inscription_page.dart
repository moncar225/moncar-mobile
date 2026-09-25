import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../application/auth_flow.dart';
import '../application/phone_auth.dart';
import '../widgets/auth_widgets.dart';

final _nameRe = RegExp(r"^[A-Za-zÀ-ÿ' -]{2,40}$");
// Mobile CI : 10 chiffres commençant par 0 (07/05/01/27…).
final _ciPhoneRe = RegExp(r'^0\d{9}$');
final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

class _Form {
  String firstName = '';
  String lastName = '';
  String phone = ''; // 10 chiffres locaux
  String email = '';
  String password = '';
  String passwordConfirm = '';
  String city = 'Abidjan';
  bool acceptCgu = false;
  bool optinPromos = false;
}

Map<String, String> _validateStep(int step, _Form f) {
  final e = <String, String>{};
  if (step == 1) {
    if (f.firstName.trim().isEmpty) {
      e['firstName'] = 'Le prénom est requis.';
    } else if (!_nameRe.hasMatch(f.firstName.trim())) {
      e['firstName'] = 'Au moins 2 caractères.';
    }
    if (f.lastName.trim().isEmpty) {
      e['lastName'] = 'Le nom est requis.';
    } else if (!_nameRe.hasMatch(f.lastName.trim())) {
      e['lastName'] = 'Au moins 2 caractères.';
    }
  }
  if (step == 2) {
    if (!_ciPhoneRe.hasMatch(f.phone)) {
      e['phone'] =
          'Entrez un numéro ivoirien à 10 chiffres (ex. 07 00 11 22 33).';
    }
    if (f.email.trim().isNotEmpty && !_emailRe.hasMatch(f.email.trim())) {
      e['email'] = 'Adresse e-mail invalide.';
    }
  }
  if (step == 3) {
    if (!isPasswordValid(f.password)) {
      e['password'] = 'Le mot de passe ne respecte pas les règles ci-dessous.';
    }
    if (f.passwordConfirm != f.password) {
      e['passwordConfirm'] = 'Les mots de passe ne correspondent pas.';
    }
  }
  if (step == 4) {
    if (f.city.trim().isEmpty) e['city'] = 'Choisissez votre ville.';
    if (!f.acceptCgu) {
      e['acceptCgu'] = 'Vous devez accepter les conditions pour continuer.';
    }
  }
  return e;
}

String _formatPhonePreview(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  final buf = StringBuffer();
  for (var i = 0; i < d.length && i < 10; i++) {
    if (i > 0 && i.isEven) buf.write(' ');
    buf.write(d[i]);
  }
  return buf.toString();
}

/// Inscription en 5 étapes : identité, contact, mot de passe,
/// ville + CGU, récapitulatif. Le numéro est ensuite vérifié par OTP
/// SMS, puis le mot de passe est rattaché au compte.
class InscriptionPage extends ConsumerStatefulWidget {
  const InscriptionPage({super.key});

  @override
  ConsumerState<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends ConsumerState<InscriptionPage> {
  final _form = _Form();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  int _step = 1;
  Map<String, String> _errors = {};
  final Set<String> _touched = {};
  bool _submitting = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  void _changed(String key) {
    setState(() {
      if (_touched.contains(key)) _errors = _validateStep(_step, _form);
    });
  }

  void _next() {
    final errs = _validateStep(_step, _form);
    // ⚠️ MOCK : le compte existant est détecté dès la saisie du numéro
    // (avec Firebase, il l'est après la vérification SMS).
    if (_step == 2 &&
        errs.isEmpty &&
        !MoncarPhoneAuth.enabled &&
        ref.read(mockStoreProvider).hasAccount('+225${_form.phone}')) {
      errs['phone'] = 'Un compte existe déjà avec ce numéro. Connectez-vous.';
    }
    setState(() {
      _touched.addAll([
        'firstName',
        'lastName',
        if (_step >= 2) ...['phone', 'email'],
        if (_step >= 3) ...['password', 'passwordConfirm'],
        if (_step >= 4) ...['city', 'acceptCgu'],
      ]);
      _errors = errs;
      if (errs.isEmpty && _step < 5) {
        _step += 1;
        _errors = {};
      }
    });
  }

  void _prev() {
    if (_step == 1) {
      context.mcBack();
      return;
    }
    setState(() {
      _step -= 1;
      _errors = {};
    });
  }

  Future<void> _submitAccount() async {
    if (_submitting) return;
    final all = {
      ..._validateStep(1, _form),
      ..._validateStep(2, _form),
      ..._validateStep(3, _form),
      ..._validateStep(4, _form),
    };
    if (all.isNotEmpty) {
      setState(() {
        _errors = all;
        _step = 1;
      });
      return;
    }
    final fullPhone = '+225${_form.phone}';
    // Le mot de passe reste en mémoire le temps de la vérification SMS
    // (jamais dans l'URL), puis est rattaché au compte.
    ref.read(pendingSignupProvider.notifier).state = PendingSignup(
      phone: fullPhone,
      password: _form.password,
      firstName: _form.firstName,
      lastName: _form.lastName,
      email: _form.email,
      city: _form.city,
      optinPromos: _form.optinPromos,
    );
    final otpRoute =
        '/auth/otp?phone=${Uri.encodeComponent(fullPhone)}&purpose=signup';
    setState(() => _submitting = true);
    if (MoncarPhoneAuth.enabled) {
      // Réel : Firebase envoie le SMS de vérification (ou applique le
      // code de test pour un numéro déclaré dans Firebase Console).
      await MoncarPhoneAuth.sendCode(
        fullPhone,
        onCodeSent: () {
          if (!mounted) return;
          setState(() => _submitting = false);
          context.push(otpRoute);
        },
        onSignedIn: () async {
          // Vérification automatique Android : pas de code à saisir.
          if (!mounted) return;
          final error = await completePhoneVerification(
            context,
            ref,
            purpose: OtpPurpose.signup,
            phone: fullPhone,
          );
          if (!mounted) return;
          setState(() => _submitting = false);
          if (error != null) showMoncarToast(context, error, error: true);
        },
        onError: (message) {
          if (!mounted) return;
          setState(() => _submitting = false);
          showMoncarToast(context, message, error: true);
        },
      );
      return;
    }
    // ⚠️ MOCK (tests uniquement) : POST /auth/otp/request simulé.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final r = ref.read(mockStoreProvider).requestOtp(fullPhone);
    setState(() => _submitting = false);
    showDemoOtpCode(context, r.code, fullPhone);
    context.push(otpRoute);
  }

  Future<void> _pickCity() async {
    final city = await CityPicker.show(
      context,
      title: 'Ville principale',
      selectedName: _form.city,
    );
    if (city == null) return;
    _form.city = city.name;
    _touched.add('city');
    _changed('city');
  }

  static const _stepNames = [
    'Identité',
    'Contact',
    'Sécurité',
    'Ville & CGU',
    'Confirmation',
  ];

  @override
  Widget build(BuildContext context) {
    final stepValid = _validateStep(_step, _form).isEmpty;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Inscription',
        showBack: true,
        showBell: false,
        onBack: _prev,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                children: [
                  const Center(child: MonCarLogo(size: 56)),
                  const SizedBox(height: 12),
                  Text(
                    'Créer votre compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rejoignez MON CAR en quelques secondes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OverlineText('Étape $_step / ${_stepNames.length}'),
                      const Spacer(),
                      Text(
                        _stepNames[_step - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _StepProgress(current: _step, total: _stepNames.length),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0.08, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: MoncarCard(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.all(20),
                      child: switch (_step) {
                        1 => _buildIdentity(),
                        2 => _buildContact(),
                        3 => _buildPassword(),
                        4 => _buildCityCgu(),
                        _ => _buildRecap(),
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step > 1)
                    TextButton.icon(
                      onPressed: _prev,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Retour'),
                      style: TextButton.styleFrom(
                        foregroundColor: MoncarColors.inkMut,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_step < 5)
                    MoncarButton(
                      label: 'Continuer',
                      icon: Icons.arrow_forward,
                      variant: MoncarButtonVariant.primary,
                      size: MoncarButtonSize.xl,
                      expand: true,
                      onPressed: stepValid ? _next : null,
                    )
                  else
                    MoncarButton(
                      label: 'Créer mon compte',
                      icon: Icons.arrow_forward,
                      variant: MoncarButtonVariant.primary,
                      size: MoncarButtonSize.xl,
                      expand: true,
                      isLoading: _submitting,
                      onPressed: _submitAccount,
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: Text(
                      'Déjà un compte ? Se connecter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          index: 1,
          title: 'Votre identité',
          subtitle:
              'Dites-nous qui vous êtes — ces informations apparaîtront sur vos billets.',
        ),
        MoncarTextField(
          label: 'Prénom',
          controller: _firstName,
          hint: 'ex. Aïcha',
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          error: _errors['firstName'],
          onChanged: (v) {
            _form.firstName = v;
            _touched.add('firstName');
            _changed('firstName');
          },
        ),
        const SizedBox(height: 16),
        MoncarTextField(
          label: 'Nom',
          controller: _lastName,
          hint: 'ex. Koné',
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          error: _errors['lastName'],
          onChanged: (v) {
            _form.lastName = v;
            _touched.add('lastName');
            _changed('lastName');
          },
        ),
      ],
    );
  }

  Widget _buildContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          index: 2,
          title: 'Vos coordonnées',
          subtitle:
              'Nous utiliserons votre téléphone pour vous envoyer un code de vérification par SMS.',
        ),
        const MoncarLabel('Téléphone'),
        PhoneField(
          controller: _phone,
          hasError: _errors['phone'] != null,
          onChanged: (v) {
            _form.phone = v.replaceAll(RegExp(r'\D'), '');
            if (_form.phone.length > 10) {
              _form.phone = _form.phone.substring(0, 10);
            }
            _touched.add('phone');
            _changed('phone');
          },
        ),
        if (_errors['phone'] != null) FieldError(_errors['phone']!),
        const SizedBox(height: 16),
        MoncarTextField(
          label: 'E-mail (optionnel)',
          controller: _email,
          hint: 'vous@exemple.com',
          keyboardType: TextInputType.emailAddress,
          error: _errors['email'],
          onChanged: (v) {
            _form.email = v;
            _touched.add('email');
            _changed('email');
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Pour recevoir vos billets et reçus par e-mail.',
          style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
        ),
      ],
    );
  }

  Widget _buildPassword() {
    // Pas d'erreur tant que la confirmation est en cours de saisie.
    final confirmError =
        _touched.contains('passwordConfirm') &&
            _form.passwordConfirm.length >= _form.password.length
        ? _errors['passwordConfirm']
        : null;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            index: 3,
            title: 'Sécurisez votre compte',
            subtitle:
                'Créez le mot de passe que vous utiliserez avec votre numéro '
                'pour vous connecter.',
          ),
          PasswordField(
            controller: _password,
            label: 'Mot de passe',
            hint: 'Au moins 8 caractères',
            isNew: true,
            textInputAction: TextInputAction.next,
            onChanged: (v) {
              _form.password = v;
              _changed('password');
            },
          ),
          PasswordStrengthMeter(password: _form.password),
          const SizedBox(height: 18),
          PasswordField(
            controller: _passwordConfirm,
            label: 'Confirmer le mot de passe',
            hint: 'Saisissez-le à nouveau',
            isNew: true,
            error: confirmError,
            textInputAction: TextInputAction.done,
            onChanged: (v) {
              _form.passwordConfirm = v;
              _touched.add('passwordConfirm');
              _changed('passwordConfirm');
            },
            onSubmitted: (_) {
              if (_validateStep(3, _form).isEmpty) _next();
            },
          ),
          if (confirmError == null &&
              _form.passwordConfirm.isNotEmpty &&
              _form.passwordConfirm == _form.password &&
              isPasswordValid(_form.password))
            const PasswordMatchHint(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: MoncarColors.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ne communiquez jamais votre mot de passe. MON CAR ne vous '
                    'le demandera jamais par téléphone ou SMS.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: MoncarColors.inkMut,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityCgu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          index: 4,
          title: 'Votre ville & conditions',
          subtitle:
              "Sélectionnez votre ville principale et acceptez nos conditions d'utilisation.",
        ),
        const MoncarLabel('Ville principale'),
        InkWell(
          onTap: _pickCity,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: MoncarColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MoncarColors.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: MoncarColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _form.city,
                    overflow: TextOverflow.ellipsis,
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
        if (_errors['city'] != null) FieldError(_errors['city']!),
        const SizedBox(height: 16),
        _CheckTile(
          checked: _form.acceptCgu,
          hasError: _errors['acceptCgu'] != null,
          onChanged: (v) {
            _form.acceptCgu = v;
            _touched.add('acceptCgu');
            _changed('acceptCgu');
          },
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: MoncarColors.inkMut,
              ),
              children: [
                TextSpan(text: "J'accepte les "),
                TextSpan(
                  text: "Conditions d'utilisation",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.brand,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' et la '),
                TextSpan(
                  text: 'Politique de confidentialité',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.brand,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' de MON CAR.'),
              ],
            ),
          ),
        ),
        if (_errors['acceptCgu'] != null) FieldError(_errors['acceptCgu']!),
        const SizedBox(height: 10),
        _CheckTile(
          checked: _form.optinPromos,
          onChanged: (v) => setState(() => _form.optinPromos = v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: MoncarColors.accent,
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Je souhaite recevoir les offres et promotions MON CAR.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'Notifications par SMS / e-mail, désinscription à tout moment.',
                style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MoncarColors.successSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: MoncarColors.success,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Vos données sont chiffrées et stockées en Côte d'Ivoire. "
                  'Elles ne sont jamais partagées sans votre consentement.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: MoncarColors.inkMut,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecap() {
    final phonePreview = _formatPhonePreview(_form.phone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          index: 5,
          title: 'Vérifiez vos informations',
          subtitle:
              'Tout est bon ? Créez votre compte : nous allons vous envoyer un code SMS pour confirmer.',
        ),
        _InfoRow(
          icon: Icons.person_outline,
          label: 'Identité',
          value: '${_form.firstName} ${_form.lastName}',
        ),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Téléphone',
          value: '+225 $phonePreview',
        ),
        if (_form.email.trim().isNotEmpty)
          _InfoRow(
            icon: Icons.mail_outline,
            label: 'E-mail',
            value: _form.email,
          ),
        _InfoRow(
          icon: Icons.lock_outline,
          label: 'Mot de passe',
          value: '••••••••',
          success: isPasswordValid(_form.password),
        ),
        _InfoRow(icon: Icons.place_outlined, label: 'Ville', value: _form.city),
        _InfoRow(
          icon: Icons.verified_user_outlined,
          label: 'CGU',
          value: _form.acceptCgu ? 'Acceptées' : '—',
          success: _form.acceptCgu,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MoncarColors.brandSoft.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: MoncarColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11.5,
                      color: MoncarColors.inkMut,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Un code à 6 chiffres sera envoyé par SMS au ',
                      ),
                      TextSpan(
                        text: '+225 $phonePreview',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 6,
                color: MoncarColors.hairline,
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOut,
                  widthFactor: i <= current ? 1 : 0,
                  child: Container(
                    color: i < current
                        ? MoncarColors.brand
                        : MoncarColors.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MoncarColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.accentInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: MoncarColors.inkMut,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.checked,
    required this.onChanged,
    required this.child,
    this.hasError = false,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final borderColor = checked
        ? MoncarColors.brand
        : hasError
        ? MoncarColors.danger.withValues(alpha: 0.4)
        : MoncarColors.hairline;
    final bg = checked
        ? MoncarColors.brandSoft.withValues(alpha: 0.5)
        : hasError
        ? MoncarColors.dangerSoft.withValues(alpha: 0.4)
        : MoncarColors.surface;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!checked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: checked,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: MoncarColors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.success = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MoncarColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: MoncarColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverlineText(label, color: MoncarColors.inkFaint),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (success)
            const MoncarBadge(
              label: 'OK',
              tone: MoncarBadgeTone.success,
              size: MoncarBadgeSize.sm,
              icon: Icons.check,
            )
          else
            Icon(Icons.chevron_right, size: 16, color: MoncarColors.inkFaint),
        ],
      ),
    );
  }
}
