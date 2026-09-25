import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/foundation.dart';

/// Délai passé en arrière-plan au-delà duquel le code PIN est redemandé.
const lockAfter = Duration(seconds: 30);

/// Nombre d'essais avant déconnexion forcée.
const _maxAttempts = 5;

/// Verrouillage de l'app : quand un code PIN est défini et que l'app
/// revient au premier plan après [lockAfter], un écran de verrouillage
/// recouvre l'interface (PIN ou biométrie). Placé dans le `builder` de
/// `MaterialApp.router` pour couvrir toutes les routes.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;
  bool _locked = false;

  /// Invite biométrique en cours : elle peut elle-même masquer l'app.
  bool _authenticating = false;

  bool get _canLock =>
      ref.read(authProvider).isAuthenticated &&
      ref.read(securitySettingsProvider).hasPin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Bouton retour Android ignoré tant que l'app est verrouillée.
  @override
  Future<bool> didPopRoute() async => _locked;

  void _onHide() {
    if (_authenticating || _locked) return;
    _hiddenAt = DateTime.now();
  }

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (_locked || hiddenAt == null || !_canLock) return;
    if (DateTime.now().difference(hiddenAt) >= lockAfter) {
      setState(() => _locked = true);
    }
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    // Déconnexion ou PIN supprimé ailleurs : on lève le verrou.
    ref.listen(authProvider, (_, next) {
      if (!next.isAuthenticated && _locked) _unlock();
    });
    return Stack(
      children: [
        TickerMode(
          enabled: !_locked,
          child: Offstage(offstage: _locked, child: widget.child),
        ),
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              onUnlocked: _unlock,
              onAuthenticating: (v) => _authenticating = v,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({required this.onUnlocked, required this.onAuthenticating});

  final VoidCallback onUnlocked;
  final ValueChanged<bool> onAuthenticating;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  int _attempts = 0;
  bool _confirmForgot = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(securitySettingsProvider).biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  Future<void> _biometric() async {
    widget.onAuthenticating(true);
    final ok = await Biometrics.authenticate('Déverrouiller MON CAR');
    widget.onAuthenticating(false);
    if (ok && mounted) widget.onUnlocked();
  }

  Future<String?> _checkPin(String code) async {
    if (ref.read(securitySettingsProvider.notifier).verifyPin(code)) {
      widget.onUnlocked();
      return null;
    }
    _attempts++;
    final left = _maxAttempts - _attempts;
    if (left <= 0) {
      _forceSignOut(
        'Trop d’essais. Reconnectez-vous avec le code reçu par SMS.',
      );
      return null;
    }
    return 'Code incorrect · $left essai${left > 1 ? 's' : ''} restant${left > 1 ? 's' : ''}';
  }

  void _forceSignOut(String message) {
    signOut(ref);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final biometric = ref.watch(securitySettingsProvider).biometric;
    final white70 = Colors.white.withValues(alpha: 0.75);
    return Material(
      child: DecoratedBox(
        decoration: brandGradientDecoration(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 40, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    user == null ? 'MON CAR' : 'Bonjour ${user.firstName}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saisissez votre code PIN pour continuer',
                    style: TextStyle(fontSize: 13, color: white70),
                  ),
                  const SizedBox(height: 28),
                  PinPad(
                    dark: true,
                    onCompleted: _checkPin,
                    extraKey: biometric
                        ? IconButton(
                            tooltip: 'Déverrouiller par biométrie',
                            onPressed: _biometric,
                            icon: const Icon(
                              Icons.fingerprint,
                              size: 32,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      if (!_confirmForgot) {
                        setState(() => _confirmForgot = true);
                        return;
                      }
                      _forceSignOut(
                        'Déconnecté. Reconnectez-vous avec le code reçu par SMS.',
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(
                      _confirmForgot
                          ? 'Confirmer : se déconnecter et se reconnecter par SMS'
                          : 'Code PIN oublié ?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
