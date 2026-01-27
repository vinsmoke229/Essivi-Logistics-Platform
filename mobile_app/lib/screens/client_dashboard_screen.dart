import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../presentation/providers/client_provider.dart';
import '../presentation/providers/auth_provider.dart';
import 'login_screen.dart';
import 'new_order_screen.dart';
import 'client_invoices_screen.dart';
import 'client_history_screen.dart';
import 'client_profile_screen.dart';
import 'delivery_tracking_screen.dart';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(clientProvider.notifier).refresh());
  }

  void _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientProvider);
    final orders = clientState.orders;
    final stats = clientState.stats;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async => await ref.read(clientProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF0F172A),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                title: const Text(
                  "Espace Client",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
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
                        icon: const Icon(Icons.logout_rounded, color: Colors.orangeAccent, size: 20),
                        onPressed: _logout,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (clientState.isLoading && orders.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BALANCE CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF64748B).withOpacity(0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "RESUMÉ ACTIVITÉ",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now()).toUpperCase(), 
                                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Suivi Temps Réel",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildPremiumMiniStat("Commandes", "${stats['total_orders'] ?? 0}", Icons.shopping_basket_rounded, Colors.blue),
                                _buildPremiumMiniStat("Restant", "${stats['pending_deliveries'] ?? 0}", Icons.timer_rounded, Colors.orange),
                                _buildPremiumMiniStat("Réussi", "${stats['completed_deliveries'] ?? 0}", Icons.check_circle_rounded, const Color(0xFF10B981)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Text(
                        "SERVICES RAPIDES",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildClientActionButton(
                              icon: Icons.shopping_cart_checkout_rounded,
                              label: "Commander",
                              color: Colors.blue,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const NewOrderScreen()));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildClientActionButton(
                              icon: Icons.history_rounded,
                              label: "Livrées",
                              color: const Color(0xFF10B981),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientHistoryScreen()));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildClientActionButton(
                              icon: Icons.person_rounded,
                              label: "Profil",
                              color: const Color(0xFF6366F1),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientProfileScreen()));
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "DERNIÈRES COMMANDES",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientHistoryScreen()));
                            },
                            child: const Text("VOIR TOUT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),

            if (!clientState.isLoading && orders.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text("Aucune commande passée", style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = orders[index];
                      final title = order.itemsDescription.isNotEmpty ? order.itemsDescription : "Commande #${order.id}";
                      return _buildPremiumOrderTile(
                        title, 
                        order.createdAt, 
                        "#${order.id}", 
                        order.status, 
                        _getStatusColor(order.status),
                        onTrack: (order.status == 'accepted') ? () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DeliveryTrackingScreen(orderId: order.id)));
                        } : null,
                      );
                    },
                    childCount: orders.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'delivered': return const Color(0xFF10B981);
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _mapStatus(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'accepted': return 'Validée';
      case 'delivered': return 'Livrée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  Widget _buildPremiumMiniStat(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildClientActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOrderTile(String title, String date, String details, String status, Color color, {VoidCallback? onTrack}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(status == "delivered" ? Icons.check_circle_rounded : Icons.pending_rounded, color: color, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(date, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(details, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(
                    _mapStatus(status).toUpperCase(),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ],
              )
            ],
          ),
          if (onTrack != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onTrack,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text("SUIVRE MON LIVREUR", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
