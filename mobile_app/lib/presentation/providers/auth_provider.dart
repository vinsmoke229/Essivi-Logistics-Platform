import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import 'core_providers.dart';

 
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
   
   
   
   
   
   
  throw UnimplementedError('Provider was not overridden');
});

 
class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserEntity? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

 
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final user = await _repository.getCurrentUser();
    if (user != null) {
      state = state.copyWith(user: user);
    }
  }

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.login(identifier, password);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> registerClient(String name, String phone, String address, {String? responsibleName, String? pin}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print("🔍 DEBUG - AuthProvider: registerClient appelé");
      print("Nom: $name, Gérant: $responsibleName, Tél: $phone");
      
      final user = await _repository.registerClient(name, phone, address, responsibleName: responsibleName, pin: pin);
      
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      print("❌ DEBUG - AuthProvider: Erreur registerClient: $e");
      String errorMsg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Exception', '');
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState();
  }
}

 
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
