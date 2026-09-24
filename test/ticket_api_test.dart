import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estora/core/error/result.dart';
import 'package:estora/domain/entities/support_ticket.dart';
import 'package:estora/services/remote/api_client.dart';
import 'package:estora/services/remote/endpoints.dart';
import 'package:estora/services/remote/remote_repositories.dart';
import 'package:estora/storage/token_store.dart';

/// Support tickets against the live contract's four `Tickets` routes.
///
/// Pinned: the list reads `Tickets` as the contract carries them and keeps
/// only this account's; a raise and an edit send `CreateTicketRequest` with
/// the ids as integers; closing sends status and remarks in the query, not a
/// body.
void main() {
  const account = {'id': 42, 'userId': 'user-guid', 'userRole': 'Tenant'};

  Map<String, Object?> ticket(
    int id, {
    String createdById = 'user-guid',
    String status = 'Open',
    String createdAt = '2026-09-20T09:00:00Z',
  }) => {
    'id': id,
    'propertyId': 3,
    'propertyName': 'Sarit Centre',
    'unitId': 11,
    'ticketType': 'Maintenance',
    'comment': 'The tap in the wash area drips all night.',
    'attachments': '',
    'status': status,
    'approvalRemarks': '',
    'approvedByName': '',
    'approvedById': '',
    'createdById': createdById,
    'createdByName': 'Amina',
    'createdAt': createdAt,
    'updatedAt': createdAt,
  };

  ({RemoteSupportRepository tickets, List<RequestOptions> requests, Dio dio})
  server(Object answer) {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
    );
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final data = switch (request.path) {
            Endpoints.account => account,
            Endpoints.tickets => answer,
            _ => const {'success': true, 'message': 'Done'},
          };
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        },
      ),
    );
    final api = ApiClient(tokenStore: _Tokens(), dio: dio);
    return (
      tickets: RemoteSupportRepository(api, AccountIdentity(api)),
      requests: requests,
      dio: dio,
    );
  }

  test('the list is read as the contract carries it, newest first', () async {
    final s = server([
      ticket(1, createdAt: '2026-09-01T09:00:00Z'),
      ticket(2, status: 'Closed'),
    ]);
    addTearDown(s.dio.close);

    final result = await s.tickets.listTickets();
    final list = result.valueOrNull!;

    expect(list.map((t) => t.id), ['2', '1']);
    expect(list.first.status, TicketStatus.closed);
    expect(list.last.category, SupportCategory.maintenance);
    expect(list.last.propertyName, 'Sarit Centre');
    expect(list.last.unitId, '11');
    // Empty strings on the wire are nothing, not a blank answer.
    expect(list.last.approvalRemarks, isNull);
    expect(list.last.reference, 'TKT-1');
  });

  test("only this account's tickets are kept", () async {
    final s = server([ticket(1), ticket(2, createdById: 'other-guid')]);
    addTearDown(s.dio.close);

    final result = await s.tickets.listTickets();

    expect(result.valueOrNull!.map((t) => t.id), ['1']);
  });

  test('raising sends CreateTicketRequest with integer ids', () async {
    final s = server(const <Object>[]);
    addTearDown(s.dio.close);

    final result = await s.tickets.raiseTicket(
      const TicketDraft(
        category: SupportCategory.utilities,
        comment: 'Corridor lights out since Tuesday.',
        propertyId: '3',
        propertyName: 'Sarit Centre',
        unitId: '11',
      ),
    );

    expect(result, isA<Ok<void>>());
    final request = s.requests.single;
    expect(request.method, 'POST');
    expect(request.path, Endpoints.createTicket);
    expect(request.data, {
      'comment': 'Corridor lights out since Tuesday.',
      'ticketType': 'Utilities',
      'attachments': '',
      'propertyId': 3,
      'propertyName': 'Sarit Centre',
      'unitId': 11,
    });
  });

  test('an edit PUTs the whole request to the ticket', () async {
    final s = server(const <Object>[]);
    addTearDown(s.dio.close);

    await s.tickets.updateTicket(
      '5',
      const TicketDraft(
        category: SupportCategory.billing,
        comment: 'The service charge doubled this month.',
        propertyId: '3',
        propertyName: 'Sarit Centre',
        unitId: '11',
      ),
    );

    final request = s.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, Endpoints.updateTicket('5'));
    expect((request.data as Map)['ticketType'], 'Billing');
  });

  test('closing sends status and remarks in the query', () async {
    final s = server(const <Object>[]);
    addTearDown(s.dio.close);

    await s.tickets.closeTicket(
      '5',
      status: TicketStatus.closed,
      remarks: 'Fixed, thank you.',
    );

    final request = s.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, Endpoints.closeTicket('5'));
    expect(request.queryParameters, {
      'status': 'Closed',
      'remarks': 'Fixed, thank you.',
    });
  });

  test('status strings fold onto the four states', () {
    expect(TicketStatus.fromApi('In Progress'), TicketStatus.inProgress);
    expect(TicketStatus.fromApi('APPROVED'), TicketStatus.inProgress);
    expect(TicketStatus.fromApi('resolved'), TicketStatus.resolved);
    expect(TicketStatus.fromApi('Rejected'), TicketStatus.closed);
    expect(TicketStatus.fromApi('Pending'), TicketStatus.open);
    expect(TicketStatus.fromApi(null), TicketStatus.open);
  });
}

class _Tokens implements TokenStore {
  @override
  Future<AuthTokens?> read() async => null;
  @override
  Future<void> write(AuthTokens value) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}
