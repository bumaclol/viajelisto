import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/default_lists.dart';
import '../logic/account_merge.dart';
import '../logic/trip_calculator.dart';
import '../models/packing_item.dart';
import '../models/packing_list.dart';
import '../models/trip_draft.dart';
import '../services/google_redirect.dart';
import '../services/phone_bridge.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';

enum CloudSave { browser, saving, saved, failed }

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
  String languageCode = 'es';
  bool hideEmail = false;
  final Set<String> _alerts = {};
  CloudSave cloudSave = CloudSave.browser;
  String? cloudSaveDetail;
  RemoteSnapshot? pendingMerge;

  bool get signedIn => sessionEmail != null;
  bool get usesCloud => _storage.usesCloud;

  Future<void> warmCloud() => _storage.warmCloud();
  String? pendingToken;

  Future<void> _persist() async {
    await _storage.saveLists(lists);
    await _storage.saveTrips(trips);
    if (!signedIn || !usesCloud) {
      cloudSave = CloudSave.browser;
      cloudSaveDetail = null;
      notifyListeners();
      return;
    }
    cloudSave = CloudSave.saving;
    cloudSaveDetail = null;
    notifyListeners();
    final error = await _storage.pushCloud(lists, trips);
    cloudSave = error == null ? CloudSave.saved : CloudSave.failed;
    cloudSaveDetail = error;
    notifyListeners();
  }

  Future<void> _reconcile({
    bool seededExample = false,
    bool restoreAccountData = false,
  }) async {
    final remote = await _storage.fetchRemote();
    if (remote.error != null) {
      cloudSave = CloudSave.failed;
      cloudSaveDetail = remote.error;
      pendingMerge = null;
      return;
    }
    if (!remote.synced) {
      await _persist();
      return;
    }
    final remoteTrips = remote.trips.isEmpty ? [TripDraft()] : remote.trips;
    if (restoreAccountData &&
        sameTripPayload(lists, trips, DefaultLists.build(), [TripDraft()])) {
      lists = remote.lists;
      trips = remoteTrips;
      pendingMerge = null;
      cloudSave = CloudSave.saved;
      cloudSaveDetail = null;
      await _storage.saveLists(lists);
      await _storage.saveTrips(trips);
      return;
    }
    if (seededExample && remoteTrips.every((trip) => trip.isBlankDraft)) {
      lists = mergeLists(lists, remote.lists);
      pendingMerge = null;
      await _persist();
      return;
    }
    if (sameTripPayload(lists, trips, remote.lists, remoteTrips)) {
      cloudSave = CloudSave.saved;
      cloudSaveDetail = null;
      pendingMerge = null;
      return;
    }
    pendingMerge = RemoteSnapshot(synced: true, lists: remote.lists, trips: remoteTrips);
    cloudSave = CloudSave.browser;
    cloudSaveDetail = 'Hay datos distintos en tu cuenta.';
  }

  Future<void> keepBrowserData() async {
    pendingMerge = null;
    await _persist();
  }

  Future<void> useAccountData() async {
    final remote = pendingMerge;
    pendingMerge = null;
    if (remote == null) return;
    lists = remote.lists;
    trips = remote.trips.isEmpty ? [TripDraft()] : remote.trips;
    notifyListeners();
    await _persist();
  }

  Future<void> combineAccount() async {
    final remote = pendingMerge;
    pendingMerge = null;
    if (remote == null) return;
    final remoteTrip = remote.trips.isEmpty ? TripDraft() : remote.trips.first;
    lists = mergeLists(lists, remote.lists);
    trips = [mergeTrip(trips.isEmpty ? TripDraft() : trips.first, remoteTrip)];
    notifyListeners();
    await _persist();
  }

  Future<void> _enterSession() async {
    sessionEmail = await _storage.sessionEmail();
    sessionName = await _storage.sessionName();
    sessionPhoto = await _storage.sessionPhoto();
    sessionPhone = await _storage.sessionPhone();
    final restoreAccountData = _storage.takeAccountDataRestoreRequest();
    if (signedIn && usesCloud) {
      await _reconcile(restoreAccountData: restoreAccountData);
    }
    notifyListeners();
  }

  Future<void> load() async {
    try {
      await _storage.open();
      lists = await _storage.loadLists();
      trips = await _storage.loadTrips();
      if (trips.isEmpty) trips = [TripDraft()];
      final seed = await _storage.replaceBlankTripWithExample(lists, trips);
      trips = seed.trips;
      sessionEmail = await _storage.sessionEmail();
      sessionName = await _storage.sessionName();
      sessionPhoto = await _storage.sessionPhoto();
      sessionPhone = await _storage.sessionPhone();
      notificationsEnabled = await _storage.notificationsEnabled();
      languageCode = await _storage.languageCode();
      hideEmail = await _storage.hideEmail();
      if (signedIn && usesCloud) await _reconcile(seededExample: seed.applied);
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
    final list = listById(listId);
    if (list != null) _watchList(list);
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
    _watchBudget();
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final error = await _storage.login(email: email, password: password);
    if (error != null) return error;
    await _enterSession();
    return null;
  }

  Future<String?> signInWithGoogle(String idToken) async {
    final error = await _storage.signInWithGoogle(idToken);
    if (error != null) return error;
    await _enterSession();
    return null;
  }

  Future<String?> signInWithProvider(String provider) async {
    final error = await _storage.signInWithProvider(provider);
    if (error != null) return error;
    await _enterSession();
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
    await _enterSession();
    return null;
  }

  Future<String?> confirmEmail(String token) async {
    final error = await _storage.confirmEmail(token);
    if (error == null) pendingToken = null;
    return error;
  }

  Future<String?> resendConfirmation(String email) {
    return _storage.resendConfirmation(email);
  }

  Future<String?> requestRecovery(String email) async {
    final error = await _storage.requestRecovery(email);
    pendingToken = _storage.pendingToken;
    return error;
  }

  Future<String?> requestLoginCode(String email) async {
    final error = await _storage.requestLoginCode(email);
    pendingToken = _storage.pendingToken;
    return error;
  }

  Future<String?> signInWithCode({
    required String email,
    required String code,
  }) async {
    final error = await _storage.loginWithCode(email: email, code: code);
    if (error != null) return error;
    await _enterSession();
    return null;
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

  Future<String?> setNotificationsEnabled(bool value) async {
    if (value) {
      final allowed = await requestAlerts();
      if (!allowed) {
        notificationsEnabled = false;
        notifyListeners();
        await _storage.setNotificationsEnabled(false);
        return 'El navegador bloqueó los avisos. Actívalos en los permisos del sitio.';
      }
    }
    notificationsEnabled = value;
    notifyListeners();
    await _storage.setNotificationsEnabled(value);
    return null;
  }

  Future<void> setLanguage(String code) async {
    languageCode = code == 'en' ? 'en' : 'es';
    notifyListeners();
    await _storage.setLanguageCode(languageCode);
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
    forgetGoogleSession();
    await _storage.logout();
    sessionEmail = null;
    sessionName = null;
    sessionPhoto = null;
    sessionPhone = null;
    pendingMerge = null;
    cloudSave = CloudSave.browser;
    cloudSaveDetail = null;
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

  void _ping(String key, String title, String body) {
    if (!notificationsEnabled || _alerts.contains(key)) return;
    _alerts.add(key);
    showAlert(title, body);
  }

  void _watchList(PackingList list) {
    final key = 'packed-${list.id}';
    final complete = list.items.isNotEmpty && list.packedCount == list.items.length;
    if (!complete) {
      _alerts.remove(key);
      return;
    }
    _ping(key, 'Equipaje listo', '${list.name} está completo.');
  }

  void _watchBudget() {
    const key = 'budget';
    if (trips.isEmpty) {
      _alerts.remove(key);
      return;
    }
    final trip = trips.first;
    final preview = previewTrip(
      distance: trip.distance,
      consumption: trip.consumption,
      fuelPrice: trip.fuelPrice,
      tolls: trip.tolls,
      budget: trip.budget,
      passengers: trip.passengers < 1 ? 1 : trip.passengers,
      liters: trip.liters,
      otherExpenses: trip.otherExpenses,
      extraAmounts: [for (final extra in trip.extras) extra.amount],
    );
    if (preview is! CostReady || preview.result.withinBudget != false) {
      _alerts.remove(key);
      return;
    }
    final missing = preview.result.budgetDifference?.abs() ?? 0;
    _ping(key, 'Presupuesto superado', 'Te pasas ${formatMoney(missing)} por persona.');
  }
}
