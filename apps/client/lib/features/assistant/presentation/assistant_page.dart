import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../../tracking/application/alerte_descente.dart' show AnnonceVocale;
import '../application/assistant.dart';

/// Assistant MON CAR (IA-001) : injectable pour les tests et pour brancher
/// l'adaptateur serveur (POST /ia/dialogue) le moment venu.
final assistantProvider = Provider<Assistant>(
  (ref) => AssistantDemo(ref.watch(mockStoreProvider)),
);

/// Assistant voyage : dialogue, suggestions, réponse vocale et passage à un
/// conseiller humain à tout moment.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();
  final _voix = AnnonceVocale();
  bool _lecture = false;
  bool _enCours = false;
  final List<MessageAssistant> _messages = [
    const MessageAssistant(
      auteur: Auteur.assistant,
      texte:
          'Bonjour, je suis l’assistant MON CAR. Posez votre question : billets, '
          'suivi du car, colis, location…',
      suggestions: suggestionsAccueil,
    ),
  ];

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _envoyer(String texte) async {
    final question = texte.trim();
    if (question.isEmpty || _enCours) return;
    _saisie.clear();
    setState(() {
      _messages.add(MessageAssistant(auteur: Auteur.client, texte: question));
      _enCours = true;
    });
    _defiler();
    MessageAssistant reponse;
    try {
      reponse = await ref.read(assistantProvider).repondre(question);
    } catch (_) {
      // Mode dégradé : jamais bloquant, on oriente vers un humain.
      reponse = const MessageAssistant(
        auteur: Auteur.assistant,
        texte:
            'Je ne suis pas disponible pour le moment. Un conseiller peut vous '
            'répondre directement.',
        versConseiller: true,
      );
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reponse);
      _enCours = false;
    });
    if (_lecture) _voix.dire(reponse.texte);
    _defiler();
  }

  void _defiler() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defilement.hasClients) {
        _defilement.animateTo(
          _defilement.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final disponible = ref.watch(assistantProvider).disponible;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Assistant MON CAR',
        subtitle: disponible ? 'Réponses automatiques' : 'Indisponible',
        showBack: true,
        showBell: false,
        rightSlot: IconButton(
          tooltip: _lecture
              ? 'Couper la lecture vocale'
              : 'Lire les réponses à voix haute',
          icon: Icon(_lecture ? Icons.volume_up : Icons.volume_off_outlined),
          onPressed: () => setState(() => _lecture = !_lecture),
        ),
      ),
      body: Column(
        children: [
          if (!disponible)
            MoncarCard(
              margin: const EdgeInsets.all(12),
              color: MoncarColors.warnSoft,
              child: const Text(
                'L’assistant est momentanément indisponible. Un conseiller vous répond.',
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _defilement,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: _messages.length + (_enCours ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('…'),
                    ),
                  );
                }
                return _Bulle(message: _messages[i], onSuggestion: _envoyer);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    onPressed: () => context.push('/help'),
                    icon: const Icon(Icons.support_agent, size: 18),
                    label: const Text('Parler à un conseiller'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _saisie,
                          enabled: disponible,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _envoyer,
                          decoration: const InputDecoration(
                            hintText: 'Votre question…',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Envoyer',
                        onPressed: disponible && !_enCours
                            ? () => _envoyer(_saisie.text)
                            : null,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle({required this.message, required this.onSuggestion});

  final MessageAssistant message;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final client = message.auteur == Auteur.client;
    final action = message.action;
    return Align(
      alignment: client ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: client
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: client ? MoncarColors.brand : MoncarColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: client
                    ? null
                    : Border.all(color: MoncarColors.hairline),
              ),
              child: Text(
                message.texte,
                style: TextStyle(
                  fontSize: 14,
                  color: client ? Colors.white : MoncarColors.ink,
                ),
              ),
            ),
            if (action != null)
              MoncarButton(
                label: action.libelle,
                size: MoncarButtonSize.sm,
                variant: MoncarButtonVariant.soft,
                onPressed: () => context.push(action.route),
              ),
            if (message.versConseiller)
              MoncarButton(
                label: 'Contacter un conseiller',
                icon: Icons.support_agent,
                size: MoncarButtonSize.sm,
                onPressed: () => context.push('/help'),
              ),
            if (message.suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in message.suggestions)
                      MoncarChip(label: s, onTap: () => onSuggestion(s)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
