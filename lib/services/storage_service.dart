import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/default_lists.dart';
import '../models/packing_list.dart';
import '../models/trip_draft.dart';
import 'app_database.dart';
import 'cloud_api.dart';

class StorageService {
  StorageService({this.cloud});

  final CloudApi? cloud;
  String? pendingToken;

  bool get usesCloud => cloud != null;
  static const listsKey = 'packing_lists_v1';
  static const listsVersionKey = 'packing_lists_version';
  static const tripsKey = 'trip_drafts_v1';
  static const draftKey = 'trip_draft_v1';

  Future<List<PackingList>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(listsKey);
    if (raw == null) {
      await prefs.setInt(listsVersionKey, DefaultLists.version);
      return DefaultLists.build();
    }

    List<PackingList> lists;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      lists = decoded
          .map((entry) => PackingList.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      lists = DefaultLists.build();
    }

    final version = prefs.getInt(listsVersionKey) ?? 0;
    if (version < DefaultLists.version) {
      final customs = lists.where((list) => !list.isPreset).toList();
      lists = [...DefaultLists.build(), ...customs];
      await saveLists(lists);
      await prefs.setInt(listsVersionKey, DefaultLists.version);
    }
    return lists;
  }

  Future<void> saveLists(List<PackingList> lists) => _writeLists(lists);

  Future<void> _writeLists(List<PackingList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(lists.map((list) => list.toJson()).toList());
    await prefs.setString(listsKey, raw);
  }

  Future<List<TripDraft>> loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(tripsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final trips = decoded
            .map((entry) => TripDraft.fromJson(entry as Map<String, dynamic>))
            .toList();
        if (trips.isNotEmpty) return trips;
      } catch (_) {
        return [TripDraft()];
      }
    }

    final legacy = prefs.getString(draftKey);
    if (legacy == null) return [TripDraft()];
    try {
      return [TripDraft.fromJson(jsonDecode(legacy) as Map<String, dynamic>)];
    } catch (_) {
      return [TripDraft()];
    }
  }

  Future<void> saveTrips(List<TripDraft> trips) => _writeTrips(trips);

  Future<void> _writeTrips(List<TripDraft> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(trips.map((trip) => trip.toJson()).toList());
    await prefs.setString(tripsKey, raw);
  }

  Future<void> open() async {
    if (cloud == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(sessionTokenKey);
    if (token == null || token.isEmpty) {
      cloud!.token = null;
      return;
    }
    cloud!.token = token;
    final me = await cloud!.get('/auth/yo');
    if (me.error != null) {
      if (me.error == 'La sesión expiró.') await logout();
      return;
    }
    final data = me.data ?? {};
    await _setSession(
      data['email'] as String? ?? '',
      data['name'] as String? ?? '',
      photo: data['photo'] as String?,
      phone: data['phone'] as String?,
    );
    await pullCloud();
  }

  Future<void> pushCloud(List<PackingList> lists, List<TripDraft> trips) async {
    if (cloud == null || cloud!.token == null || cloud!.token!.isEmpty) return;
    await cloud!.put('/datos', {
      'listas': lists.map((list) => list.toJson()).toList(),
      'viajes': trips.map((trip) => trip.toJson()).toList(),
    });
  }

  Future<void> pullCloud() async {
    if (cloud == null || cloud!.token == null || cloud!.token!.isEmpty) return;
    final remote = await cloud!.get('/datos');
    if (remote.error != null || remote.data == null) return;
    if (remote.data!['sincronizado'] != true) {
      await pushCloud(await loadLists(), await loadTrips());
      return;
    }
    final rawLists = remote.data!['listas'] as List<dynamic>? ?? [];
    final rawTrips = remote.data!['viajes'] as List<dynamic>? ?? [];
    final lists = rawLists
        .map((entry) => PackingList.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList();
    final trips = rawTrips
        .map((entry) => TripDraft.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList();
    if (lists.isNotEmpty) await _writeLists(lists);
    await _writeTrips(trips.isEmpty ? [TripDraft()] : trips);
  }

  static const sessionTokenKey = 'session_token_v1';
  static const sessionKey = 'session_email_v1';
  static const sessionNameKey = 'session_name_v1';
  static const sessionPhotoKey = 'session_photo_v1';
  static const sessionPhoneKey = 'session_phone_v1';
  static const notificationsKey = 'settings_notifications_v1';
  static const hideEmailKey = 'settings_hide_email_v1';

  Future<String?> sessionEmail() async {
    if (cloud != null && (cloud!.token == null || cloud!.token!.isEmpty)) return null;
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(sessionKey);
    if (email == null || email.isEmpty) return null;
    return email;
  }

  Future<String?> sessionName() async {
    final email = await sessionEmail();
    if (email == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(sessionNameKey);
    if (cached != null && cached.isNotEmpty) return cached;

    final database = await AppDatabase.open();
    final rows = await database.query(
      'users',
      columns: ['name'],
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final name = rows.first['name'] as String?;
    if (name != null && name.isNotEmpty) {
      await prefs.setString(sessionNameKey, name);
    }
    return name;
  }

  Future<String?> sessionPhoto() async {
    final email = await sessionEmail();
    if (email == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final photo = prefs.getString(sessionPhotoKey);
    if (photo == null || photo.isEmpty) return null;
    return photo;
  }

  Future<String?> sessionPhone() async {
    final email = await sessionEmail();
    if (email == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(sessionPhoneKey);
    if (phone == null || phone.isEmpty) return null;
    return phone;
  }

  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationsKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsKey, value);
  }

  Future<bool> hideEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hideEmailKey) ?? false;
  }

  Future<void> setHideEmail(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hideEmailKey, value);
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    if (cleanName.isEmpty) return 'Escribe tu nombre.';
    if (!_looksLikeEmail(cleanEmail)) return 'Escribe un correo válido.';
    if (password.length < 6) return 'La contraseña necesita al menos 6 caracteres.';
    if (cloud != null) {
      final reply = await cloud!.post('/auth/registro', {
        'name': cleanName,
        'email': cleanEmail,
        'password': password,
      });
      if (reply.error != null) return reply.error;
      pendingToken = reply.data?['token'] as String?;
      return null;
    }

    final database = await AppDatabase.open();
    final existing = await database.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) return 'Ese correo ya tiene una cuenta.';

    await database.insert('users', {
      'name': cleanName,
      'email': cleanEmail,
      'password': _hash(password),
    });
    await _setSession(cleanEmail, cleanName);
    return null;
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_looksLikeEmail(cleanEmail)) return 'Escribe un correo válido.';
    if (cloud != null) {
      final reply = await cloud!.post('/auth/entrar', {
        'email': cleanEmail,
        'password': password,
      });
      if (reply.error != null) return reply.error;
      final data = reply.data ?? {};
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) return 'No se pudo entrar.';
      cloud!.token = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionTokenKey, token);
      await _setSession(
        cleanEmail,
        data['name'] as String? ?? '',
        photo: data['photo'] as String?,
        phone: data['phone'] as String?,
      );
      await pullCloud();
      return null;
    }

    final database = await AppDatabase.open();
    final rows = await database.query(
      'users',
      where: 'email = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['password'] != _hash(password)) {
      return 'Correo o contraseña incorrectos.';
    }
    await _setSession(
      cleanEmail,
      rows.first['name'] as String? ?? '',
      photo: rows.first['photo'] as String?,
      phone: rows.first['phone'] as String?,
    );
    return null;
  }

  Future<String?> updateName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return 'Escribe tu nombre.';
    final email = await sessionEmail();
    if (email == null) return 'Inicia sesión de nuevo.';
    if (cloud != null) {
      final reply = await cloud!.patch('/auth/perfil', {'name': cleanName});
      if (reply.error != null) return reply.error;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionNameKey, cleanName);
      return null;
    }

    final database = await AppDatabase.open();
    await database.update(
      'users',
      {'name': cleanName},
      where: 'email = ?',
      whereArgs: [email],
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionNameKey, cleanName);
    return null;
  }

  Future<String?> updatePhoto(String? photo) async {
    final email = await sessionEmail();
    if (email == null) return 'Inicia sesión de nuevo.';
    final clean = (photo == null || photo.isEmpty) ? null : photo;
    if (cloud != null) {
      final reply = await cloud!.put('/auth/foto', {'photo': clean});
      if (reply.error != null) return reply.error;
      final prefs = await SharedPreferences.getInstance();
      if (clean == null) {
        await prefs.remove(sessionPhotoKey);
      } else {
        await prefs.setString(sessionPhotoKey, clean);
      }
      return null;
    }

    final database = await AppDatabase.open();
    await database.update(
      'users',
      {'photo': clean},
      where: 'email = ?',
      whereArgs: [email],
    );
    final prefs = await SharedPreferences.getInstance();
    if (clean == null) {
      await prefs.remove(sessionPhotoKey);
    } else {
      await prefs.setString(sessionPhotoKey, clean);
    }
    return null;
  }

  Future<String?> updateProfile({
    required String name,
    required String phone,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    if (cleanName.isEmpty) return 'Escribe tu nombre.';
    if (cleanPhone.isNotEmpty && cleanPhone.replaceAll(RegExp(r'\D'), '').length < 8) {
      return 'Escribe un teléfono válido.';
    }
    final email = await sessionEmail();
    if (email == null) return 'Inicia sesión de nuevo.';
    if (cloud != null) {
      final reply = await cloud!.patch('/auth/perfil', {
        'name': cleanName,
        'phone': cleanPhone,
      });
      if (reply.error != null) return reply.error;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionNameKey, cleanName);
      if (cleanPhone.isEmpty) {
        await prefs.remove(sessionPhoneKey);
      } else {
        await prefs.setString(sessionPhoneKey, cleanPhone);
      }
      return null;
    }

    final database = await AppDatabase.open();
    await database.update(
      'users',
      {'name': cleanName, 'phone': cleanPhone.isEmpty ? null : cleanPhone},
      where: 'email = ?',
      whereArgs: [email],
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionNameKey, cleanName);
    if (cleanPhone.isEmpty) {
      await prefs.remove(sessionPhoneKey);
    } else {
      await prefs.setString(sessionPhoneKey, cleanPhone);
    }
    return null;
  }

  Future<String?> changePassword({
    required String current,
    required String next,
    required String confirm,
  }) async {
    if (next.length < 6) return 'La contraseña necesita al menos 6 caracteres.';
    if (next != confirm) return 'Las contraseñas no coinciden.';
    final email = await sessionEmail();
    if (email == null) return 'Inicia sesión de nuevo.';
    if (cloud != null) {
      final reply = await cloud!.post('/auth/cambiar', {
        'actual': current,
        'nueva': next,
      });
      return reply.error;
    }

    final database = await AppDatabase.open();
    final rows = await database.query(
      'users',
      columns: ['password'],
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['password'] != _hash(current)) {
      return 'La contraseña actual no es correcta.';
    }
    await database.update(
      'users',
      {'password': _hash(next)},
      where: 'email = ?',
      whereArgs: [email],
    );
    return null;
  }

  Future<String?> resetPassword({
    required String email,
    required String password,
    required String confirm,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_looksLikeEmail(cleanEmail)) return 'Escribe un correo válido.';
    if (password.length < 6) return 'La contraseña necesita al menos 6 caracteres.';
    if (password != confirm) return 'Las contraseñas no coinciden.';

    final database = await AppDatabase.open();
    final rows = await database.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (rows.isEmpty) return 'No hay una cuenta con ese correo.';
    await database.update(
      'users',
      {'password': _hash(password)},
      where: 'email = ?',
      whereArgs: [cleanEmail],
    );
    return null;
  }

  Future<String?> confirmEmail(String token) async {
    if (cloud == null) return 'El servidor no está activo.';
    final reply = await cloud!.post('/auth/confirmar', {'token': token});
    if (reply.error != null) return reply.error;
    pendingToken = null;
    return null;
  }

  Future<String?> requestRecovery(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_looksLikeEmail(cleanEmail)) return 'Escribe un correo válido.';
    if (cloud == null) return 'El servidor no está activo.';
    final reply = await cloud!.post('/auth/recuperar', {'email': cleanEmail});
    if (reply.error != null) return reply.error;
    pendingToken = reply.data?['token'] as String?;
    return null;
  }

  Future<String?> completeRecovery({
    required String token,
    required String password,
    required String confirm,
  }) async {
    if (password.length < 6) return 'La contraseña necesita al menos 6 caracteres.';
    if (password != confirm) return 'Las contraseñas no coinciden.';
    if (cloud == null) return 'El servidor no está activo.';
    final reply = await cloud!.post('/auth/restablecer', {
      'token': token,
      'password': password,
    });
    if (reply.error != null) return reply.error;
    pendingToken = null;
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionTokenKey);
    await prefs.remove(sessionKey);
    await prefs.remove(sessionNameKey);
    await prefs.remove(sessionPhotoKey);
    await prefs.remove(sessionPhoneKey);
    cloud?.token = null;
    await _writeLists(DefaultLists.build());
    await _writeTrips([TripDraft()]);
    await prefs.setInt(listsVersionKey, DefaultLists.version);
  }

  Future<void> _setSession(
    String email,
    String name, {
    String? photo,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionKey, email);
    await prefs.setString(sessionNameKey, name);
    if (photo == null || photo.isEmpty) {
      await prefs.remove(sessionPhotoKey);
    } else {
      await prefs.setString(sessionPhotoKey, photo);
    }
    if (phone == null || phone.isEmpty) {
      await prefs.remove(sessionPhoneKey);
    } else {
      await prefs.setString(sessionPhoneKey, phone);
    }
  }

  bool _looksLikeEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _hash(String password) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode('travel-equality::$password')) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
