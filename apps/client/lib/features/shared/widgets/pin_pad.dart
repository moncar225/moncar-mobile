import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:core_ui/core_ui.dart';

/// Longueur du code PIN de verrouillage.
const pinLength = 4;

/// Saisie d'un code PIN : points de progression + pavé numérique.
///
/// [onCompleted] reçoit le code complet et renvoie un message d'erreur
/// (le code est alors effacé) ou `null` si le code est accepté.
/// [extraKey] occupe la case en bas à gauche (ex. bouton biométrie).
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.extraKey,
    this.dark = false,
  });

  final Future<String?> Function(String code) onCompleted;
  final Widget? extraKey;

  /// Chiffres blancs sur fond de marque (écran de verrouillage).
  final bool dark;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _code = '';
  String? _error;
  bool _busy = false;

  void _tap(String digit) {
    if (_busy || _code.length >= pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _code += digit;
      _error = null;
    });
    if (_code.length == pinLength) _submit();
  }

  void _backspace() {
    if (_busy || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    _busy = true;
    final error = await widget.onCompleted(_code);
    _busy = false;
    if (!mounted) return;
    if (error == null) return;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _code = '';
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.dark ? Colors.white : MoncarColors.ink;
    final dot = widget.dark ? Colors.white : MoncarColors.brand;
    final errorColor = widget.dark
        ? const Color(0xFFFFB4A9)
        : MoncarColors.danger;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < pinLength; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _code.length
                      ? (_error != null ? errorColor : dot)
                      : Colors.transparent,
                  border: Border.all(
                    color: _error != null ? errorColor : dot,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: _error == null
                ? null
                : Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: errorColor),
                  ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final k in row)
                SizedBox(
                  width: 72,
                  height: 60,
                  child: k.isEmpty
                      ? widget.extraKey
                      : Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => k == '<' ? _backspace() : _tap(k),
                            child: Center(
                              child: k == '<'
                                  ? Icon(
                                      Icons.backspace_outlined,
                                      semanticLabel: 'Effacer',
                                      color: fg.withValues(alpha: 0.7),
                                    )
                                  : Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: fg,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}
