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
    _captureGPS();  
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

     
    try {
      final success = await ref.read(dataServiceProvider).createClient(
        name: _nameController.text.trim(),
        responsible: _responsibleController.text.trim(),  
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        lat: _capturedPosition!.latitude,
        lng: _capturedPosition!.longitude
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Client IAI enregistré avec succès !"), backgroundColor: Colors.green)
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec de l'enregistrement"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red)
      );
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
              TextFormField(
                controller: _nameController, 
                decoration: const InputDecoration(labelText: "Nom Boutique / Point de Vente", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Nom requis" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _responsibleController, 
                decoration: const InputDecoration(labelText: "Nom du Responsable / Gérant", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Nom du Responsable requis" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController, 
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Téléphone requis" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController, 
                decoration: const InputDecoration(labelText: "Quartier / Adresse", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text("ENREGISTRER CE POINT DE VENTE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}