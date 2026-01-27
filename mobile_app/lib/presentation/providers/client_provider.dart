import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/client_repository.dart';
import '../../data/datasources/client_remote_data_source.dart';
import '../../data/repositories/client_repository_impl.dart';
import '../providers/core_providers.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return ClientRepositoryImpl(
    remoteDataSource: ClientRemoteDataSource(apiClient: apiClient),
  );
});

class ClientState {
  final bool isLoading;
  final List<OrderEntity> orders;
  final Map<String, dynamic> stats;
  final String? error;

  ClientState({
    this.isLoading = false,
    this.orders = const [],
    this.stats = const {},
    this.error,
  });

  ClientState copyWith({
    bool? isLoading,
    List<OrderEntity>? orders,
    Map<String, dynamic>? stats,
    String? error,
  }) {
    return ClientState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      stats: stats ?? this.stats,
      error: error,
    );
  }
}

class ClientNotifier extends StateNotifier<ClientState> {
  final ClientRepository _repository;

  ClientNotifier(this._repository) : super(ClientState()) {
    refresh();
  }

  Future<void> refresh() async {
    await Future.wait([
      loadOrders(),
      loadStats(),
    ]);
  }

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await _repository.getOrders();
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadStats() async {
    try {
      final stats = await _repository.getStats();
      state = state.copyWith(stats: stats);
    } catch (e) {
      print("Erreur chargement stats: $e");
    }
  }

  Future<bool> createOrder({
    required List<Map<String, dynamic>> items,
    String? preferredTime,
    String? instructions,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _repository.createOrder(
        items: items,
        preferredTime: preferredTime,
        instructions: instructions,
      );
      if (success) {
        await refresh(); // Refresh everything
      }
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final clientProvider = StateNotifierProvider<ClientNotifier, ClientState>((ref) {
  final repository = ref.watch(clientRepositoryProvider);
  return ClientNotifier(repository);
});
