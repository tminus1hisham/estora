import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/state_views.dart';
import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/date_format.dart';
import '../../../domain/entities/tenant.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../navigation/routes.dart';
import '../application/notification_controller.dart';

/// Section 49's notification list.
///
/// Each entry carries a target, so tapping a "your invoice is due" alert goes
/// to that invoice rather than dropping the tenant on a list to find it.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);
    final hasUnread =
        notifications.value?.any((notification) => !notification.isRead) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: hasUnread
                ? () =>
                      ref.read(notificationListProvider.notifier).markAllRead()
                : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: switch (notifications) {
        AsyncLoading() when !notifications.hasValue => const LoadingView(),
        AsyncError(:final error) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.read(notificationListProvider.notifier).refresh(),
        ),
        _ => _NotificationList(items: notifications.requireValue),
      },
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.items});

  final List<NotificationItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Nothing yet',
        message:
            'Alerts about bookings, invoices, payments and your lease will '
            'appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationListProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _NotificationTile(item: items[index]),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = _appearance(context);

    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: item.isRead
            ? Colors.transparent
            : scheme.primaryContainer.withValues(alpha: 0.32),
        border: Border(
          left: BorderSide(
            color: item.isRead ? Colors.transparent : scheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () {
            if (!item.isRead) {
              ref.read(notificationListProvider.notifier).markRead(item.id);
            }
            _navigate(context);
          },
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap.h4,
              // Section 50: body text comes rendered from a server-side template,
              // so wording can change without an app release.
              Text(item.body),
              Gap.h4,
              Text(
                AppDate.dateTime(item.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          trailing: item.isRead
              ? null
              : Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
          isThreeLine: true,
        ),
      ),
    );
  }

  (IconData, Color) _appearance(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = context.statusColors;

    return switch (item.type) {
      NotificationType.bookingCreated ||
      NotificationType.bookingExpiring ||
      NotificationType.bookingExpired => (
        Icons.event_available_outlined,
        status.progress,
      ),
      NotificationType.paymentSuccess => (
        Icons.check_circle_outline_rounded,
        status.positive,
      ),
      NotificationType.paymentFailed => (
        Icons.error_outline_rounded,
        status.danger,
      ),
      NotificationType.invoiceGenerated ||
      NotificationType.invoiceDue => (Icons.receipt_long_outlined, status.info),
      NotificationType.invoiceOverdue => (
        Icons.warning_amber_rounded,
        status.danger,
      ),
      NotificationType.leaseReady ||
      NotificationType.leaseSigned ||
      NotificationType.leaseActivated => (
        Icons.description_outlined,
        status.positive,
      ),
      NotificationType.leaseExpiring => (
        Icons.schedule_outlined,
        status.warning,
      ),
      NotificationType.documentRequired => (
        Icons.upload_file_outlined,
        status.warning,
      ),
      NotificationType.unknown => (
        Icons.notifications_none_rounded,
        colors.onSurfaceVariant,
      ),
    };
  }

  void _navigate(BuildContext context) {
    final id = item.targetId;
    if (id == null) return;

    switch (item.target) {
      case NotificationTarget.booking:
        context.pushNamed(
          Routes.bookingStatus,
          pathParameters: {'bookingId': id},
        );
      case NotificationTarget.lease:
        context.pushNamed(Routes.leaseDetail, pathParameters: {'leaseId': id});
      case NotificationTarget.invoice:
        context.pushNamed(
          Routes.invoiceDetail,
          pathParameters: {'invoiceId': id},
        );
      case NotificationTarget.payment:
        context.pushNamed(
          Routes.paymentStatus,
          pathParameters: {'paymentId': id},
        );
      case NotificationTarget.document:
        context.pushNamed(Routes.documents);
      case NotificationTarget.none:
        break;
    }
  }
}
