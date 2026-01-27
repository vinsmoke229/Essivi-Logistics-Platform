import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/client_remote_data_source.dart';
import '../presentation/providers/core_providers.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  ConsumerState<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final dataSource = ClientRemoteDataSource(apiClient: ref.read(apiClientProvider));
      final data = await dataSource.getProfile();
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du chargement du profil: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updatePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);
    try {
      final dataSource = ClientRemoteDataSource(apiClient: ref.read(apiClientProvider));
      final success = await dataSource.changePin(
        _oldPinController.text.trim(),
        _newPinController.text.trim(),
      );

      if (success && mounted) {
        _oldPinController.clear();
        _newPinController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Code PIN mis à jour avec succès"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Mon Profil", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("INFORMATIONS PERSONNELLES"),
                _buildInfoCard(),
                const SizedBox(height: 32),
                _buildSectionHeader("SÉCURITÉ"),
                _buildSecurityCard(),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.person_outline, "Nom", _profile?['name'] ?? "-"),
          const Divider(height: 32),
          _buildInfoRow(Icons.phone_android_outlined, "Téléphone", _profile?['phone'] ?? "-"),
          const Divider(height: 32),
          _buildInfoRow(Icons.location_on_outlined, "Adresse", _profile?['address'] ?? "-"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _oldPinController,
              obscureText: true,
              decoration: _inputDecoration("Ancien PIN", Icons.lock_open_rounded),
              validator: (v) => v!.isEmpty ? "Requis" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPinController,
              obscureText: true,
              decoration: _inputDecoration("Nouveau PIN", Icons.lock_outline_rounded),
              validator: (v) => v!.length < 4 ? "4 chiffres minimum" : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updatePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isUpdating 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("METTRE À JOUR LE PIN", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }
}
