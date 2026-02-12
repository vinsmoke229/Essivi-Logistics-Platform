import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../presentation/providers/agent_provider.dart';
import 'delivery_screen.dart';

class MissionsListScreen extends ConsumerStatefulWidget {
  const MissionsListScreen({super.key});

  @override
  ConsumerState<MissionsListScreen> createState() => _MissionsListScreenState();
}

class _MissionsListScreenState extends ConsumerState<MissionsListScreen> {
  
  @override
  void initState() {
    super.initState();
     
    Future.microtask(() => ref.read(agentProvider.notifier).loadMissions());
  }

  Future<Position> _determinePosition() async {
      
     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
     if (!serviceEnabled) throw Exception('Localisation désactivée');
     LocationPermission permission = await Geolocator.checkPermission();
     if (permission == LocationPermission.denied) {
       permission = await Geolocator.requestPermission();
       if (permission == LocationPermission.denied) throw Exception('Permission refusée');
     }
     if (permission == LocationPermission.deniedForever) throw Exception('Permission refusée pour toujours');
     return await Geolocator.getCurrentPosition();
  }

  void _toggleTour() async {
    try {
      final pos = await _determinePosition();
      ref.read(agentProvider.notifier).toggleTour(pos.latitude, pos.longitude);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur GPS: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentState = ref.watch(agentProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("AGENT - ESSIVI", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(agentProvider.notifier).loadMissions(),
          )
        ],
      ),
      body: Column(
        children: [
           
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: ElevatedButton.icon(
              onPressed: agentState.isLoading ? null : _toggleTour,
              icon: Icon(agentState.isTourActive ? Icons.stop : Icons.play_arrow),
              label: agentState.isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(agentState.isTourActive ? "ARRÊTER MA TOURNÉE" : "DÉMARRER MA TOURNÉE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: agentState.isTourActive ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          if (agentState.error != null)
             Padding(
               padding: const EdgeInsets.all(8.0),
               child: Text(agentState.error!, style: const TextStyle(color: Colors.red)),
             ),
          const Divider(height: 1),
          
           
          Expanded(
            child: agentState.missions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          agentState.error != null ? Icons.cloud_off_rounded : Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          agentState.error ?? "Aucune mission assignée",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(agentProvider.notifier).loadMissions(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("🔄 RÉESSAYER"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: agentState.missions.length,
                    itemBuilder: (context, index) {
                      final mission = agentState.missions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(mission.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("📦 Vitale: ${mission.quantityVitale} | Voltic: ${mission.quantityVoltic}"),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => DeliveryScreen(missionEntity: mission)),
                            ).then((_) => ref.read(agentProvider.notifier).loadMissions());
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}