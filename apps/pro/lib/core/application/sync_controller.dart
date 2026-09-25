// ============================================================
// MON CAR PRO — File d'actions locale + synchronisation.
//
// « Le terrain ne dépend pas du réseau » (principe n°6) : chaque action
// est d'abord enregistrée localement avec son heure terrain et son
// Idempotency-Key, puis rejouée au retour du réseau, sans doublon.
// ⚠️ Stockage : préférences locales en attendant le schéma Drift
// (core_data) dérivé du contrat OpenAPI.
// ============================================================

library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pro_api.dart';
import '../domain/models.dart';
import 'app_providers.dart';

@immutable
class SyncState {
  const SyncState({
    this.ops = const [],
    this.flushing = false,
    this.lastSyncAt,
  });

  final List<SyncOp> ops;
  final bool flushing;
  final DateTime? lastSyncAt;

  int get pendingCount => ops
      .where(
        (o) =>
            o.status == SyncOpStatus.pending || o.status == SyncOpStatus.error,
      )
      .length;

  int get doneCount => ops.where((o) => o.status == SyncOpStatus.done).length;
  int get errorCount => ops.where((o) => o.status == SyncOpStatus.error).length;

  bool isDone(String key) =>
      ops.any((o) => o.idempotencyKey == key && o.status == SyncOpStatus.done);

  SyncState copyWith({
    List<SyncOp>? ops,
    bool? flushing,
    DateTime? lastSyncAt,
  }) => SyncState(
    ops: ops ?? this.ops,
    flushing: flushing ?? this.flushing,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
}

class SyncController extends Notifier<SyncState> {
  static const _kOps = 'pro.sync.ops';
  static const _keepDone = 40;

  @override
  SyncState build() {
    ref.listen(networkProvider.select((n) => n.online), (prev, online) {
      if (online && prev == false) scheduleMicrotask(flush);
    });
    return SyncState(ops: _load());
  }

  List<SyncOp> _load() {
    final raw = ref.read(sharedPrefsProvider)?.getString(_kOps);
    if (raw == null) return const [];
    try {
      return [
        for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          SyncOp.fromJson(j).copyWith(
            // Une synchro interrompue reprend depuis « en attente ».
            status: SyncOp.fromJson(j).status == SyncOpStatus.syncing
                ? SyncOpStatus.pending
                : null,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  void _save() {
    final done = state.ops.where((o) => o.status == SyncOpStatus.done).toList();
    final keep = [
      ...state.ops.where((o) => o.status != SyncOpStatus.done),
      ...done.take(_keepDone),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    ref
        .read(sharedPrefsProvider)
        ?.setString(_kOps, jsonEncode([for (final o in keep) o.toJson()]));
  }

  /// Enregistre une action terrain puis tente l'envoi si le réseau est là.
  /// Renvoie l'Idempotency-Key utilisée.
  String enqueue(String kind, String summary, {String? key}) {
    final k = key ?? newIdempotencyKey();
    if (state.ops.any((o) => o.idempotencyKey == k)) return k;
    final op = SyncOp(
      id: newIdempotencyKey(),
      kind: kind,
      idempotencyKey: k,
      summary: summary,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(ops: [op, ...state.ops]);
    _save();
    if (ref.read(networkProvider).online) scheduleMicrotask(flush);
    return k;
  }

  /// Rejoue les opérations en attente, dans l'ordre terrain.
  Future<void> flush() async {
    if (state.flushing || !ref.read(networkProvider).online) return;
    final queue =
        state.ops
            .where(
              (o) =>
                  o.status == SyncOpStatus.pending ||
                  o.status == SyncOpStatus.error,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (queue.isEmpty) return;
    state = state.copyWith(flushing: true);
    final api = ref.read(proApiProvider);
    for (final op in queue) {
      if (!ref.mounted || !ref.read(networkProvider).online) break;
      _update(op.id, (o) => o.copyWith(status: SyncOpStatus.syncing));
      try {
        await api.replay(op);
        if (!ref.mounted) return;
        _update(
          op.id,
          (o) =>
              o.copyWith(status: SyncOpStatus.done, attempts: o.attempts + 1),
        );
      } on ProApiException catch (e) {
        if (!ref.mounted) return;
        _update(
          op.id,
          (o) => o.copyWith(
            status: SyncOpStatus.error,
            attempts: o.attempts + 1,
            lastError: e.message,
          ),
        );
      } catch (_) {
        if (!ref.mounted) return;
        _update(
          op.id,
          (o) => o.copyWith(
            status: SyncOpStatus.error,
            attempts: o.attempts + 1,
            lastError: 'Erreur inattendue. Nouvel essai automatique.',
          ),
        );
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(flushing: false, lastSyncAt: DateTime.now());
    _save();
  }

  void _update(String id, SyncOp Function(SyncOp) f) {
    state = state.copyWith(
      ops: [for (final o in state.ops) o.id == id ? f(o) : o],
    );
  }

  /// Purge l'historique des opérations déjà synchronisées.
  void clearDone() {
    state = state.copyWith(
      ops: state.ops.where((o) => o.status != SyncOpStatus.done).toList(),
    );
    _save();
  }
}

final syncProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
