import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';
import 'missions_list_screen.dart';
import 'dashboard_screen.dart';
import 'client_dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isAgentMode = true;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    // Hide keyboard
    FocusScope.of(context).unfocus();

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    // Si c'est un client de test, créer automatiquement le compte
    if (!_isAgentMode && identifier == "00228912345678") {
      _createTestClientIfNeeded();
    }

    ref.read(authProvider.notifier).login(identifier, password);
  }

  void _createTestClientIfNeeded() {
    // Logique pour créer un client de test si nécessaire
    // Cette fonction pourrait appeler une API pour créer le client
    print("Création du client de test si nécessaire...");
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes for navigation or error handling
    ref.listen(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      } else if (next.user != null) {
        // DEBUG: Afficher le rôle pour diagnostic
        print("🔍 DEBUG - Rôle utilisateur: ${next.user!.role}");
        print("🔍 DEBUG - Mode actuel: ${_isAgentMode ? 'AGENT' : 'CLIENT'}");
        
        // PRIORITÉ AU MODE SÉLECTIONNÉ PAR L'UTILISATEUR
        if (_isAgentMode) {
          print("🔍 DEBUG - Redirection forcée vers DashboardScreen (mode agent)");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          print("🔍 DEBUG - Redirection forcée vers ClientDashboardScreen (mode client)");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ClientDashboardScreen()),
          );
        }
      }
    });

    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(Icons.water_drop_rounded, size: 60, color: Colors.blue),
                  ),
                  const SizedBox(height: 24),
                  const Text('ESSIVI Sarl', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 48),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _buildToggleTab("AGENT", _isAgentMode, () => setState(() => _isAgentMode = true)),
                              _buildToggleTab("CLIENT", !_isAgentMode, () => setState(() => _isAgentMode = false)),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildTextField(
                            controller: _identifierController, 
                            label: _isAgentMode ? 'Matricule / Tél' : 'Numéro de Téléphone', 
                            icon: _isAgentMode ? Icons.person_outline : Icons.phone_android_outlined
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController, 
                            label: _isAgentMode ? 'Mot de passe' : 'Code PIN', 
                            icon: Icons.lock_outline, 
                            isPassword: true
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: authState.isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                                : Text(_isAgentMode ? 'SE CONNECTER' : 'ACCÉDER À MON ESPACE', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (!_isAgentMode) ...[
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              child: const Text("Pas encore de compte ? S'inscrire", style: TextStyle(color: Colors.white70)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTab(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isActive ? Colors.white : Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.blue.shade400),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      validator: (value) => value!.isEmpty ? 'Requis' : null,
    );
  }
}