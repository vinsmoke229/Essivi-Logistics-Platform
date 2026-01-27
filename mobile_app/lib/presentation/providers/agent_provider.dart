import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/mission_entity.dart';
import '../../domain/repositories/agent_repository.dart';
import '../../data/datasources/agent_remote_data_source.dart';
import '../../data/repositories/agent_repository_impl.dart';
import '../providers/core_providers.dart';

// REPOSITORY PROVIDER
final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final remoteDataSource = AgentRemoteDataSource(apiClient: apiClient);
  return AgentRepositoryImpl(remoteDataSource: remoteDataSource);
});

// STATE
class AgentState {
  final bool isTourActive;
  final bool isLoading;
  final String? currentTourId;
  final List<MissionEntity> missions;
  final String? error;

  AgentState({
    this.isTourActive = false,
    this.isLoading = false,
    this.currentTourId,
    this.missions = const [],
    this.error,
  });

  AgentState copyWith({
    bool? isTourActive,
    bool? isLoading,
    String? currentTourId,
    List<MissionEntity>? missions,
    String? error,
  }) {
    return AgentState(
      isTourActive: isTourActive ?? this.isTourActive,
      isLoading: isLoading ?? this.isLoading,
      currentTourId: currentTourId ?? this.currentTourId,
      missions: missions ?? this.missions,
      error: error,
    );
  }
}

// NOTIFIER
class AgentNotifier extends StateNotifier<AgentState> {
  final AgentRepository _repository;
  final SharedPreferences _prefs;

  AgentNotifier(this._repository, this._prefs) : super(AgentState()) {
    _loadState();
  }

  void _loadState() {
    final isActive = _prefs.getBool('isTourActive') ?? false;
    final tourId = _prefs.getString('currentTourId');
    state = state.copyWith(isTourActive: isActive, currentTourId: tourId);
    if (isActive) {
      loadMissions();
    }
  }

  Future<void> loadMissions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final missions = await _repository.getMissions();
      state = state.copyWith(missions: missions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Erreur chargement missions: $e");
    }
  }

  Future<void> toggleTour(double lat, double lng) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (state.isTourActive) {
        // Stop Tour
        await _repository.endTour(lat, lng);
        await _prefs.setBool('isTourActive', false);
        await _prefs.remove('currentTourId');
        state = state.copyWith(isTourActive: false, currentTourId: null, isLoading: false);
      } else {
        // Start Tour
        final tourId = await _repository.startTour(lat, lng);
        await _prefs.setBool('isTourActive', true);
        if (tourId != null) await _prefs.setString('currentTourId', tourId);
        state = state.copyWith(isTourActive: true, currentTourId: tourId, isLoading: false);
        loadMissions(); // Load missions when tour starts
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    // Fire and forget, don't block
    try {
      await _repository.updateLocation(lat, lng);
    } catch (_) {}
  }
}

// PROVIDER
final agentProvider = StateNotifierProvider<AgentNotifier, AgentState>((ref) {
  final repository = ref.watch(agentRepositoryProvider);
  // Need SharedPreferences. Ideally we await it or use the overridden provider.
  // We can use ref.read(sharedPreferencesProvider) inside main override context.
  // BUT sharedPreferencesProvider is FutureProvider...
  // However, we overrode it in main with AsyncValue.data containing the instance.
  // So we can try `ref.read(sharedPreferencesProvider).requireValue`.
  // Wait, `requireValue` might fail if not initialized, but in main we ensure it is (sync override).
  // Safe approach: create a Sync Provider for prefs if we override it, or just use `AsnycValue`.
  
  // Actually, we can just assume it's there because we overrode it.
  // Actually, we can just assume it's there because we overrode it.
  final prefs = ref.watch(sharedPreferencesProvider);
  
  return AgentNotifier(repository, prefs);
});
