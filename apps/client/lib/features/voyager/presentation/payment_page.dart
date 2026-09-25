import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/payment_otp_sheet.dart';
import '../../shared/foundation.dart';
import '../widgets/voyager_widgets.dart';

enum _Phase { select, initiating, pending, success, failed, expired }

/// Paiement mobile money / carte : initialisation idempotente puis
/// interrogation du serveur jusqu'à un statut terminal — le succès
/// n'est jamais supposé côté client.
class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  PaymentMethod _method = PaymentMethod.orangeMoney;
  _Phase _phase = _Phase.select;
  int _countdown = 300;
  Payment? _payment;
  String _failureReason = '';
  Timer? _ticker;
  Timer? _poller;

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _start(Booking booking) async {
    final confirmed = await confirmPaymentWithOtp(
      context,
      ref,
      amountXOF: booking.totalXOF,
    );
    if (!confirmed || !mounted) return;
    setState(() => _phase = _Phase.initiating);
    // ⚠️ MOCK : POST /payments (latence simulée).
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final store = ref.read(mockStoreProvider);
    final r = store.createPayment(
      bookingId: booking.id,
      method: _method,
      idempotencyKey: booking.idempotencyKey,
    );
    final p = r.payment;
    if (!r.ok || p == null) {
      setState(() {
        _phase = _Phase.failed;
        _failureReason = r.error ?? 'Initialisation du paiement échouée.';
      });
      return;
    }
    setState(() {
      _payment = p;
      _phase = _Phase.pending;
      _countdown = 300;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown = (_countdown - 1).clamp(0, 300));
    });
    _poller = Timer(
      const Duration(milliseconds: 1800),
      () => _poll(booking, p.id),
    );
  }

  /// ⚠️ MOCK : POST /payments/:id/poll — le « PSP » confirme après ~1,4 s.
  Future<void> _poll(Booking booking, String paymentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final store = ref.read(mockStoreProvider);
    store.processPayment(paymentId);
    final updated = store.findPayment(paymentId);
    if (updated == null) {
      _poller = Timer(
        const Duration(milliseconds: 2500),
        () => _poll(booking, paymentId),
      );
      return;
    }
    setState(() => _payment = updated);
    switch (updated.status) {
      case PaymentStatus.paye:
        _ticker?.cancel();
        setState(() => _phase = _Phase.success);
        _poller = Timer(const Duration(milliseconds: 600), () {
          if (mounted) {
            context.pushReplacement('/voyager/confirmation/${booking.id}');
          }
        });
      case PaymentStatus.echoue:
        _ticker?.cancel();
        setState(() {
          _phase = _Phase.failed;
          _failureReason = updated.failureReason ?? 'Transaction refusée.';
        });
      case PaymentStatus.expire:
        _ticker?.cancel();
        setState(() => _phase = _Phase.expired);
      case PaymentStatus.enAttente || PaymentStatus.annule:
        _poller = Timer(
          const Duration(seconds: 2),
          () => _poll(booking, paymentId),
        );
    }
  }

  void _retry() {
    _ticker?.cancel();
    _poller?.cancel();
    setState(() {
      _phase = _Phase.select;
      _payment = null;
      _failureReason = '';
      _countdown = 300;
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.read(mockStoreProvider).findBooking(widget.bookingId);
    if (booking == null) {
      return Scaffold(
        appBar: const TopBar(
          title: 'Paiement',
          showBack: true,
          showBell: false,
        ),
        body: MoncarErrorState(
          message: 'Réservation introuvable',
          onRetry: () => setState(() {}),
        ),
      );
    }
    return switch (_phase) {
      _Phase.initiating || _Phase.pending => _buildPending(booking),
      _Phase.failed => _buildFailed(),
      _Phase.expired => _buildExpired(),
      _Phase.success => _buildSuccess(),
      _Phase.select => _buildSelect(booking),
    };
  }

  Widget _statusScaffold(String title, Widget child) {
    return PopScope(
      canPop: _phase != _Phase.pending && _phase != _Phase.initiating,
      child: Scaffold(
        backgroundColor: MoncarColors.background,
        appBar: TopBar(title: title, showBell: false),
        body: ListView(padding: const EdgeInsets.all(16), children: [child]),
      ),
    );
  }

  Widget _buildPending(Booking booking) {
    final meta = PAYMENT_METHODS.firstWhere((m) => m.method == _method);
    final color = hexColor(meta.color);
    final initiating = _phase == _Phase.initiating;
    final mm = _countdown ~/ 60;
    final ss = (_countdown % 60).toString().padLeft(2, '0');
    return _statusScaffold(
      'Paiement en cours',
      Column(
        children: [
          MoncarCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _PingRing(
                  color: MoncarColors.accent,
                  child: Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      meta.icon,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  initiating ? 'Initialisation…' : 'Paiement en cours',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  initiating
                      ? 'Connexion à ${meta.label}…'
                      : 'Confirmez la transaction sur votre téléphone via ${meta.label}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MoncarColors.brandSoft.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const OverlineText('Montant'),
                      Text(
                        formatXOF(booking.totalXOF),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: MoncarColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!initiating) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: MoncarColors.inkMut,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$mm:$ss',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: MoncarColors.inkMut,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'restant',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoncarColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 12,
                      color: MoncarColors.inkFaint,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Ne fermez pas cette page. Transaction sécurisée.',
                      style: TextStyle(
                        fontSize: 10,
                        color: MoncarColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "N'entrez jamais votre code PIN si on vous le demande par téléphone. "
              'MON CAR ne vous demandera jamais votre code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return _statusScaffold(
      'Paiement échoué',
      MoncarCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _StatusIcon(
              icon: Icons.close,
              color: MoncarColors.danger,
              bg: MoncarColors.dangerSoft,
            ),
            const SizedBox(height: 16),
            Text(
              'Paiement échoué',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _failureReason,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
            ),
            if (_payment != null) ...[
              const SizedBox(height: 16),
              Text(
                'Réf. ${_payment!.reference}',
                style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
              ),
            ],
            const SizedBox(height: 16),
            MoncarButton(
              label: 'Réessayer',
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: _retry,
            ),
            const SizedBox(height: 8),
            MoncarButton(
              label: 'Changer de méthode',
              variant: MoncarButtonVariant.ghost,
              size: MoncarButtonSize.md,
              expand: true,
              onPressed: _retry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpired() {
    return _statusScaffold(
      'Paiement expiré',
      MoncarCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _StatusIcon(
              icon: Icons.schedule,
              color: MoncarColors.warn,
              bg: MoncarColors.warnSoft,
            ),
            const SizedBox(height: 16),
            Text(
              'Délai dépassé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'La transaction a expiré. Votre réservation a été annulée et les sièges libérés.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
            ),
            const SizedBox(height: 16),
            MoncarButton(
              label: 'Nouvelle recherche',
              variant: MoncarButtonVariant.brand,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: () => context.go('/voyager'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return _statusScaffold(
      'Paiement confirmé',
      MoncarCard(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            _PingRing(
              color: MoncarColors.success,
              child: _StatusIcon(
                icon: Icons.check,
                color: MoncarColors.success,
                bg: MoncarColors.successSoft,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Paiement confirmé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Génération de votre billet…',
              style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
            ),
            SizedBox(height: 16),
            Icon(Icons.bolt, size: 20, color: MoncarColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildSelect(Booking booking) {
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Paiement',
        subtitle: booking.reference,
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: brandGradientDecoration(
              radius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverlineText(
                  'Montant à payer',
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 4),
                Text(
                  formatXOF(booking.totalXOF),
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Montant verrouillé par le serveur',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Choisissez votre moyen de paiement'),
          for (final m in PAYMENT_METHODS) ...[
            PaymentMethodTile(
              meta: m,
              active: _method == m.method,
              onTap: () => setState(() => _method = m.method),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            color: MoncarColors.successSoft.withValues(alpha: 0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: MoncarColors.success,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paiement 100% sécurisé',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.ink,
                        ),
                      ),
                      Text(
                        'Vos données sont chiffrées. MON CAR ne stocke jamais votre code PIN.',
                        style: TextStyle(
                          fontSize: 11,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
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
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineText('Total'),
                    Text(
                      formatXOF(booking.totalXOF),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const MoncarBadge(
                  label: '15 min',
                  tone: MoncarBadgeTone.warn,
                  size: MoncarBadgeSize.sm,
                  icon: Icons.schedule,
                ),
              ],
            ),
            const SizedBox(height: 8),
            MoncarButton(
              label: 'Payer ${formatXOF(booking.totalXOF)}',
              icon: Icons.lock_outline,
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: () => _start(booking),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne de choix d'un moyen de paiement (réutilisée par Colis/Location).
class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.meta,
    required this.active,
    required this.onTap,
  });

  final PaymentMethodMeta meta;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MoncarColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? MoncarColors.brand : MoncarColors.hairline,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hexColor(meta.color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                meta.icon,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: meta.textDark ? MoncarColors.ink : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Text(
                    meta.desc,
                    style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? MoncarColors.brand : null,
                border: Border.all(
                  color: active ? MoncarColors.brand : MoncarColors.hairline,
                  width: 2,
                ),
              ),
              child: active
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.icon,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 40, color: color),
    );
  }
}

/// Anneau pulsé autour d'un contenu (état « en cours »).
class _PingRing extends StatefulWidget {
  const _PingRing({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  State<_PingRing> createState() => _PingRingState();
}

class _PingRingState extends State<_PingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform.scale(
            scale: 1 + _c.value * 0.35,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.3 * (1 - _c.value)),
                  width: 2,
                ),
              ),
            ),
          ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}
