import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viajelisto/main.dart';
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
    expect(find.text('Playa'), findsWidgets);
    expect(find.text('Camping'), findsOneWidget);
    expect(find.text('Bosque'), findsOneWidget);
  });

  testWidgets('abre la sección de perfil', (tester) async {
    SharedPreferences.setMockInitialValues({
      'session_email_v1': 'ana@correo.com',
      'session_name_v1': 'Ana',
    });
    await tester.pumpWidget(const ViajeListoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsWidgets);
    expect(find.text('ana@correo.com'), findsOneWidget);
    expect(find.text('Sin teléfono'), findsOneWidget);
    expect(find.text('Editar perfil'), findsOneWidget);
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

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('TravelEquality'), findsOneWidget);

    await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('Guardar contraseña'), findsOneWidget);
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
