import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Import GPS
import '../services/data_service.dart';
import '../services/location_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:io';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataService _dataService = DataService();
  final LocationService _locationService = LocationService(); // Instance GPS
  
  final _qtyVitaleController = TextEditingController(text: '0');
  final _qtyVolticController = TextEditingController(text: '0');
  final _amountController = TextEditingController();

  List<dynamic> _clients = [];
  String? _selectedClientId;
  bool _isLoading = false;
  
  // Variables GPS
  Position? _currentPosition;
  String _gpsStatus = "Recherche du signal GPS...";
  bool _isGpsReady = false;
  double _distanceToClient = double.infinity;
  final double _validationThreshold = 2.0; // 2 mètres selon cahier des charges
  
  // Evaluation
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  
  // Photo & Signature
  XFile? _image;
  final ImagePicker _picker = ImagePicker();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _loadClients();
    _getCurrentLocation(); // Lancer le GPS dès l'ouverture
  }

  // Capturer la position réelle
  void _getCurrentLocation() async {
    try {
      Position position = await _locationService.determinePosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isGpsReady = true;
        _gpsStatus = "Position verrouillée : ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      });
      _calculateDistance(); // Recalculer si on a la position
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsStatus = "Erreur GPS : $e";
        _isGpsReady = false;
      });
    }
  }

  void _loadClients() async {
    final clients = await _dataService.getClients();
    setState(() {
      _clients = clients;
    });
  }

  // Calcul de la distance entre l'agent et le client sélectionné
  void _calculateDistance() {
    if (_currentPosition == null || _selectedClientId == null) return;
    
    final client = _clients.firstWhere((c) => c['id'].toString() == _selectedClientId);
    if (client['gps_lat'] == null || client['gps_lng'] == null) {
      setState(() => _distanceToClient = double.infinity);
      return;
    }

    final double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      client['gps_lat'], 
      client['gps_lng']
    );

    setState(() {
      _distanceToClient = distance;
    });
  }

  Widget _buildDistanceIndicator() {
    bool isNearby = _distanceToClient <= _validationThreshold;
    String text = _distanceToClient == double.infinity 
      ? "Coordonnées client manquantes" 
      : "Distance du client : ${_distanceToClient.toStringAsFixed(1)} m";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isNearby ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(isNearby ? Icons.check_circle : Icons.warning, color: isNearby ? Colors.green : Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: isNearby ? Colors.green[900] : Colors.red[900], fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _submitDelivery() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner un client")));
      return;
    }
    
    // Blocage si pas de GPS (Respect strict du cahier des charges)
    if (!_isGpsReady || _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attente du signal GPS...")));
      return;
    }

    /* Règle des 2 mètres (Cahier des charges 3.1.3)
    if (_distanceToClient > _validationThreshold) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vous devez être à moins de $_validationThreshold m du client (Actuel: ${_distanceToClient.toStringAsFixed(1)}m)"))
      );
      return;
    } */

    setState(() => _isLoading = true);

    // Conversion Base64 pour la signature (Prototype)
    String? signatureBase64;
    try {
      final signatureExport = await _signatureController.toPngBytes();
      if (signatureExport != null) {
        signatureBase64 = base64Encode(signatureExport);
      }
    } catch (e) {
      print("Erreur export signature: $e");
    }

    String? photoBase64;
    if (_image != null) {
      final bytes = await File(_image!.path).readAsBytes();
      photoBase64 = base64Encode(bytes);
    }

    final success = await _dataService.sendDelivery(
      clientId: int.parse(_selectedClientId!),
      qtyVitale: int.parse(_qtyVitaleController.text),
      qtyVoltic: int.parse(_qtyVolticController.text),
      amount: double.parse(_amountController.text),
      gpsLat: _currentPosition!.latitude,
      gpsLng: _currentPosition!.longitude,
      photoUrl: photoBase64,
      signatureUrl: signatureBase64,
      // Ajout de l'évaluation (besoin de mise à jour des paramètres sendDelivery si on veut les sauver)
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Livraison enregistrée avec GPS ! 🚚"), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'envoi"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("LIVRAISON", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
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
                color: _isGpsReady ? const Color(0xFF10B981).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isGpsReady ? const Color(0xFF10B981) : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isGpsReady ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded, 
                      color: Colors.white, 
                      size: 14
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _gpsStatus, 
                      style: TextStyle(
                        color: _isGpsReady ? const Color(0xFF065F46) : Colors.orange.shade900, 
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
                    // CLIENT SELECTION CARD
                    _buildSectionHeader("POINT DE VENTE"),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedClientId,
                        items: _clients.map<DropdownMenuItem<String>>((client) {
                          return DropdownMenuItem<String>(
                            value: client['id'].toString(),
                            child: Text(
                              "${client['name']}",
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClientId = value;
                            _calculateDistance();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Sélectionner un client",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.storefront_rounded, color: Colors.blue),
                        ),
                      ),
                    ),
                    
                    if (_selectedClientId != null) ...[
                      const SizedBox(height: 16),
                      _buildPremiumDistanceIndicator(),
                    ],
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader("QUANTITÉS (PAQUETS)"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuantityField(
                            controller: _qtyVitaleController,
                            label: "VITALE",
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuantityField(
                            controller: _qtyVolticController,
                            label: "VOLTIC",
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader("PUREMENT FINANCIER"),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: "MONTANT TOTAL PERÇU",
                          labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          hintText: "0.00",
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.payments_rounded, color: const Color(0xFF10B981)),
                          suffixText: "FCFA",
                          suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        ),
                        validator: (val) => val!.isEmpty ? "Requis" : null,
                      ),
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader("PREUVES DE LIVRAISON"),
                    const SizedBox(height: 12),
                    
                    // PHOTO PICKER
                    InkWell(
                      onTap: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                        setState(() => _image = image);
                      },
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: _image == null 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, color: Colors.blue.shade300),
                                const Text("Prendre une photo", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(File(_image!.path), fit: BoxFit.cover),
                            ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    
                    // SIGNATURE PAD
                    const Text("Signature du client :", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _signatureController.clear(),
                      child: const Text("Effacer la signature", style: TextStyle(fontSize: 11, color: Colors.red)),
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
                              color: (_isLoading || !_isGpsReady || _distanceToClient > _validationThreshold) 
                                ? Colors.transparent 
                                : Colors.blue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitDelivery,
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
                            : const Text("VALIDER LA LIVRAISON", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    if (_distanceToClient > _validationThreshold && _selectedClientId != null)
                      Center(
                        child: Text(
                          "Rapprochement requis (< ${_validationThreshold}m)",
                          style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
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

  Widget _buildQuantityField({required TextEditingController controller, required String label, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPremiumDistanceIndicator() {
    bool isNearby = _distanceToClient <= _validationThreshold;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNearby ? const Color(0xFF10B981).withOpacity(0.05) : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isNearby ? const Color(0xFF10B981).withOpacity(0.2) : Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isNearby ? const Color(0xFF10B981) : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(isNearby ? Icons.check_rounded : Icons.location_on_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNearby ? "POSSITION VALIDÉE" : "DISTANCE TROP ÉLEVÉE",
                style: TextStyle(
                  color: isNearby ? const Color(0xFF065F46) : Colors.red.shade900, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 11,
                  letterSpacing: 0.5
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _distanceToClient == double.infinity ? "GPS Invalide" : "${_distanceToClient.toStringAsFixed(1)} mètres",
                style: TextStyle(color: isNearby ? const Color(0xFF047857) : Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
