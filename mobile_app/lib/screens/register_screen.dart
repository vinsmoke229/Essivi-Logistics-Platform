import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();
  
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Hide keyboard
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final pin = _pinController.text.trim();

    print("🔍 DEBUG - Tentative d'inscription client:");
    print("Nom: $name");
    print("Téléphone: $phone");
    print("Adresse: $address");
    print("PIN: $pin");

    try {
      await ref.read(authProvider.notifier).registerClient(name, phone, address, pin: pin);

      // Check if error
      if (ref.read(authProvider).error == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Compte créé avec succès ! Connectez-vous avec votre téléphone et PIN.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            )
          );
          Navigator.pop(context); // Go back to login
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: ${ref.read(authProvider).error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            )
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de l\'inscription: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          )
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription Client', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.person_add_outlined, size: 60, color: Colors.blue),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Créer un compte client',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Remplissez les informations pour créer votre compte',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildTextField(
                      controller: _nameController, 
                      label: 'Nom du Point de Vente', 
                      icon: Icons.store,
                      validator: (value) => value!.isEmpty ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _phoneController, 
                      label: 'Numéro de téléphone', 
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value!.isEmpty) return 'Téléphone requis';
                        if (value.length < 8) return 'Téléphone invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _addressController, 
                      label: 'Adresse complète', 
                      icon: Icons.location_on,
                      validator: (value) => value!.isEmpty ? 'Adresse requise' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _pinController, 
                      label: 'PIN (4 chiffres)', 
                      icon: Icons.lock,
                      isPassword: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      validator: (value) {
                        if (value!.isEmpty) return 'PIN requis';
                        if (value.length != 4) return 'Le PIN doit avoir 4 chiffres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    if (authState.error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authState.error!,
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),

                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('S\'INSCRIRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                    
                    // Instructions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue, size: 16),
                              SizedBox(width: 8),
                              Text("INSTRUCTIONS", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "• Choisissez un PIN à 4 chiffres facile à retenir\n• Gardez votre PIN confidentiel\n• Utilisez ce PIN pour vous connecter",
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.blue.shade400),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        counterText: maxLength != null ? '' : null,
      ),
      validator: validator ?? (value) => value!.isEmpty ? 'Requis' : null,
    );
  }
}
