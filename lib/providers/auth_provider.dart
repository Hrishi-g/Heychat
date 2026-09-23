import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/secure_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _currentMblNo;
  String? _currentImgUrl;
  String? _currentUserName;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get currentMblNo => _currentMblNo;
  String? get currentImgUrl => _currentImgUrl;
  String? get currentUserName => _currentUserName;

  AuthProvider() {
    checkLoginState();
  }

  void updateProfileData({String? name, String? imgUrl}) {
    bool changed = false;
    if (name != null && name != _currentUserName) {
      _currentUserName = name;
      changed = true;
    }
    if (imgUrl != null && imgUrl != _currentImgUrl) {
      _currentImgUrl = imgUrl;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> checkLoginState() async {
    _isLoading = true;

    // 1. Migrate any legacy tokens from unencrypted SharedPreferences
    await SecureStorageService.instance.migrateFromSharedPreferences();

    // 2. Read from hardware-backed secure storage
    final token = await AuthService.getToken();
    final mblNo = await AuthService.getUserMblNo();
    if (token != null && mblNo != null) {
      _isAuthenticated = true;
      _currentMblNo = mblNo;
      _isLoading = false;
      notifyListeners();

      // Fetch user profile to cache image & display name
      _fetchProfileInBackground();
    } else {
      _isAuthenticated = false;
      _currentMblNo = null;
      _currentImgUrl = null;
      _currentUserName = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchProfileInBackground() async {
    try {
      final profile = await AuthService().getProfile();
      if (profile != null) {
        _currentUserName = profile.name;
        _currentImgUrl = profile.imgUrl;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLoggedIn(String mblNo) async {
    _isAuthenticated = true;
    _currentMblNo = mblNo;
    await AuthService.saveUserMblNo(mblNo);
    notifyListeners();
    _fetchProfileInBackground();
  }

  Future<void> logout() async {
    await AuthService.clearToken();
    await DatabaseService.instance.clearDatabase();
    _isAuthenticated = false;
    _currentMblNo = null;
    _currentImgUrl = null;
    _currentUserName = null;
    notifyListeners();
  }
}
