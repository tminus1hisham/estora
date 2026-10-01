import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../domain/entities/tenant.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../services/providers.dart';

/// Badge count for the home screen's bell icon.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final result = await ref.watch(notificationRepositoryProvider).unreadCount();
  return result.valueOrNull ?? 0;
});

/// Section 49's notification list.
final notificationListProvider =
    AsyncNotifierProvider<NotificationListController, List<NotificationItem>>(
      NotificationListController.new,
    );

class NotificationListController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    final result = await ref
        .read(notificationRepositoryProvider)
        .listNotifications();
    return switch (result) {
      Ok(:final value) => value.items,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> refresh() async {
    final scope = ref;
    final next = await AsyncValue.guard(build);
    if (scope.mounted) state = next;
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markRead(String notificationId) async {
    await ref.read(notificationRepositoryProvider).markRead(notificationId);
    await refresh();
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    await refresh();
  }
}

/// Section 49's channels, as a tenant preference.
final notificationChannelsProvider =
    AsyncNotifierProvider<
      NotificationChannelsController,
      Set<NotificationChannel>
    >(NotificationChannelsController.new);

class NotificationChannelsController
    extends AsyncNotifier<Set<NotificationChannel>> {
  @override
  Future<Set<NotificationChannel>> build() async {
    final result = await ref
        .read(notificationRepositoryProvider)
        .getChannelPreferences();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  Future<void> toggle(NotificationChannel channel, bool enabled) async {
    final current = <NotificationChannel>{...?state.value};
    if (enabled) {
      current.add(channel);
    } else {
      current.remove(channel);
    }

    // Optimistic: the switch should move under the tenant's finger rather than
    // waiting for a round trip. Reverted below if the server refuses.
    state = AsyncData(current);

    final result = await ref
        .read(notificationRepositoryProvider)
        .setChannelPreferences(current);
    if (result.isErr) state = await AsyncValue.guard(build);
  }
}
