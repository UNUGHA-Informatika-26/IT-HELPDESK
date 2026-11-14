import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityCubit extends Cubit<ConnectivityStatus> {
  ConnectivityCubit({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(ConnectivityStatus.offline) {
    _subscription = _connectivity!.onConnectivityChanged.listen(
      _update,
      onError: (Object _) => emit(ConnectivityStatus.offline),
    );
    unawaited(refresh());
  }

  ConnectivityCubit.forTesting({
    ConnectivityStatus initial = ConnectivityStatus.online,
  })  : _connectivity = null,
        super(initial);

  final Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => state == ConnectivityStatus.online;

  void reportFirestoreUnavailable() => emit(ConnectivityStatus.offline);

  Future<void> refresh() async {
    final connectivity = _connectivity;
    if (connectivity == null) return;
    try {
      _update(await connectivity.checkConnectivity());
    } on Object {
      emit(ConnectivityStatus.offline);
    }
  }

  void _update(List<ConnectivityResult> results) {
    emit(results.any((result) => result != ConnectivityResult.none)
        ? ConnectivityStatus.online
        : ConnectivityStatus.offline);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
