import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/data_service.dart'; // Pour récupérer les headers
import '../services/location_service.dart';
import '../utils/constants.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();
  final DataService _dataService = DataService(); // Juste pour récupérer token si besoin

  final _nameController = TextEditingController();
  final _responsibleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  Position? _currentPosition;
  String _gpsStatus = "Recherche GPS...";

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  void _getLocation() async {
    try {
      Position pos = await _locationService.determinePosition();
      setState(() {
        _currentPosition = pos;
        _gpsStatus = "OK (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})";
      });
    } catch (e) {
      setState(() => _gpsStatus = "Erreur GPS");
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS requis pour géolocaliser la boutique")));
      return;
    }

    setState(() => _isLoading = true);

    // Préparation de l'appel API (On le fait ici en direct pour simplifier, ou on pourrait le mettre dans DataService)
    final url = Uri.parse('${ApiConstants.baseUrl}/clients/');
    
    // Astuce : On doit récupérer le token manuellement. 
    // Pour aller vite, on va copier la logique de header ici, ou mieux : ajouter la méthode dans DataService.
    // Ajoutons la méthode dans DataService plus bas, c'est plus propre.
    final success = await _dataService.createClient(
      name: _nameController.text,
      responsible: _responsibleController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Client ajouté avec succès !"), backgroundColor: Colors.green));
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'ajout"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("NOUVEAU CLIENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // GPS STATUS HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _currentPosition != null ? const Color(0xFF10B981).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentPosition != null ? const Color(0xFF10B981) : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _currentPosition != null ? Icons.location_on_rounded : Icons.location_searching_rounded, 
                      color: Colors.white, 
                      size: 14
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _gpsStatus, 
                      style: TextStyle(
                        color: _currentPosition != null ? const Color(0xFF065F46) : Colors.orange.shade900, 
                        fontSize: 11, 
                        fontWeight: FontWeight.bold
                      )
                    )
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("IDENTITÉ DU POINT DE VENTE"),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(
                      controller: _nameController,
                      label: "NOM DE LA BOUTIQUE",
                      icon: Icons.storefront_rounded,
                      validator: (v) => v!.isEmpty ? "Nom requis" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(
                      controller: _responsibleController,
                      label: "NOM DU RESPONSABLE",
                      icon: Icons.person_rounded,
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader("COORDONNÉES & LOCALISATION"),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(
                      controller: _phoneController,
                      label: "TÉLÉPHONE",
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? "Téléphone requis" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(
                      controller: _addressController,
                      label: "ADRESSE / QUARTIER",
                      icon: Icons.map_rounded,
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (_isLoading || _currentPosition == null) 
                                ? Colors.transparent 
                                : Colors.blue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: (_isLoading || _currentPosition == null) ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("ENREGISTRER LE CLIENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.blue, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
