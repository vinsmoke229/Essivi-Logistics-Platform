library simple_delivery_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/presentation/providers/data_service_provider.dart';
import 'package:mobile_app/screens/add_client_screen.dart';
import 'package:mobile_app/screens/delivery_form_screen.dart';

class SimpleDeliveryScreen extends ConsumerStatefulWidget {
  const SimpleDeliveryScreen({super.key});

  @override
  ConsumerState<SimpleDeliveryScreen> createState() => _SimpleDeliveryScreenState();
}

class _SimpleDeliveryScreenState extends ConsumerState<SimpleDeliveryScreen> {
  List<dynamic> _clients = [];
  List<dynamic> _missions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final dataService = ref.read(dataServiceProvider);
    final clients = await dataService.getClients();
    final missions = await dataService.getMyMissions();
    
    setState(() {
      _clients = clients;
      _missions = missions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("LIVRAISONS", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.add_business, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          "AJOUTER UN CLIENT",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${_clients.length} clients enregistrés",
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                   
                  GestureDetector(
                    onTap: () => _showNewDeliveryDialog(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.local_shipping, color: Colors.white, size: 48),
                          SizedBox(height: 12),
                          Text(
                            "NOUVELLE LIVRAISON",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Text(
                    "MISSIONS EN COURS",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 16),
                  
                  _missions.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                "Aucune mission en cours",
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _missions.length,
                          itemBuilder: (context, index) {
                            final mission = _missions[index];
                            final items = mission['items'] as List? ?? [];
                            final int totalArticles = items.length;
                            final double totalAmount = (mission['total_amount'] as num?)?.toDouble() ?? 0.0;
                            
                            return GestureDetector(
                              onTap: () {
                                 
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DeliveryFormScreen(initialMission: mission),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Mission #${mission['order_id'] ?? mission['id'] ?? 'N/A'}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "${totalAmount.toStringAsFixed(0)} FCFA",
                                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            mission['client_name'] ?? 'Client Inconnu',
                                            style: TextStyle(color: Colors.grey.shade700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.inventory_2, size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 4),
                                        Text(
                                          "$totalArticles Article(s) - Total: ${totalAmount.toStringAsFixed(0)} FCFA",
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Cliquer pour livrer",
                                          style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  void _showNewDeliveryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Nouvelle Livraison", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Voulez-vous créer une nouvelle livraison ou ajouter un client d'abord ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ANNULER"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddClientScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("AJOUTER CLIENT"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveryFormScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("LIVRAISON DIRECTE"),
          ),
        ],
      ),
    );
  }
}
