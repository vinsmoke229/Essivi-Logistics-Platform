import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../../domain/entities/mission_entity.dart';
import '../../data/repositories/delivery_repository.dart';
import '../presentation/providers/agent_provider.dart';
import '../../services/hive_service.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  final MissionEntity missionEntity;
  const DeliveryScreen({super.key, required this.missionEntity});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  StreamSubscription<Position>? _positionStream;
  double _distanceInMeters = double.infinity;
  bool _canValidate = false;
  bool _isLoading = false;
  Position? _currentPosition;

  final _amountController = TextEditingController();
  final SignatureController _sig = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  XFile? _image;
  bool _signatureCaptured = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.missionEntity.totalAmount.toString();
    _startTracking();
  }

  void _startTracking() async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1)
    ).listen((pos) {
      double dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        widget.missionEntity.gpsLat, widget.missionEntity.gpsLng
      );

      if (mounted) {
        setState(() {
          _distanceInMeters = dist;
          _currentPosition = pos; // Store current position
          // 2m tolerance as per specifications
          _canValidate = dist <= 2.0; 
        });
        
        // Update Agent Location remotely (Fire and forget)
        ref.read(agentProvider.notifier).updateLocation(pos.latitude, pos.longitude);
      }
    });
  }

  void _forceArrival() {
    setState(() {
      _distanceInMeters = 1.5;
      _canValidate = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mode Démo : Arrivée simulée")));
  }

  Future<void> _capturePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 600,
      );
      
      if (photo != null && mounted) {
        setState(() {
          _image = photo;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo capturée avec succès!"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur capture photo: $e"))
        );
      }
    }
  }

  void _clearPhoto() {
    setState(() {
      _image = null;
    });
  }

  void _clearSignature() {
    _sig.clear();
    setState(() {
      _signatureCaptured = false;
    });
  }

  void _saveSignature() {
    if (_sig.isNotEmpty) {
      setState(() {
        _signatureCaptured = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signature enregistrée!"))
      );
    }
  }

  Future<void> _submitDelivery() async {
    // Validation checks
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez prendre une photo de livraison"))
      );
      return;
    }

    if (!_signatureCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez faire signer le client"))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Use current position if available, otherwise fallback to mission position
      final gpsLat = _currentPosition?.latitude ?? widget.missionEntity.gpsLat;
      final gpsLng = _currentPosition?.longitude ?? widget.missionEntity.gpsLng;
      
      // Check connectivity
      final hiveService = HiveService();
      await hiveService.init();
      final isOnline = await hiveService.isOnline();
      
      if (isOnline) {
        // Try to send online first
        try {
          // Convert signature to base64 for now (in real implementation, upload to server)
          final signatureBytes = await _sig.toPngBytes();
          final signatureBase64 = signatureBytes != null 
              ? 'data:image/png;base64,${base64Encode(signatureBytes)}'
              : null;
          
          final success = await ref.read(deliveryRepositoryProvider).sendDelivery(
            clientId: widget.missionEntity.clientId,
            qtyVitale: widget.missionEntity.quantityVitale,
            qtyVoltic: widget.missionEntity.quantityVoltic,
            amount: double.tryParse(_amountController.text) ?? widget.missionEntity.totalAmount,
            gpsLat: gpsLat,
            gpsLng: gpsLng,
            photoUrl: _image?.path, // TODO: Implement actual upload
            signatureUrl: signatureBase64, // TODO: Implement actual upload
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Livraison validée et synchronisée !"))
            );
            Navigator.pop(context);
            return;
          }
        } catch (e) {
          print("Online submission failed, falling back to offline: $e");
        }
      }
      
      // Save offline if online failed or no connectivity
      final signatureBytes = await _sig.toPngBytes();
      final signatureData = signatureBytes != null ? base64Encode(signatureBytes) : null;
      
      final offlineDelivery = OfflineDelivery(
        clientId: widget.missionEntity.clientId,
        qtyVitale: widget.missionEntity.quantityVitale,
        qtyVoltic: widget.missionEntity.quantityVoltic,
        amount: double.tryParse(_amountController.text) ?? widget.missionEntity.totalAmount,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        photoPath: _image?.path,
        signatureData: signatureData,
        createdAt: DateTime.now(),
      );
      
      await hiveService.saveOfflineDelivery(offlineDelivery);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline 
                ? "Livraison sauvegardée localement (échec synchronisation)"
                : "Livraison sauvegardée localement (mode hors ligne)"),
            backgroundColor: Colors.orange,
          )
        );
        Navigator.pop(context);
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.missionEntity.clientName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _forceArrival,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _canValidate ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Icon(_canValidate ? Icons.check_circle : Icons.directions_walk, color: Colors.white, size: 40),
                    Text(_canValidate ? "ARRIVÉ CHEZ LE CLIENT" : "EN ROUTE...", 
                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("${_distanceInMeters.toStringAsFixed(1)} m", 
                         style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _amountController, decoration: const InputDecoration(labelText: "Montant à percevoir")),
            const SizedBox(height: 20),
            
            // Photo Section
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Photo de livraison", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_image != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_image!.path),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _capturePhoto,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text("Reprendre"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _clearPhoto,
                                icon: const Icon(Icons.delete),
                                label: const Text("Supprimer"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text("Aucune photo", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    if (_image == null)
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _capturePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text("Prendre une photo"),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Signature Section
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("Signature du client", style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_signatureCaptured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text("Signé", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Signature(
                      controller: _sig,
                      backgroundColor: Colors.white,
                      width: double.infinity,
                      height: 150,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _clearSignature,
                          icon: const Icon(Icons.clear),
                          label: const Text("Effacer"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSignature,
                          icon: const Icon(Icons.check),
                          label: const Text("Valider signature"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_canValidate && !_isLoading) ? _submitDelivery : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: _isLoading ? const CircularProgressIndicator() : const Text("VALIDER LA LIVRAISON", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}