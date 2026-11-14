import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/features/connectivity/connectivity_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  test('reports online when at least one network interface is available',
      () async {
    final connectivity = _MockConnectivity();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    final cubit = ConnectivityCubit(connectivity: connectivity);
    addTearDown(cubit.close);

    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, ConnectivityStatus.online);
  });

  test('reports offline when no interface is available', () async {
    final connectivity = _MockConnectivity();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);
    final cubit = ConnectivityCubit(connectivity: connectivity);
    addTearDown(cubit.close);

    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, ConnectivityStatus.offline);
  });
}
