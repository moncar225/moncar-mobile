import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/foundation.dart';

const _faq = [
  (
    q: 'Comment réserver un trajet ?',
    a: 'Onglet Voyager → saisissez votre ville de départ, votre destination et la date. Sélectionnez votre trajet, choisissez vos sièges sur la carte, renseignez les passagers puis payez via Orange/MTN/Moov/Wave ou carte bancaire. Vous recevez votre billet électronique avec QR code immédiatement après confirmation du paiement.',
  ),
  (
    q: 'Quand mon siège est-il confirmé ?',
    a: "Le siège est bloqué pendant 15 minutes après sélection. Il n'est définitivement confirmé qu'une fois le paiement serveur à l'état « payé ». Si le paiement expire ou échoue, le siège est libéré automatiquement et remis en vente.",
  ),
  (
    q: 'Comment annuler un trajet et être remboursé ?',
    a: "Ouvrez le billet depuis Historique → Mes billets. Le bouton « Annuler » est disponible jusqu'au départ selon la politique d'annulation de la compagnie : Flexible = remboursement total, Modéré = 70%, Strict = aucun remboursement. Le remboursement est crédité sous 3 à 7 jours sur votre moyen de paiement d'origine.",
  ),
  (
    q: 'Comment suivre un colis ?',
    a: "Onglet Colis → Suivre → saisissez le numéro de suivi (format MON-COL-XXXXXX). Vous verrez le statut en temps réel : déposé, en transit, arrivé en gare, attente de retrait, livré. Le destinataire doit présenter une pièce d'identité pour récupérer le colis en gare.",
  ),
  (
    q: 'Puis-je louer un véhicule avec chauffeur ?',
    a: "Oui. Sur l'onglet Location, activez l'option « Avec chauffeur » puis recherchez. Les véhicules avec chauffeur sont disponibles en zone intérieure, sous-régionale et internationale. Le prix journalier inclut le service du chauffeur et le carburant est à votre charge sauf convention contraire.",
  ),
  (
    q: 'Quels moyens de paiement sont acceptés ?',
    a: 'Mobile Money : Orange Money, MTN MoMo, Moov Money. Portefeuille électronique : Wave. Carte bancaire : Visa, Mastercard. Espèces acceptées dans certaines gares partenaires uniquement. Le paiement est traité par CinetPay avec confirmation serveur obligatoire.',
  ),
  (
    q: "Mon paiement a échoué mais j'ai été débité, que faire ?",
    a: "Si le paiement serveur renvoie « échoué » ou « expiré » mais que vous avez été débité, le remboursement automatique est déclenché sous 24h à 72h ouvrées. Vous pouvez aussi contacter le support avec la référence PMT-XXXX visible dans Historique → Paiements. Aucune action de votre part n'est nécessaire pour le remboursement automatique.",
  ),
  (
    q: 'Comment cumuler et utiliser mes points fidélité ?',
    a: "Vous gagnez 1 point par tranche de 1 000 FCFA dépensée sur des trajets payés. Les points apparaissent sous 24h dans l'onglet Fidélité. Ils sont utilisables contre des remises, trajets gratuits ou upgrades selon votre palier (Standard, Argent, Or, VIP). Les points expirent le 31 décembre de l'année N+2.",
  ),
];

const _guides = [
  (
    title: 'Voyager',
    icon: Icons.directions_bus_outlined,
    color: Color(0xFF002060),
    steps: [
      'Rechercher un trajet',
      'Choisir ses sièges',
      'Payer en ligne',
      'Embarquer avec QR',
    ],
    route: '/voyager',
    isTab: true,
  ),
  (
    title: 'Envoyer un colis',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFFFF6600),
    steps: [
      "Remplir l'expédition",
      'Payer le tarif serveur',
      'Déposer le colis en gare',
      'Suivre en temps réel',
    ],
    route: '/colis/new',
    isTab: false,
  ),
  (
    title: 'Louer un véhicule',
    icon: Icons.directions_car_outlined,
    color: Color(0xFF0A2D6E),
    steps: [
      'Choisir la zone & dates',
      'Sélectionner un véhicule',
      'Réserver et payer',
      'Récupérer les clés',
    ],
    route: '/location',
    isTab: true,
  ),
];

const _reportTypes = [
  (key: 'technique', label: 'Problème technique'),
  (key: 'paiement', label: 'Problème de paiement'),
  (key: 'trajet', label: 'Problème de trajet'),
  (key: 'colis', label: 'Problème de colis'),
  (key: 'compte', label: 'Problème de compte'),
  (key: 'autre', label: 'Autre'),
];

const _emergencyPhone = '+225 27 20 30 04 00';
const _supportEmail = 'support@moncar.ci';

/// Aide & support : assistance 24/7, contacts, guides rapides, FAQ,
/// signalement d'un problème et chat support (maquette).
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  String? _reportType;
  final _reportDesc = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reportDesc.dispose();
    super.dispose();
  }

  Future<void> _launch(Uri uri, String fallback) async {
    final ok = await launchUrl(uri);
    if (!ok && mounted) showMoncarToast(context, fallback);
  }

  void _call() => _launch(
    Uri(scheme: 'tel', path: _emergencyPhone.replaceAll(' ', '')),
    'Appel impossible depuis cet appareil : $_emergencyPhone',
  );

  Future<void> _submitReport() async {
    if (_reportType == null) {
      showMoncarToast(
        context,
        'Sélectionnez un type de problème.',
        error: true,
      );
      return;
    }
    if (_reportDesc.text.trim().length < 10) {
      showMoncarToast(
        context,
        'Décrivez votre problème (10 caractères minimum).',
        error: true,
      );
      return;
    }
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _reportType = null;
      _reportDesc.clear();
    });
    showMoncarToast(
      context,
      'Signalement envoyé. Notre support vous répondra sous 24h par email.',
      success: true,
    );
  }

  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MoncarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Aide & support',
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          MoncarCard(
            onTap: () => context.push('/assistant'),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: MoncarColors.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assistant MON CAR',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                        ),
                      ),
                      Text(
                        'Une réponse immédiate, à toute heure',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: MoncarColors.inkMut),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MoncarColors.dangerSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MoncarColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MoncarColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Assistance 24/7',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MoncarColors.danger,
                            ),
                          ),
                          SizedBox(width: 8),
                          MoncarBadge(
                            label: 'Urgence',
                            tone: MoncarBadgeTone.danger,
                            size: MoncarBadgeSize.sm,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Problème à bord, accident, litige urgent. Notre équipe vous répond jour et nuit.',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _call,
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text(_emergencyPhone),
                        style: FilledButton.styleFrom(
                          backgroundColor: MoncarColors.danger,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Contactez-nous'),
          Row(
            children: [
              _ContactTile(
                icon: Icons.chat_bubble_outline,
                label: 'Discuter',
                color: MoncarColors.brand,
                onTap: _openChat,
              ),
              const SizedBox(width: 10),
              _ContactTile(
                icon: Icons.mail_outline,
                label: 'Email',
                color: MoncarColors.accent,
                onTap: () => _launch(
                  Uri(scheme: 'mailto', path: _supportEmail),
                  'Écrivez-nous : $_supportEmail',
                ),
              ),
              const SizedBox(width: 10),
              _ContactTile(
                icon: Icons.phone_outlined,
                label: 'Appeler',
                color: MoncarColors.success,
                onTap: _call,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Comment ça marche'),
          for (final g in _guides) ...[
            MoncarCard(
              padding: const EdgeInsets.all(14),
              onTap: () =>
                  g.isTab ? context.go(g.route) : context.push(g.route),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: g.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(g.icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MoncarColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            for (var i = 0; i < g.steps.length; i++) ...[
                              Text(
                                '${i + 1}. ${g.steps[i]}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: i == 0
                                      ? MoncarColors.brand
                                      : MoncarColors.inkMut,
                                ),
                              ),
                              if (i < g.steps.length - 1)
                                Icon(
                                  Icons.arrow_forward,
                                  size: 10,
                                  color: MoncarColors.inkFaint,
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: MoncarColors.inkFaint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          const _SectionTitle('Questions fréquentes'),
          MoncarCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (var i = 0; i < _faq.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: MoncarColors.hairline,
                        ),
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          14,
                        ),
                        expandedAlignment: Alignment.centerLeft,
                        iconColor: MoncarColors.brand,
                        collapsedIconColor: MoncarColors.inkMut,
                        title: Text(
                          _faq[i].q,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                        children: [
                          Text(
                            _faq[i].a,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Signaler un problème'),
          MoncarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MoncarLabel('Type de problème'),
                DropdownButtonFormField<String>(
                  initialValue: _reportType,
                  key: ValueKey(_reportType == null),
                  isExpanded: true,
                  hint: const Text('Sélectionnez un type'),
                  onChanged: (v) => setState(() => _reportType = v),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MoncarColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MoncarColors.hairline),
                    ),
                  ),
                  items: [
                    for (final t in _reportTypes)
                      DropdownMenuItem(value: t.key, child: Text(t.label)),
                  ],
                ),
                const SizedBox(height: 12),
                MoncarTextField(
                  label: 'Description',
                  controller: _reportDesc,
                  hint:
                      "Décrivez ce qui s'est passé (étapes, référence, date…)",
                  maxLines: 5,
                  maxLength: 1000,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_reportDesc.text.length}/1000',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: MoncarColors.inkFaint),
                ),
                const SizedBox(height: 8),
                MoncarButton(
                  label: 'Envoyer le signalement',
                  icon: Icons.send_outlined,
                  variant: MoncarButtonVariant.primary,
                  size: MoncarButtonSize.lg,
                  expand: true,
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submitReport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: OverlineText(title, color: MoncarColors.inkFaint),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MoncarCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MoncarColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet();

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

typedef _Msg = ({String text, bool mine, String time});

/// Réponses automatiques de l'assistant selon les mots-clés du message.
/// ⚠️ MOCK : à remplacer par le chat temps réel (WebSocket) du support.
String _autoReply(String message) {
  final m = message.toLowerCase();
  bool has(List<String> words) => words.any(m.contains);
  if (RegExp(r'mon-(col-|rsv-|loc-)?[a-z0-9]{4,}').hasMatch(m) ||
      m.contains('pmt-')) {
    return 'Merci, j’ai bien noté votre référence. Un conseiller consulte votre dossier et vous répond ici dans quelques minutes.';
  }
  if (has(['rembours', 'annul'])) {
    return 'Vous pouvez annuler depuis Historique → votre billet → Annuler. Le remboursement suit la politique de la compagnie (Flexible, Modéré ou Strict) et arrive sous 72 h sur votre moyen de paiement.';
  }
  if (has(['bagage', 'valise', 'sac'])) {
    return 'Chaque passager a droit à 1 bagage en soute (20 kg) et 1 bagage à main. Au-delà, un supplément est demandé en gare.';
  }
  if (has(['colis', 'envoi', 'paquet'])) {
    return 'Pour suivre un colis, ouvrez l’onglet Colis et saisissez votre numéro MON-COL-XXXXXX. Le destinataire est prévenu par SMS à l’arrivée.';
  }
  if (has(['paiement', 'payer', 'orange', 'mtn', 'moov', 'wave', 'argent'])) {
    return 'Si votre compte a été débité sans confirmation, patientez 15 minutes : le paiement est vérifié automatiquement. Sinon, donnez-moi la référence PMT-XXXX.';
  }
  if (has([
    'location',
    'véhicule',
    'vehicule',
    'voiture',
    'vtc',
    'chauffeur',
  ])) {
    return 'Pour une location, la pièce d’identité et le permis sont vérifiés à la prise en charge. Les VTC sont toujours loués avec chauffeur.';
  }
  if (has(['retard', 'horaire', 'départ', 'depart'])) {
    return 'Suivez votre car en temps réel depuis votre billet → Suivre le trajet. En cas de retard de plus de 2 h, vous pouvez demander un remboursement.';
  }
  if (has(['bonjour', 'salut', 'bonsoir', 'merci'])) {
    return 'Avec plaisir ! Dites-moi comment je peux vous aider.';
  }
  return 'Je transmets votre demande à un conseiller. Réponse moyenne en 5 minutes (8h – 22h).';
}

class _ChatSheetState extends State<_ChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [
    (
      text:
          "Bonjour 👋 Je suis Sara de l'équipe support. Comment puis-je vous aider aujourd'hui ?",
      mine: false,
      time: _now(),
    ),
    (
      text:
          'Indiquez votre numéro de référence (ex : MON-XXXXXX, MON-COL-XXXXXX ou PMT-XXXX) si possible.',
      mine: false,
      time: _now(),
    ),
  ];
  bool _typing = false;

  static String _now() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() {
      _messages.add((text: text, mine: true, time: _now()));
      _typing = true;
    });
    _scrollToEnd();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _messages.add((text: _autoReply(text), mine: false, time: _now()));
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat avec le support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Réponse moyenne en 5 minutes — Disponible 8h à 22h.',
                    style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: MoncarColors.hairline),
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_typing ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (i == _messages.length) {
                    return const _ChatBubble(
                      text: 'Sara est en train d’écrire…',
                      typing: true,
                    );
                  }
                  final m = _messages[i];
                  return _ChatBubble(text: m.text, mine: m.mine, time: m.time);
                },
              ),
            ),
            Divider(height: 1, color: MoncarColors.hairline),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Écrivez votre message…',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: MoncarColors.hairline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: MoncarColors.hairline,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Envoyer',
                      onPressed: _send,
                      style: IconButton.styleFrom(
                        backgroundColor: MoncarColors.accent,
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(
                        Icons.send,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    this.mine = false,
    this.time,
    this.typing = false,
  });

  final String text;
  final bool mine;
  final String? time;
  final bool typing;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? MoncarColors.brand : MoncarColors.brandSoft,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 16 : 6),
          topRight: Radius.circular(mine ? 6 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          fontStyle: typing ? FontStyle.italic : FontStyle.normal,
          color: mine
              ? Colors.white
              : (typing ? MoncarColors.inkMut : MoncarColors.ink),
        ),
      ),
    );
    if (mine) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                bubble,
                if (time != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    time!,
                    style: TextStyle(
                      fontSize: 10,
                      color: MoncarColors.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: brandGradientDecoration().copyWith(
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.headset_mic_outlined,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time == null ? 'Support MON CAR' : 'Support MON CAR · $time',
                style: TextStyle(fontSize: 10, color: MoncarColors.inkMut),
              ),
              const SizedBox(height: 2),
              bubble,
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}
