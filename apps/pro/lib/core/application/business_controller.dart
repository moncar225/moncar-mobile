// ============================================================
// MON CAR PRO — Agents BUSINESS : remises et restitutions (LOC-004).
//
// Enchaînement imposé par le CDC : la remise validée déclenche la
// location active ; la restitution contrôlée permet la clôture. Les
// frais définitifs et le règlement fournisseur sont calculés serveur.
// ============================================================

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../domain/models.dart';
import 'app_providers.dart';
import 'sync_controller.dart';

/// Relevé saisi par l'agent (remise ou restitution).
class RentalReport {
  const RentalReport({
    required this.km,
    required this.fuel,
    required this.checklist,
    required this.photos,
    required this.notes,
    this.idNote = '',
    this.feesEstimate = 0,
    this.clientSigned = false,
  });

  final int km;
  final int fuel;
  final List<bool?> checklist;
  final Set<String> photos;
  final String notes;
  final String idNote;
  final int feesEstimate;
  final bool clientSigned;
}

class BusinessController extends Notifier<List<RentalTask>> {
  @override
  List<RentalTask> build() => demoRentalTasks();

  RentalTask byId(String id) => state.firstWhere((t) => t.id == id);

  /// Valide la remise / restitution. En ligne : preuve générée par le
  /// serveur. Hors ligne : relevé mis en file, preuve à la synchro.
  Future<String?> submit(String taskId, RentalReport report) async {
    final task = byId(taskId);
    final online = ref.read(networkProvider).online;
    String? proof;
    if (online) {
      proof = await ref.read(proApiProvider).submitRentalTask(task);
      if (!ref.mounted) return proof;
    }
    ref
        .read(syncProvider.notifier)
        .enqueue(
          task.type == RentalTaskType.remise ? 'REMISE' : 'RESTITUTION',
          '${task.type.label} ${task.ref} — ${report.km} km · ${report.fuel} %',
          key: '${task.type.name}-${task.id}',
        );
    state = [
      for (final t in state)
        t.id == taskId
            ? t.copyWith(status: RentalTaskStatus.termine, proofRef: proof)
            : t,
    ];
    return proof;
  }
}

final businessProvider = NotifierProvider<BusinessController, List<RentalTask>>(
  BusinessController.new,
);
