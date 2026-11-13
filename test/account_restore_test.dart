import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viajelisto/models/packing_list.dart';
import 'package:viajelisto/models/trip_draft.dart';
import 'package:viajelisto/services/cloud_api.dart';
import 'package:viajelisto/services/storage_service.dart';
import 'package:viajelisto/state/app_controller.dart';

class _AccountCloudApi extends CloudApi {
  _AccountCloudApi(this.savedLists, this.savedTrips) : super('https://test.example');

  final List<PackingList> savedLists;
  final List<TripDraft> savedTrips;
  Map<String, dynamic>? loginRequest;

  @override
  Future<CloudReply> post(String path, Map<String, dynamic> body) async {
    if (path == '/auth/entrar') {
      loginRequest = body;
      token = 'session-token';
      return const CloudReply(data: {'token': 'session-token', 'name': 'Ana'});
    }
    return const CloudReply(error: 'Unexpected request');
  }

  @override
  Future<CloudReply> get(String path) async {
    if (path == '/datos') {
      return CloudReply(
        data: {
          'sincronizado': true,
          'listas': savedLists.map((list) => list.toJson()).toList(),
          'viajes': savedTrips.map((trip) => trip.toJson()).toList(),
        },
      );
    }
    return const CloudReply(error: 'Unexpected request');
  }

  @override
  Future<CloudReply> put(String path, Map<String, dynamic> body) async {
    return const CloudReply(data: {'ok': true});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores the same account data after logout and email/password login', () async {
    SharedPreferences.setMockInitialValues({
      'session_email_v1': 'ana@example.com',
      'session_name_v1': 'Ana',
      'session_token_v1': 'old-token',
      'example_trip_seeded_v1': true,
    });
    final cloud = _AccountCloudApi(
      [
        PackingList(
          id: 'account-list',
          name: 'Lista de Ana',
          iconKey: 'backpack',
          isPreset: false,
          items: [],
        ),
      ],
      [TripDraft(name: 'Viaje guardado', destination: 'Pucón', distance: '250')],
    );
    final storage = StorageService(cloud: cloud);

    await storage.logout();
    final controller = AppController(storage);
    await controller.load();

    final error = await controller.signIn(
      email: 'ana@example.com',
      password: 'secreto1',
    );

    expect(error, isNull);
    expect(cloud.loginRequest, {'email': 'ana@example.com', 'password': 'secreto1'});
    expect(controller.pendingMerge, isNull);
    expect(controller.lists.single.name, 'Lista de Ana');
    expect(controller.trips.single.destination, 'Pucón');
  });
}
