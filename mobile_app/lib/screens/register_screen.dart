import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';
import 'client_dashboard_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}



class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _responsibleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();
  
  LatLng _pinnedLocation = const LatLng(6.13, 1.22);  
  final MapController _mapController = MapController();
  
  void _submit() async {
     
    final lat = _pinnedLocation.latitude;
    final lng = _pinnedLocation.longitude;
     
    if (!_formKey.currentState!.validate()) return;
    
     
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final responsible = _responsibleController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final pin = _pinController.text.trim();

    try {
      await ref.read(authProvider.notifier).registerClient(
        name, 
        phone, 
        address, 
        responsibleName: responsible, 
        pin: pin
      );

       
      final authState = ref.read(authProvider);
      if (authState.user != null && authState.error == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Inscription et Connexion réussies !'),
              backgroundColor: Colors.green,
            )
          );
           
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const ClientDashboardScreen()),
            (route) => false,
          );
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
    _responsibleController.dispose();
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

                     
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)
                        ]
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _pinnedLocation,
                              initialZoom: 14.0,
                              onTap: (tapPosition, point) {
                                setState(() {
                                  _pinnedLocation = point;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.essivi.delivery',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _pinnedLocation,
                                    width: 80,
                                    height: 80,
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          PositionResultOverlay(lat: _pinnedLocation.latitude, lng: _pinnedLocation.longitude),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "💡 Touchez la carte pour épingler votre position exacte",
                      style: TextStyle(color: Colors.blue.shade300, fontSize: 11, fontStyle: FontStyle.italic),
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
                      controller: _responsibleController, 
                      label: 'Nom du Responsable / Gérant', 
                      icon: Icons.person_outline,
                      validator: (value) => value!.isEmpty ? 'Nom du responsable requis' : null,
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

class PositionResultOverlay extends StatelessWidget {
  final double lat;
  final double lng;
  const PositionResultOverlay({super.key, required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gps_fixed, color: Colors.blue, size: 14),
            const SizedBox(width: 8),
            Text(
              "Position : ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}",
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
