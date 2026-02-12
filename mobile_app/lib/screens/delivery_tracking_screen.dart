import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';

 
 
class DeliveryTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final double? agentLat;
  final double? agentLng;

  const DeliveryTrackingScreen({
    super.key, 
    required this.orderId,
    this.agentLat,
    this.agentLng,
  });

  @override
  ConsumerState<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends ConsumerState<DeliveryTrackingScreen> {
  final SocketService _socketService = SocketService();
  final MapController _mapController = MapController();
  
  LatLng? _agentPosition;
  bool _isSocketConnected = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    
     
    if (widget.agentLat != null && widget.agentLng != null) {
      _agentPosition = LatLng(widget.agentLat!, widget.agentLng!);
    }
    
    _initializeSocket();
  }

   
  void _initializeSocket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        _socketService.connect(
          token: token,
          orderId: widget.orderId,
        );
        
        if (mounted) {
          setState(() {
            _isSocketConnected = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _connectionError = 'Token d\'authentification manquant';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur initialisation Socket: $e');
      if (mounted) {
        setState(() {
          _connectionError = 'Erreur de connexion: $e';
        });
      }
    }
  }

   
  void _centerOnAgent() {
    if (_agentPosition != null) {
      _mapController.move(_agentPosition!, 15.0);
    }
  }

  @override
  void dispose() {
     
    _socketService.leaveOrderRoom(widget.orderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     
    const LatLng shopLocation = LatLng(6.137, 1.212);

    return Scaffold(
      appBar: AppBar(
        title: Text("Suivi Commande #${widget.orderId}"),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
           
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: _isSocketConnected
                  ? const Icon(Icons.wifi, color: Colors.greenAccent, size: 20)
                  : const Icon(Icons.wifi_off, color: Colors.redAccent, size: 20),
            ),
          ),
        ],
      ),
      body: StreamBuilder<AgentPosition>(
        stream: _socketService.positionStream,
        builder: (context, snapshot) {
           
          if (snapshot.hasData && mounted) {
            final newPosition = LatLng(snapshot.data!.lat, snapshot.data!.lng);
            
             
            if (snapshot.data!.orderId == widget.orderId || snapshot.data!.orderId == null) {
              _agentPosition = newPosition;
              
               
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _mapController.move(newPosition, _mapController.camera.zoom);
                }
              });
            }
          }

           
          final currentPosition = _agentPosition ?? shopLocation;

          return Stack(
            children: [
               
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentPosition,
                  initialZoom: 14.0,
                  minZoom: 10.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.essivi.app',
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                   
                  MarkerLayer(
                    markers: [
                       
                      Marker(
                        point: shopLocation,
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.store, color: Colors.blue, size: 40),
                      ),
                       
                      if (_agentPosition != null)
                        Marker(
                          point: _agentPosition!,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.delivery_dining, 
                            color: Colors.red, 
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                   
                  if (_agentPosition != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [shopLocation, _agentPosition!],
                          color: Colors.blue.withOpacity(0.5),
                          strokeWidth: 4.0,
                          isDotted: true,
                        ),
                      ],
                    ),
                ],
              ),
              
               
              if (_connectionError != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.red.shade700,
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _connectionError!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              
               
              if (_agentPosition == null && _connectionError == null)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'En attente de la position du livreur...',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _centerOnAgent,
        label: const Text("Centrer sur livreur"),
        icon: const Icon(Icons.my_location),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }
}
