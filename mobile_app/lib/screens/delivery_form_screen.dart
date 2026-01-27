import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:flutter/foundation.dart'; // Pour kIsWeb
import 'dart:typed_data'; // Pour Uint8List
import 'dart:convert'; // Pour jsonEncode

import '../services/data_service.dart';
import '../services/location_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../presentation/providers/data_service_provider.dart';

class DeliveryFormScreen extends ConsumerStatefulWidget {
  const DeliveryFormScreen({super.key});

  @override
  ConsumerState<DeliveryFormScreen> createState() => _DeliveryFormScreenState();
}

class _DeliveryFormScreenState extends ConsumerState<DeliveryFormScreen> {
  final LocationService _locationService = LocationService();
  final ImagePicker _imagePicker = ImagePicker();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  
  List<dynamic> _clients = [];
  List<dynamic> _products = []; // LISTE DYNAMIQUE DES PRODUITS
  final Map<int, int> _quantities = {}; // ID Produit -> Quantité
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _selectedClientId;
  
  // GESTION WEB-SAFE (Mémoire)
  Uint8List? _locationPhotoBytes;
  Uint8List? _customerSignatureBytes;
  // Chemin fichier (Uniquement pour Mobile/SQLite)
  String? _mobilePhotoPath; 
  String? _mobileSignaturePath;
  
  String? _currentLocation;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _getCurrentLocation();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Charger les clients
      final clients = await ref.read(dataServiceProvider).getClients();
      
      // 2. Charger les produits (Verna, Vitale...)
      final products = await ref.read(dataServiceProvider).getProducts();
      
      if (mounted) {
        setState(() {
          _clients = clients;
          _products = products;
          // Initialiser les compteurs à 0 pour chaque produit trouvé
          for (var p in _products) {
            _quantities[p['id']] = 0;
          }
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur chargement: $e")));
      }
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _amountController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final position = await _locationService.determinePosition();
      setState(() {
        _currentLocation = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _currentLocation = "Localisation indisponible";
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _captureLocationPhoto() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800, maxHeight: 600,
      );
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _locationPhotoBytes = bytes;
          if (!kIsWeb) _mobilePhotoPath = pickedFile.path; // Sauvegarde le chemin sur Mobile
        });
      }
    } catch (e) {
      // Ignorer erreur annulée
    }
  }

  Future<void> _saveCustomerSignature() async {
    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes != null) {
        setState(() {
          _customerSignatureBytes = signatureBytes;
          // Sur mobile, on pourrait sauvegarder dans un fichier temporaire ici si besoin
          // Pour l'instant on garde en mémoire/blob
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur signature: $e")));
    }
  }

  void _clearSignature() {
    _signatureController.clear();
    setState(() {
      _customerSignatureBytes = null;
      _mobileSignaturePath = null;
    });
  }

  // --- CALCUL DU PRIX DYNAMIQUE ---
  void _calculateAmount() {
    double total = 0;
    for (var p in _products) {
      final qty = _quantities[p['id']] ?? 0;
      final price = double.tryParse(p['price'].toString()) ?? 0.0;
      total += qty * price;
    }
    _amountController.text = total.toStringAsFixed(0);
  }

  Future<void> _submitDelivery() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Vérifier qu'au moins un produit est sélectionné
    final items = _quantities.entries
        .where((e) => e.value > 0)
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner au moins un produit")),
      );
      return;
    }

    // Validation Photo (Sauf sur Web en dev pour aller vite)
    if (_locationPhotoBytes == null && !kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo du lieu obligatoire")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Capture de la signature avant envoi
    await _saveCustomerSignature();

    try {
      final double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
      
      // Préparation des données pour SQLite (on stocke le Base64 directement)
      final deliveryData = {
        'client_id': _selectedClientId,
        'client_name': _selectedClientId != null 
            ? _clients.firstWhere((c) => c['id'].toString() == _selectedClientId)['name']
            : _clientNameController.text,
        'items_json': jsonEncode(items),
        'amount': totalAmount,
        'gps_lat': _currentLocation != null ? double.tryParse(_currentLocation!.split(',')[0]) : 0.0,
        'gps_lng': _currentLocation != null ? double.tryParse(_currentLocation!.split(',')[1].trim()) : 0.0,
        'photo_url': _locationPhotoBytes != null ? 'data:image/jpeg;base64,${base64Encode(_locationPhotoBytes!)}' : null,
        'signature_url': _customerSignatureBytes != null ? 'data:image/png;base64,${base64Encode(_customerSignatureBytes!)}' : null,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0
      };

      // 1. Sauvegarde Locale (Toujours)
      await _databaseHelper.insertDelivery(deliveryData);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Livraison enregistrée !"), backgroundColor: Colors.green),
      );
      
      // 2. Tentative de Synchro immédiate (Si réseau)
      if (!kIsWeb) {
         try { ref.read(dataServiceProvider).syncOfflineDeliveries(); } catch (e) { /* Silent */ }
      }
      
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("NOUVELLE LIVRAISON", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION CLIENT ---
                  _buildSectionTitle("Client"),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration('Sélectionner un client'),
                    value: _selectedClientId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Nouveau client (Hors catalogue)')),
                      ..._clients.map((client) {
                        return DropdownMenuItem(
                          value: client['id'].toString(),
                          child: Text(client['name'] ?? 'Inconnu'),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _selectedClientId = value),
                  ),
                  if (_selectedClientId == null) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _clientNameController,
                      decoration: _inputDecoration('Nom de la boutique'),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _clientPhoneController,
                      decoration: _inputDecoration('Téléphone'),
                      keyboardType: TextInputType.phone,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // --- SECTION PRODUITS DYNAMIQUE ---
                  _buildSectionTitle("Produits"),
                  const SizedBox(height: 8),
                  if (_products.isEmpty)
                    const Text("Aucun produit disponible (Vérifiez la connexion ou le stock)", style: TextStyle(color: Colors.red)),
                  
                  ..._products.map((prod) {
                    final int pid = prod['id'];
                    final int qty = _quantities[pid] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), 
                        side: BorderSide(color: qty > 0 ? Colors.blue : Colors.grey.shade200)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text("${prod['price']} F / unité", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (qty > 0) {
                                  setState(() {
                                    _quantities[pid] = qty - 1;
                                    _calculateAmount();
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            ),
                            SizedBox(
                              width: 30,
                              child: Text("$qty", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _quantities[pid] = qty + 1;
                                  _calculateAmount();
                                });
                              },
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 16),
                  // TOTAL
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("MONTANT TOTAL :", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        Text("${_amountController.text} FCFA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SECTION PREUVES ---
                  _buildSectionTitle("Preuves de livraison"),
                  const SizedBox(height: 12),
                  
                  // GPS
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_currentLocation ?? "Recherche GPS...", style: const TextStyle(fontSize: 13))),
                      if (!_isGettingLocation) 
                        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _getCurrentLocation)
                      else
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // PHOTO
                  GestureDetector(
                    onTap: _captureLocationPhoto,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: _locationPhotoBytes != null 
                          ? DecorationImage(image: MemoryImage(_locationPhotoBytes!), fit: BoxFit.cover)
                          : null,
                      ),
                      child: _locationPhotoBytes == null 
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Icon(Icons.camera_alt, size: 40, color: Colors.grey), Text("Prendre une photo")],
                          )
                        : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // SIGNATURE
                  _buildSectionTitle("Signature du client"),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Signature(
                        controller: _signatureController,
                        height: 150,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _clearSignature,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text("Effacer"),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // BOUTON FINAL
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitDelivery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("VALIDER LA LIVRAISON", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)));
  }
}