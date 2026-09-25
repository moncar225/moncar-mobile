import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/foundation.dart';
import '../data/ticket_pdf.dart';

/// Billet électronique : itinéraire, détails, QR signé (agrandissable)
/// et actions (suivi, partage, PDF, historique).
class TicketPage extends ConsumerStatefulWidget {
  const TicketPage({super.key, required this.ticketId});

  /// Identifiant ou numéro de billet (ou identifiant de réservation).
  final String ticketId;

  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<TicketPage> {
  Ticket? _find() {
    final store = ref.read(mockStoreProvider);
    // Par numéro/id, sinon par réservation (billet aller en priorité).
    return store.findTicket(widget.ticketId) ??
        store.tickets
            .where(
              (t) => t.bookingId == widget.ticketId && t.leg == TicketLeg.aller,
            )
            .firstOrNull;
  }

  bool _pdfBusy = false;

  /// Autre billet de la même réservation (segment aller ↔ retour).
  Ticket? _sibling(Ticket t) => ref
      .read(mockStoreProvider)
      .tickets
      .where((x) => x.bookingId == t.bookingId && x.id != t.id)
      .firstOrNull;

  /// Partage natif (WhatsApp, SMS, e-mail…) du résumé du billet.
  Future<void> _share(Ticket t) async {
    final text =
        'Mon billet MON CAR ${t.number}\n'
        '${t.originCity} → ${t.destinationCity}\n'
        '${formatDateFull(t.date)} · départ ${t.departureTime}\n'
        'Siège ${t.seatNumber} · ${t.companyName}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Billet MON CAR ${t.number}'),
      );
    } catch (_) {
      if (mounted) copyWithToast(context, text, message: 'Billet copié');
    }
  }

  /// Génère le billet PDF puis l'ouvre dans la feuille de partage
  /// (Enregistrer dans Fichiers/Drive, WhatsApp, e-mail…).
  Future<void> _downloadPdf(Ticket t) async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final bytes = await buildTicketPdf(t);
      final name = 'billet-${t.number}.pdf';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: name),
          ],
          fileNameOverrides: [name],
          subject: 'Billet MON CAR ${t.number}',
        ),
      );
    } catch (_) {
      if (mounted) {
        showMoncarToast(
          context,
          'Impossible de générer le PDF. Réessayez.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  void _zoom(Ticket t) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: MoncarColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Billet ${t.number}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MoncarColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              TicketQr(payload: t.qrPayload, size: 260),
              const SizedBox(height: 12),
              Text(
                "Présentez ce code à l'embarquement",
                style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
              ),
              const SizedBox(height: 16),
              MoncarButton(
                label: 'Fermer',
                variant: MoncarButtonVariant.brand,
                size: MoncarButtonSize.md,
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final t = _find();
    if (t == null) {
      return Scaffold(
        appBar: const TopBar(
          title: 'Mon billet',
          showBack: true,
          showBell: false,
        ),
        body: MoncarErrorState(
          message: 'Billet introuvable',
          onRetry: () => setState(() {}),
        ),
      );
    }
    final issued = DateTime.parse(t.issuedAt);
    final issuedStr =
        '${issued.day.toString().padLeft(2, '0')}/'
        '${issued.month.toString().padLeft(2, '0')}/${issued.year}';

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Mon billet',
        showBack: true,
        showBell: false,
        rightSlot: IconButton(
          tooltip: 'Partager',
          onPressed: () => _share(t),
          icon: Icon(Icons.share_outlined, color: MoncarColors.brand),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_sibling(t) case final other?) ...[
            _LegSwitch(
              current: t.leg,
              onSwitch: () =>
                  context.pushReplacement('/voyager/ticket/${other.id}'),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: MoncarColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: MoncarColors.hairline),
              boxShadow: [
                BoxShadow(
                  color: MoncarColors.brand.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: brandGradientDecoration(),
                  child: Row(
                    children: [
                      const MonCarLogo(size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MON CAR',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Voyagez en toute confiance',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_sibling(t) != null) ...[
                        MoncarBadge(
                          label: t.leg.label,
                          tone: t.leg == TicketLeg.retour
                              ? MoncarBadgeTone.accent
                              : MoncarBadgeTone.brand,
                          size: MoncarBadgeSize.sm,
                        ),
                        const SizedBox(width: 6),
                      ],
                      MoncarBadge(
                        label: t.status == TicketStatus.emis
                            ? 'Valide'
                            : t.status.name,
                        tone: MoncarBadgeTone.success,
                        size: MoncarBadgeSize.sm,
                        icon: Icons.check,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Endpoint(
                          label: 'Départ',
                          city: t.originCity,
                          time: t.departureTime,
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_bus,
                              size: 16,
                              color: MoncarColors.accent,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Direct',
                              style: TextStyle(
                                fontSize: 9,
                                color: MoncarColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _Endpoint(
                          label: 'Arrivée',
                          city: t.destinationCity,
                          time: t.arrivalTime,
                        ),
                      ),
                    ],
                  ),
                ),
                const _Perforation(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Detail(
                              icon: Icons.person_outline,
                              label: 'Passager',
                              value: t.passengerName,
                            ),
                            _Detail(
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: formatDateFull(t.date),
                            ),
                            _Detail(
                              icon: Icons.place_outlined,
                              label: 'Embarquement',
                              value: t.boardingStop,
                            ),
                            _Detail(
                              icon: Icons.directions_bus_outlined,
                              label: 'Véhicule',
                              value: t.vehicleModel,
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 12,
                                  color: MoncarColors.inkMut,
                                ),
                                SizedBox(width: 6),
                                OverlineText('Siège'),
                              ],
                            ),
                            Text(
                              t.seatNumber,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: MoncarColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _zoom(t),
                            child: TicketQr(payload: t.qrPayload, size: 130),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Touchez pour agrandir',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 10,
                                color: MoncarColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Signé · clé v${t.keyVersion}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: MoncarColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MoncarColors.brandSoft.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const OverlineText('Référence'),
                                Text(
                                  t.number,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    color: MoncarColors.brand,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const OverlineText('Émis le'),
                                Text(
                                  issuedStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: MoncarColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Billet vérifiable hors ligne · clé publique embarquée',
                        style: TextStyle(
                          fontSize: 10,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MoncarButton(
            label: 'Suivre mon voyage',
            icon: Icons.place_outlined,
            variant: MoncarButtonVariant.primary,
            size: MoncarButtonSize.lg,
            expand: true,
            onPressed: () => context.push('/tracking/${t.tripId}'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _IconAction(
                  icon: Icons.share_outlined,
                  tooltip: 'Partager',
                  onTap: () => _share(t),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IconAction(
                  icon: Icons.download_outlined,
                  tooltip: 'Télécharger le PDF',
                  onTap: () => _downloadPdf(t),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IconAction(
                  icon: Icons.confirmation_number_outlined,
                  tooltip: 'Mes billets',
                  onTap: () => context.push('/history?tab=tickets'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// QR code du billet (payload signé par le serveur, scannable).
class TicketQr extends StatelessWidget {
  const TicketQr({super.key, required this.payload, this.size = 130});

  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      // Toujours navy sur blanc, même en thème sombre : contraste requis
      // par les lecteurs de QR à l'embarquement.
      child: QrImageView(
        data: payload,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: MoncarPalette.light.brand,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: MoncarPalette.light.brand,
        ),
        semanticsLabel: 'QR code du billet',
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.city,
    required this.time,
  });

  final String label;
  final String city;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OverlineText(label),
        const SizedBox(height: 2),
        Text(
          city,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: MoncarColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(time, style: TextStyle(fontSize: 11, color: MoncarColors.inkMut)),
      ],
    );
  }
}

/// Ligne de perforation avec encoches latérales.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, c) {
                final count = (c.maxWidth / 10).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => Container(
                      width: 5,
                      height: 2,
                      color: MoncarColors.hairline,
                    ),
                  ),
                );
              },
            ),
          ),
          const Positioned(left: -12, child: _Notch()),
          const Positioned(right: -12, child: _Notch()),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: MoncarColors.background,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: MoncarColors.inkMut),
              const SizedBox(width: 6),
              OverlineText(label),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: MoncarColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: MoncarColors.brand,
          side: BorderSide(color: MoncarColors.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

/// Bascule Aller / Retour entre les deux billets d'un aller-retour.
class _LegSwitch extends StatelessWidget {
  const _LegSwitch({required this.current, required this.onSwitch});

  final TicketLeg current;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Row(
        children: [
          for (final leg in TicketLeg.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: leg == current,
                child: GestureDetector(
                  onTap: leg == current ? null : onSwitch,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: leg == current
                          ? MoncarColors.brand
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      leg == TicketLeg.aller ? 'Billet aller' : 'Billet retour',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: leg == current
                            ? Colors.white
                            : MoncarColors.inkMut,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
