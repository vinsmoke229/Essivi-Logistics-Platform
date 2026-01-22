import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'delivery_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'add_client_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DataService _dataService = DataService();
  final LocationService _locationService = LocationService();
  
  bool _isTourActive = false;
  bool _isLoading = false;
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _checkTourStatus();
    _dataService.syncOfflineDeliveries(); // Tente de synchroniser les données locales
  }

  void _checkTourStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTourActive = prefs.getBool('isTourActive') ?? false;
      _userName = prefs.getString('name') ?? "Utilisateur";
    });
  }

  void _toggleTour() async {
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
      // DÉMARRER
      final tourId = await _dataService.startTour(position.latitude, position.longitude);
      if (tourId != null) {
        await prefs.setBool('isTourActive', true);
        await prefs.setInt('currentTourId', tourId);
        setState(() => _isTourActive = true);
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tournée démarrée ! 🚀"), backgroundColor: Colors.green));
      }
    } else {
      // TERMINER
      final result = await _dataService.endTour(position.latitude, position.longitude);
      if (result != null) {
        await prefs.setBool('isTourActive', false);
        await prefs.remove('currentTourId');
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

  void _logout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0F172A), // Slate 900
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: const Text(
                "Tableau de Bord",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _logout(context),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bonjour, $_userName",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const Text(
                    "Voici votre activité pour aujourd'hui.",
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),

                  // TOUR ACTION CARD
                  GestureDetector(
                    onTap: _isLoading ? null : _toggleTour,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isTourActive 
                            ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)] 
                            : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: (_isTourActive ? Colors.red : Colors.blue).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isTourActive ? "TOURNÉE EN COURS" : "DÉMARRER LA JOURNÉE",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isTourActive ? "Appuyez pour arrêter" : "Prêt à livrer ? Commencez ici",
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: _isLoading 
                              ? const Padding(
                                  padding: EdgeInsets.all(15.0),
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : Icon(_isTourActive ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    "OPÉRATIONS",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // QUICK ACTIONS GRID
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                _buildPremiumCard(
                  context, 
                  'Livraison', 
                  Icons.local_shipping_rounded, 
                  const Color(0xFF3B82F6), 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveryScreen()))
                ),
                _buildPremiumCard(
                  context, 
                  'Historique', 
                  Icons.history_rounded, 
                  const Color(0xFFF59E0B), 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()))
                ),
                _buildPremiumCard(
                  context, 
                  'Client', 
                  Icons.person_add_rounded, 
                  const Color(0xFF10B981), 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddClientScreen()))
                ),
                _buildPremiumCard(
                  context, 
                  'Profil', 
                  Icons.account_circle_rounded, 
                  const Color(0xFF8B5CF6), 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))
                ),
              ],
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64748B).withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Appuyer",
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
