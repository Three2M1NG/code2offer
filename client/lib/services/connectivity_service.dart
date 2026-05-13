import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Stream<bool> onStatusChange() {
    return _connectivity.onConnectivityChanged.map(
      (result) => !result.contains(ConnectivityResult.none),
    );
  }
}

final connectivityProvider = StreamProvider<bool>((ref) {
  final svc = ConnectivityService();
  return svc.onStatusChange();
});

final isOnlineProvider = FutureProvider<bool>((ref) async {
  final svc = ConnectivityService();
  return svc.isOnline();
});
