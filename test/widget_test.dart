import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viajelisto/main.dart';
import 'package:viajelisto/models/trip_draft.dart';
import 'package:viajelisto/services/storage_service.dart';
import 'package:viajelisto/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('muestra las listas de playa, camping y bosque', (tester) async {
    SharedPreferences.setMockInitialValues({
      'session_email_v1': 'ana@correo.com',
      'session_name_v1': 'Ana',
    });
    await tester.pumpWidget(const ViajeListoApp());
    await tester.pumpAndSettle();

    expect(find.text('TravelEquality'), findsOneWidget);
    await tester.tap(find.text('Equipaje'));
    await tester.pumpAndSettle();
    expect(find.text('Playa'), findsWidgets);
    expect(find.text('Camping'), findsOneWidget);
    expect(find.text('Bosque'), findsOneWidget);
  });

  testWidgets('abre la sección de perfil', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'session_email_v1': 'ana@correo.com',
      'session_name_v1': 'Ana',
    });
    await tester.pumpWidget(const ViajeListoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsWidgets);
    expect(find.text('ana@correo.com'), findsOneWidget);
    expect(find.text('Sin teléfono'), findsOneWidget);
    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Privacidad'), 300);
    expect(find.text('Privacidad'), findsOneWidget);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Seguridad'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Ayuda'), 300);
    expect(find.text('AYUDA Y NOTIFICACIONES'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Ayuda'));
    await tester.pumpAndSettle();
    expect(
      find.text('Elige Playa, Camping o Bosque, marca lo que ya empacaste y crea listas nuevas.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Editar perfil'), -400);
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar cambios'), findsOneWidget);
  });

  testWidgets('pide iniciar sesión si no hay una cuenta abierta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ViajeListoApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));

    expect(find.text('TravelEquality'), findsOneWidget);
    await tester.tap(find.text('Cuenta'));
    await tester.pump();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('Guardar contraseña'), findsOneWidget);
  });

  testWidgets('el viaje genera el texto para compartir', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'session_email_v1': 'ana@correo.com',
      'session_name_v1': 'Ana',
    });
    await tester.pumpWidget(const ViajeListoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Viaje'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '100');
    await tester.enterText(fields.at(1), '10');
    await tester.enterText(fields.at(2), '1000');
    await tester.enterText(fields.at(3), '2');
    await tester.enterText(fields.at(4), '5000');
    final amounts = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Monto',
    );
    for (var i = 0; i < amounts.evaluate().length; i++) {
      await tester.ensureVisible(amounts.at(i));
      await tester.enterText(amounts.at(i), '');
    }
    await tester.pump();

    expect(find.text('Compartir resumen'), findsOneWidget);
    await tester.tap(find.text('Compartir resumen'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen del viaje'), findsOneWidget);
    expect(find.textContaining('Pasajero 1 (conductor)'), findsOneWidget);
    expect(find.textContaining(r'$7.500'), findsWidgets);
  });

  test('guarda listas y el cálculo aunque se vuelva a abrir la app', () async {
    final first = AppController(StorageService());
    await first.load();
    await first.addList('Termas');
    await first.addItem(
      first.lists.firstWhere((list) => list.name == 'Termas').id,
      'Toalla',
    );
    await first.toggleItem(
      first.lists.firstWhere((list) => list.name == 'Playa').id,
      'preset-playa-0',
      true,
    );
    await first.updateTrips([
      first.trips.first
        ..distance = '80'
        ..passengers = 3,
    ]);

    final second = AppController(StorageService());
    await second.load();

    final termas = second.lists.firstWhere((list) => list.name == 'Termas');
    final playa = second.lists.firstWhere((list) => list.name == 'Playa');
    expect(termas.items.single.name, 'Toalla');
    expect(termas.items.single.quantity, 1);
    await first.setItemQuantity(termas.id, termas.items.single.id, 3);
    final third = AppController(StorageService());
    await third.load();
    expect(
      third.lists.firstWhere((list) => list.name == 'Termas').items.single.quantity,
      3,
    );
    expect(playa.items.first.name, 'Traje de baño');
    expect(playa.items.any((item) => item.name == 'Quitasol'), isTrue);
    expect(playa.items.first.packed, isTrue);
    expect(second.trips.first.distance, '80');
    expect(second.trips.first.passengers, 3);

    await second.restorePresets();
    expect(second.lists.any((list) => list.name == 'Termas'), isTrue);
    expect(
      second.lists.firstWhere((list) => list.id == 'preset-playa').items.first.packed,
      isFalse,
    );
  });

  test('la primera visita abre el ejemplo de la costa', () async {
    final controller = AppController(StorageService());
    await controller.load();
    expect(controller.trips.first.name, 'Fin de semana en la costa');
    expect(controller.trips.first.destination, 'Valparaíso');
    expect(controller.trips.first.distance, '240');
    expect(
      controller.lists.firstWhere((list) => list.id == 'preset-playa').items.first.packed,
      isTrue,
    );
  });

  test('reemplaza una sola vez el viaje en blanco por el ejemplo', () async {
    SharedPreferences.setMockInitialValues({
      'trip_drafts_v1': jsonEncode([TripDraft().toJson()]),
    });
    final first = AppController(StorageService());
    await first.load();
    final trip = first.trips.first;
    expect(trip.name, 'Fin de semana en la costa');
    expect(trip.origin, 'Santiago');
    expect(trip.destination, 'Valparaíso');
    expect(trip.distance, '240');
    expect(trip.consumption, '12');
    expect(trip.fuelPrice, '1400');
    expect(trip.tolls, '8000');
    expect(trip.passengers, 3);
    expect(trip.budget, '15000');
    expect(trip.extras.single.name, 'Snacks para el camino');
    expect(trip.extras.single.amount, '6000');
    expect(trip.departDate, '13-11-2026');
    expect(trip.returnDate, '15-11-2026');

    trip.destination = '';
    trip.distance = '';
    await first.updateTrips([trip]);

    final second = AppController(StorageService());
    await second.load();
    expect(second.trips.first.destination, isEmpty);
    expect(second.trips.first.distance, isEmpty);
    expect(second.trips.first.name, 'Fin de semana en la costa');
  });

  test('no pisa un viaje que ya tiene destino o kilómetros', () async {
    SharedPreferences.setMockInitialValues({
      'trip_drafts_v1': jsonEncode([
        TripDraft(name: 'Sur', origin: 'Temuco', destination: 'Pucón', passengers: 4).toJson(),
      ]),
    });
    final withDestination = AppController(StorageService());
    await withDestination.load();
    expect(withDestination.trips.first.destination, 'Pucón');
    expect(withDestination.trips.first.name, 'Sur');
    expect(withDestination.trips.first.passengers, 4);
    expect(
      withDestination.lists.firstWhere((list) => list.id == 'preset-playa').items.first.packed,
      isFalse,
    );

    SharedPreferences.setMockInitialValues({
      'trip_drafts_v1': jsonEncode([TripDraft(distance: '50').toJson()]),
    });
    final withDistance = AppController(StorageService());
    await withDistance.load();
    expect(withDistance.trips.first.distance, '50');
    expect(withDistance.trips.first.destination, isEmpty);
    expect(withDistance.trips.first.name, isEmpty);
  });

  test('guarda la cuenta en la base de datos', () async {
    final storage = StorageService();
    final email = 'ana${DateTime.now().microsecondsSinceEpoch}@correo.com';

    expect(
      await storage.register(name: 'Ana', email: email, password: 'secreto1'),
      isNull,
    );
    await storage.logout();
    expect(await storage.sessionEmail(), isNull);

    expect(await storage.login(email: email, password: 'secreto1'), isNull);
    expect(await storage.sessionEmail(), email);
    expect(await storage.sessionName(), 'Ana');
    expect(await storage.updateName('Ana María'), isNull);
    expect(await storage.sessionName(), 'Ana María');
    expect(await storage.updatePhoto('aG9sYQ=='), isNull);
    expect(await storage.sessionPhoto(), 'aG9sYQ==');
    expect(await storage.updatePhoto(null), isNull);
    expect(await storage.sessionPhoto(), isNull);
    expect(
      await storage.updateProfile(name: 'Ana Gómez', phone: '+56911112222'),
      isNull,
    );
    expect(await storage.sessionName(), 'Ana Gómez');
    expect(await storage.sessionPhone(), '+56911112222');
    expect(
      await storage.changePassword(current: 'secreto1', next: 'secreto2', confirm: 'secreto2'),
      isNull,
    );
    await storage.logout();
    expect(await storage.login(email: email, password: 'secreto1'), isNotNull);
    expect(await storage.login(email: email, password: 'secreto2'), isNull);
    expect(
      await storage.resetPassword(email: email, password: 'nueva123', confirm: 'nueva123'),
      isNull,
    );
    expect(await storage.login(email: email, password: 'secreto2'), isNotNull);
    expect(await storage.login(email: email, password: 'nueva123'), isNull);
  });
}
