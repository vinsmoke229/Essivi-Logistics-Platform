import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/client_provider.dart';

class DeliveryTrackingScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Position de l'entrepôt Essivi (Lomé) - Exemple
    const LatLng shopLocation = LatLng(6.137, 1.212);
    
    final LatLng agentLocation = agentLat != null 
      ? LatLng(agentLat!, agentLng!)
      : shopLocation; // Fallback

    return Scaffold(
      appBar: AppBar(
        title: Text("Suivi Commande #$orderId"),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: agentLocation,
          initialZoom: 14.0,
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
              Marker(
                point: agentLocation,
                width: 50,
                height: 50,
                child: const Icon(Icons.delivery_dining, color: Colors.red, size: 40),
              ),
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [shopLocation, agentLocation],
                color: Colors.blue.withOpacity(0.5),
                strokeWidth: 4.0,
                isDotted: true,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Re-centrer sur l'agent
        },
        label: const Text("Livreur"),
        icon: const Icon(Icons.my_location),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }
}
