import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../services/providers.dart';
import '../../leases/application/lease_controller.dart';
import 'support_models.dart';

/// The status filter on the tickets screen. Null is "All".
final ticketFilterProvider =
    NotifierProvider<TicketFilterController, TicketStatus?>(
      TicketFilterController.new,
    );

class TicketFilterController extends Notifier<TicketStatus?> {
  @override
  TicketStatus? build() => null;

  void select(TicketStatus? status) => state = status;
}

/// Every ticket the tenant has raised, newest first, from `tickets/get/all`.
///
/// The write routes answer with a bare acknowledgement, so each write is
/// followed by a fresh read: the list on screen is always the server's, never
/// a local guess at what the new ticket looks like.
final supportTicketsProvider =
    AsyncNotifierProvider<SupportTicketController, List<SupportTicket>>(
      SupportTicketController.new,
    );

class SupportTicketController extends AsyncNotifier<List<SupportTicket>> {
  @override
  Future<List<SupportTicket>> build() async {
    final result = await ref.read(supportRepositoryProvider).listTickets();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    final scope = ref;
    final next = await AsyncValue.guard(build);
    if (scope.mounted) state = next;
  }

  Future<Result<void>> raise(TicketDraft draft) =>
      _write(ref.read(supportRepositoryProvider).raiseTicket(draft));

  Future<Result<void>> edit(String ticketId, TicketDraft draft) =>
      _write(ref.read(supportRepositoryProvider).updateTicket(ticketId, draft));

  /// Closes a ticket from the tenant's side. The remark is what the desk
  /// reads as the reason, so an empty one is given a plain default.
  Future<Result<void>> close(String ticketId, {String remarks = ''}) {
    final note = remarks.trim();
    return _write(
      ref
          .read(supportRepositoryProvider)
          .closeTicket(
            ticketId,
            status: TicketStatus.closed,
            remarks: note.isEmpty ? 'Closed by the tenant.' : note,
          ),
    );
  }

  /// Waits for the write, then rereads the list if it went through. A failed
  /// reread leaves the old list in place: the write itself succeeded, and
  /// that is what the caller is told.
  Future<Result<void>> _write(Future<Result<void>> write) async {
    final result = await write;
    if (result.isOk) {
      final fresh = await AsyncValue.guard(build);
      if (fresh.hasValue) state = fresh;
    }
    return result;
  }
}

/// The spaces a ticket can be about, one per unit on the tenant's leases.
///
/// Live leases lead. A tenant whose only lease is signed but not yet active
/// still has a unit to talk about, so the rest are offered when no lease is
/// live — anything is better than a form with nowhere to send it.
final ticketSpacesProvider = FutureProvider<List<TicketSpace>>((ref) async {
  final leases = await ref.watch(leaseListProvider.future);
  final current = leases.where((lease) => lease.status.isCurrent).toList();

  final spaces = <String, TicketSpace>{};
  for (final lease in current.isEmpty ? leases : current) {
    if (lease.unitId.isEmpty) continue;
    spaces.putIfAbsent(
      lease.unitId,
      () => TicketSpace(
        propertyId: lease.propertyId,
        propertyName: lease.propertyName ?? 'Your property',
        unitId: lease.unitId,
        unitNumber: lease.unitNumber,
      ),
    );
  }
  return spaces.values.toList(growable: false);
});
