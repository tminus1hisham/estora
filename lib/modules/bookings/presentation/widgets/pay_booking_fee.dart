import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/booking.dart';
import '../../../payments/presentation/widgets/mpesa_payment_sheet.dart';
import '../../application/booking_controller.dart';

/// Opens the M-Pesa sheet for [booking]'s fee (section 24).
///
/// One place for every "Pay now" on a booking to go through, so the list row
/// and the status screen raise the same prompt against the same record. The
/// figure is the booking's own [Booking.bookingFee]; the sheet shows it and
/// sends it back, and nothing in between touches it.
///
/// Resolves to `true` once the server has confirmed the fee. The list is
/// refreshed either way: a prompt answered after the sheet was closed still
/// changes what the row should say.
Future<bool?> payBookingFee(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  final actions = ref.read(bookingActionsProvider);
  final where = [
    if (booking.unitNumber != null) 'Unit ${booking.unitNumber}',
    ?booking.propertyName,
  ];

  final paid = await showMpesaPaymentSheet(
    context,
    MpesaPaymentRequest(
      title: 'Booking fee',
      subtitle: where.isEmpty ? null : where.join(' · '),
      amount: booking.bookingFee,
      phoneNumber: booking.phoneNumber,
      send: (phoneNumber) =>
          actions.requestFeePrompt(booking, phoneNumber: phoneNumber),
      confirmPaid: () => actions.confirmFeePaid(booking.id),
      restart: () => actions.restartFeePrompt(booking.id),
    ),
  );

  if (paid != true) {
    ref.invalidate(bookingListProvider);
    ref.invalidate(bookingDetailProvider(booking.id));
  }
  return paid;
}
