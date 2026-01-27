import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/data_service_provider.dart';
import '../services/location_service.dart';

class AddClientScreen extends ConsumerStatefulWidget {
  const AddClientScreen({super.key});

  @override
  ConsumerState<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends ConsumerState<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();

  final _nameController = TextEditingController();
  final _responsibleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  Position? _capturedPosition;

  @override
  void initState() {
    super.initState();
    _captureGPS(); // Capture automatique au démarrage
  }

  void _captureGPS() async {
    try {
      Position pos = await _locationService.determinePosition();
      if (!mounted) return;
      setState(() => _capturedPosition = pos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("GPS Erreur: $e")));
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _capturedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attente position GPS...")));
      return;
    }

    setState(() => _isLoading = true);
    
    // On envoie les coordonnées capturées par le téléphone
    final success = await ref.read(dataServiceProvider).createClient(
      name: _nameController.text,
      responsible: _responsibleController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      lat: _capturedPosition!.latitude,
      lng: _capturedPosition!.longitude
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Client IAI enregistré avec succès !")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NOUVEAU CLIENT (IAI)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Indicateur GPS Vert/Rouge
              Container(
                padding: const EdgeInsets.all(12),
                color: _capturedPosition != null ? Colors.green[50] : Colors.red[50],
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: _capturedPosition != null ? Colors.green : Colors.red),
                    const SizedBox(width: 10),
                    Text(_capturedPosition != null ? "Position Capturée ✅" : "Recherche GPS... ⏳"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Nom Boutique")),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: "Téléphone")),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: "Quartier")),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: _isLoading ? const CircularProgressIndicator() : const Text("ENREGISTRER CE POINT DE VENTE"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}