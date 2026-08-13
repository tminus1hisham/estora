import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../domain/entities/lease.dart';

/// How far through its term a lease has run, 0–1.
///
/// A term is the one thing about a lease that is genuinely a proportion, which
/// is why it is the only thing on these screens drawn as a bar. A lease that
/// has not started yet reads as empty; one that has ended reads as full.
double leaseTermProgress(Lease lease, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final total = lease.endDate.difference(lease.startDate).inSeconds;
  // A same-day term is a server oddity, not something to divide by.
  if (total <= 0) return today.isBefore(lease.startDate) ? 0 : 1;
  final elapsed = today.difference(lease.startDate).inSeconds;
  return (elapsed / total).clamp(0.0, 1.0);
}

/// What is left of the term, in the fewest words that are still true.
String leaseTermCaption(Lease lease, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (lease.startDate.isAfter(today)) {
    return 'Starts ${AppDate.short(lease.startDate)}';
  }

  final days = lease.daysUntilExpiry;
  if (days < 0) return 'Ended ${AppDate.short(lease.endDate)}';
  if (days == 0) return 'Ends today';
  if (days == 1) return '1 day left';
  if (days <= 60) return '$days days left';

  final months = days ~/ 30;
  return '$months months left';
}

/// The tone the term should be drawn in.
///
/// The lease's own status carries it until the end is in sight, at which point
/// how close the end is matters more than what the status is called.
StatusTone leaseTermTone(Lease lease) {
  if (!lease.status.isCurrent) return lease.status.tone;
  final days = lease.daysUntilExpiry;
  if (days < 0) return StatusTone.danger;
  if (days <= 30) return StatusTone.danger;
  if (days <= 90) return StatusTone.warning;
  return StatusTone.positive;
}

/// `5th`, for the day of the month rent falls due (section 34).
String ordinalDay(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}
