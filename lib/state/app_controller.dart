import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/default_lists.dart';
import '../models/packing_item.dart';
import '../models/packing_list.dart';
import '../models/trip_draft.dart';
import '../services/storage_service.dart';

class AppController extends ChangeNotifier {
  AppController(this._storage);

  final StorageService _storage;
  List<PackingList> lists = [];
  List<TripDraft> trips = [TripDraft()];
  bool loading = true;
  String? sessionEmail;
  String? sessionName;
  String? sessionPhoto;
  String? sessionPhone;
  bool notificationsEnabled = true;
  bool hideEmail = false;

  bool get signedIn => sessionEmail != null;
  bool get usesCloud => _storage.usesCloud;
  String? pendingToken;

  Future<void> _persist() async {
    await _storage.saveLists(lists);
    await _storage.saveTrips(trips);
    await _storage.pushCloud(lists, trips);
  }

  Future<void> load() async {
    try {
      await _storage.open();
      lists = await _storage.loadLists();
      trips = await _storage.loadTrips();
      sessionEmail = await _storage.sessionEmail();
      sessionName = await _storage.sessionName();
      sessionPhoto = await _storage.sessionPhoto();
      sessionPhone = await _storage.sessionPhone();
      notificationsEnabled = await _storage.notificationsEnabled();
      hideEmail = await _storage.hideEmail();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  PackingList? listById(String id) {
    for (final list in lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  Future<void> addList(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    lists = [
      ...lists,
      PackingList(
        id: _id(),
        name: trimmed,
        iconKey: 'custom',
        isPreset: false,
        items: [],
      ),
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> renameList(String id, String name) async {
    final trimmed = name.trim();
    final list = listById(id);
    if (trimmed.isEmpty || list == null) return;
    list.name = trimmed;
    notifyListeners();
    await _persist();
  }

  Future<void> deleteList(String id) async {
    lists = lists.where((list) => list.id != id).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> addItem(String listId, String name, {int quantity = 1}) async {
    final trimmed = name.trim();
    final list = listById(listId);
    if (trimmed.isEmpty || list == null) return;
    final safeQuantity = quantity < 1 ? 1 : quantity;
    list.items = [
      ...list.items,
      PackingItem(id: _id(), name: trimmed, quantity: safeQuantity),
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> setItemQuantity(String listId, String itemId, int quantity) async {
    final item = _item(listId, itemId);
    if (item == null) return;
    item.quantity = quantity < 1 ? 1 : quantity;
    notifyListeners();
    await _persist();
  }

  Future<void> renameItem(String listId, String itemId, String name) async {
    final trimmed = name.trim();
    final item = _item(listId, itemId);
    if (trimmed.isEmpty || item == null) return;
    item.name = trimmed;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleItem(String listId, String itemId, bool packed) async {
    final item = _item(listId, itemId);
    if (item == null) return;
    item.packed = packed;
    notifyListeners();
    await _persist();
  }

  Future<void> deleteItem(String listId, String itemId) async {
    final list = listById(listId);
    if (list == null) return;
    list.items = list.items.where((item) => item.id != itemId).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> restorePresets() async {
    final customs = lists.where((list) => !list.isPreset).toList();
    lists = [...DefaultLists.build(), ...customs];
    notifyListeners();
    await _persist();
  }

  Future<void> updateTrips(List<TripDraft> next) async {
    trips = next.isEmpty ? [TripDraft()] : next;
    notifyListeners();
    await _persist();
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final error = await _storage.login(email: email, password: password);
    if (error != null) return error;
    sessionEmail = await _storage.sessionEmail();
    sessionName = await _storage.sessionName();
    sessionPhoto = await _storage.sessionPhoto();
    sessionPhone = await _storage.sessionPhone();
    lists = await _storage.loadLists();
    trips = await _storage.loadTrips();
    notifyListeners();
    return null;
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final error = await _storage.register(name: name, email: email, password: password);
    pendingToken = _storage.pendingToken;
    if (error != null) return error;
    sessionEmail = await _storage.sessionEmail();
    sessionName = await _storage.sessionName();
    sessionPhoto = await _storage.sessionPhoto();
    sessionPhone = await _storage.sessionPhone();
    notifyListeners();
    return null;
  }

  Future<String?> confirmEmail(String token) async {
    final error = await _storage.confirmEmail(token);
    if (error == null) pendingToken = null;
    return error;
  }

  Future<String?> requestRecovery(String email) async {
    final error = await _storage.requestRecovery(email);
    pendingToken = _storage.pendingToken;
    return error;
  }

  Future<String?> completeRecovery({
    required String token,
    required String password,
    required String confirm,
  }) {
    return _storage.completeRecovery(token: token, password: password, confirm: confirm);
  }

  Future<String?> updateProfile({
    required String name,
    required String phone,
  }) async {
    final error = await _storage.updateProfile(name: name, phone: phone);
    if (error != null) return error;
    sessionName = name.trim();
    final cleanPhone = phone.trim();
    sessionPhone = cleanPhone.isEmpty ? null : cleanPhone;
    notifyListeners();
    return null;
  }

  Future<String?> changePassword({
    required String current,
    required String next,
    required String confirm,
  }) async {
    return _storage.changePassword(current: current, next: next, confirm: confirm);
  }

  Future<String?> resetPassword({
    required String email,
    required String password,
    required String confirm,
  }) {
    return _storage.resetPassword(email: email, password: password, confirm: confirm);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    await _storage.setNotificationsEnabled(value);
  }

  Future<void> setHideEmail(bool value) async {
    hideEmail = value;
    notifyListeners();
    await _storage.setHideEmail(value);
  }

  Future<String?> setProfilePhoto(Uint8List bytes) async {
    if (bytes.length > 1200000) {
      return 'Esa foto es muy pesada. Elige una más pequeña.';
    }
    final encoded = base64Encode(bytes);
    final error = await _storage.updatePhoto(encoded);
    if (error != null) return error;
    sessionPhoto = encoded;
    notifyListeners();
    return null;
  }

  Future<void> removeProfilePhoto() async {
    await _storage.updatePhoto(null);
    sessionPhoto = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _storage.logout();
    sessionEmail = null;
    sessionName = null;
    sessionPhoto = null;
    sessionPhone = null;
    notifyListeners();
  }

  PackingItem? _item(String listId, String itemId) {
    final list = listById(listId);
    if (list == null) return null;
    for (final item in list.items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}
