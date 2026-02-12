import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'package:mobile_app/widgets/session_timeout_wrapper.dart';
import 'package:mobile_app/widgets/sync_status_indicator.dart';
import 'package:mobile_app/presentation/providers/data_service_provider.dart';
import 'package:mobile_app/presentation/providers/auth_provider.dart';
import 'package:mobile_app/services/location_service.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/simple_delivery_screen.dart';
import 'package:mobile_app/screens/agent_profile_screen.dart';
import 'package:mobile_app/screens/history_screen.dart';
import 'package:mobile_app/screens/add_client_screen.dart';
import 'package:mobile_app/screens/performance_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final LocationService _locationService = LocationService();
  
  bool _isTourActive = false;
  bool _isLoading = false;
  String _userName = "";
  int _missionCount = 0;
  Timer? _trackingTimer; // Gardé pour la structure demandée

  @override
  void initState() {
    super.initState();
    _checkTourStatus();
    _loadMissions();
    ref.read(dataServiceProvider).syncOfflineDeliveries(); 
  }

  void _loadMissions() async {
    try {
      final missions = await ref.read(dataServiceProvider).getMyMissions();
      if (mounted) {
        setState(() {
          _missionCount = missions.length;
        });
      }
    } catch (e) {
      print("Erreur chargement missions dashboard: $e");
    }
  }

  void _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('name') ?? "Agent";
      });
    }
  }

  void _checkTourStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isTourActive = prefs.getBool('isTourActive') ?? false;
      });
    }
    
    // Identity load
    _loadIdentity();

    if (_isTourActive) {
      _startTracking();
    }
  }

  @override
  void dispose() {
    _stopTracking();
    _trackingTimer?.cancel();
    super.dispose();
  }

  void _startTracking() async {
    if (kIsWeb) {
      print("🛰️ Tracking GPS Web (Simulation via Timer)");
      _trackingTimer?.cancel();
      _trackingTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
        try {
          final position = await _locationService.determinePosition();
          await ref.read(dataServiceProvider).updateLocation(position.latitude, position.longitude);
          print("📍 Position Web envoyée: ${position.latitude}, ${position.longitude}");
        } catch (e) {
          print("⚠️ Erreur tracking Web: $e");
        }
      });
    } else {
      print("🛰️ Tracking GPS Arrière-plan Démarré");
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
    }
  }

  void _stopTracking() {
    if (kIsWeb) {
      print("🛑 Tracking GPS Web Arrêté");
      _trackingTimer?.cancel();
      _trackingTimer = null;
    } else {
      print("🛑 Tracking GPS Arrière-plan Arrêté");
      FlutterBackgroundService().invoke("stopService");
    }
  }

  void _toggleTour() async {
    // Si la tournée est active, on veut la terminer (pas de stock à charger)
    if (_isTourActive) {
      _processTourAction(null); // null = Fin de tournée
      return;
    }

    // Si on veut DÉMARRER, on affiche d'abord le dialogue de stock
    final stockItems = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadStockDialog(),
    );

    if (stockItems != null) {
      _processTourAction(stockItems);
    }
  }

  void _processTourAction(List<Map<String, dynamic>>? stockItems) async {
    setState(() => _isLoading = true);
    
    Position position;
    try {
      position = await _locationService.determinePosition();
    } catch (e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur GPS: $e")));
      setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!_isTourActive) {
      // DÉMARRER avec le stock
      final tourId = await ref.read(dataServiceProvider).startTour(
        position.latitude, 
        position.longitude,
        items: stockItems ?? [] // On passe les items
      );
      
      if (tourId != null) {
        await prefs.setBool('isTourActive', true);
        await prefs.setInt('currentTourId', tourId);
        _startTracking();
        setState(() => _isTourActive = true);
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tournée démarrée ! "), backgroundColor: Colors.green));
      }
    } else {
      // TERMINER
      final result = await ref.read(dataServiceProvider).endTour(position.latitude, position.longitude);
      if (result != null) {
        await prefs.setBool('isTourActive', false);
        await prefs.remove('currentTourId');
        _stopTracking();
        setState(() => _isTourActive = false);
        
        if(!mounted) return;
        final summary = result['summary'];
        _showSummaryDialog(summary['deliveries'], summary['cash']);
      }
    }
    setState(() => _isLoading = false);
  }

  void _showSummaryDialog(int count, double cash) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Bilan de la Tournée", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text("Chiffre d'Affaires", style: TextStyle(color: Colors.green[800], fontSize: 12)),
                  Text("$cash F", style: TextStyle(color: Colors.green[900], fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16)),
              title: Text("$count Livraisons effectuées"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("FERMER", style: TextStyle(fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (Reste de la méthode build inchangé)
    return SessionTimeoutWrapper(
      timeoutDuration: const Duration(minutes: 5),
      onTimeout: () {
        ref.read(authProvider.notifier).logout();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Tableau de Bord", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          actions: [
            const SyncStatusIndicator(),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Bonjour, $_userName", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const Text("Voici votre activité pour aujourd'hui.", style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: _isLoading ? null : _toggleTour, // Utilise la nouvelle méthode
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTourActive 
                        ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)] 
                        : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(_isTourActive ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _isTourActive ? "TOURNÉE EN COURS" : "DÉMARRER LA JOURNÉE",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$_missionCount ARTICLES À LIVRER",
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              const Text("OPÉRATIONS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _buildActionButton(
                    'Livraison',
                    Icons.local_shipping,
                    Colors.blue,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => SimpleDeliveryScreen()))
                  ),
                  _buildActionButton(
                    'Historique',
                    Icons.history,
                    Colors.orange,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryScreen()))
                  ),
                  _buildActionButton(
                    'Client',
                    Icons.person_add,
                    Colors.green,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddClientScreen()))
                  ),
                  _buildActionButton(
                    'Profil',
                    Icons.account_circle,
                    Colors.purple,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => AgentProfileScreen()))
                  ),
                  _buildActionButton(
                    'Performance',
                    Icons.bar_chart,
                    Colors.red,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => PerformanceScreen()))
                  ),
                  _buildActionButton(
                    'Sync',
                    Icons.sync,
                    Colors.teal,
                    () async {
                      await ref.read(dataServiceProvider).syncOfflineDeliveries();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Synchronisation terminée"), backgroundColor: Colors.green),
                      );
                    }
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LoadStockDialog extends ConsumerStatefulWidget {
  const LoadStockDialog({super.key});

  @override
  ConsumerState<LoadStockDialog> createState() => _LoadStockDialogState();
}

class _LoadStockDialogState extends ConsumerState<LoadStockDialog> {
  List<dynamic> _products = [];
  Map<int, int> _quantities = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    try {
      final products = await ref.read(dataServiceProvider).getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("📦 Chargement du Stock"),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _products.isEmpty
                ? const Text("Aucun produit disponible.")
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final productId = product['id'];
                      return ListTile(
                        title: Text(product['name']),
                        subtitle: Text("En stock: ${product['stock_quantity'] ?? '?'}"),
                        trailing: SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    final current = _quantities[productId] ?? 0;
                                    if (current > 0) _quantities[productId] = current - 1;
                                  });
                                },
                              ),
                              Text("${_quantities[productId] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                onPressed: () {
                                  setState(() {
                                    final current = _quantities[productId] ?? 0;
                                    _quantities[productId] = current + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Annuler (retourne null)
          child: const Text("ANNULER"),
        ),
        ElevatedButton(
          onPressed: () {
            // Créer la liste des items à charger
            List<Map<String, dynamic>> items = [];
            _quantities.forEach((id, qty) {
              if (qty > 0) {
                // Trouver le produit pour avoir son nom si besoin, ou juste envoyer ID
                final product = _products.firstWhere((p) => p['id'] == id, orElse: () => {});
                items.add({
                  "product_id": id,
                  "quantity": qty,
                  "product_name": product['name'] ?? "Produit #$id" 
                });
              }
            });
            Navigator.pop(context, items);
          },
          child: const Text("DÉMARRER"),
        ),
      ],
    );
  }
}