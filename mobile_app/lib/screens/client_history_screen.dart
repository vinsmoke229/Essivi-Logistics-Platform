import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../presentation/providers/data_service_provider.dart';

class ClientHistoryScreen extends ConsumerStatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  ConsumerState<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends ConsumerState<ClientHistoryScreen> {
  List<dynamic> _orders = [];
  List<dynamic> _deliveries = [];
  bool _isLoading = true;
  String _selectedTab = 'orders';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final ordersData = await ref.read(dataServiceProvider).getClientOrders();
      final deliveriesData = await ref.read(dataServiceProvider).getClientDeliveries();
      if (!mounted) return;
      setState(() {
        _orders = ordersData;
        _deliveries = deliveriesData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orders = _getMockOrders();
        _deliveries = _getMockDeliveries();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMockOrders() {
    return [
      {
        "id": 1,
        "status": "completed",
        "items": [
          {"product_name": "Vitale", "quantity": 2},
          {"product_name": "Voltic", "quantity": 3}
        ],
        "preferred_time": "Matin",
        "special_instructions": "Livraison à l'arrière du magasin",
        "created_at": "2024-01-24T08:30:00",
        "total_amount": 2500
      },
      {
        "id": 2,
        "status": "pending",
        "items": [
          {"product_name": "Vitale", "quantity": 1},
          {"product_name": "Voltic", "quantity": 2}
        ],
        "preferred_time": "Après-midi",
        "special_instructions": "",
        "created_at": "2024-01-24T10:15:00",
        "total_amount": 1500
      },
    ];
  }

  List<Map<String, dynamic>> _getMockDeliveries() {
    return [
      {
        "id": 1,
        "items": [
          {"product_name": "Vitale", "quantity": 2},
          {"product_name": "Voltic", "quantity": 3}
        ],
        "total_amount": 2500,
        "date": "2024-01-24T09:45:00",
        "status": "completed",
        "gps_lat": 6.123456,
        "gps_lng": 1.234567
      },
      {
        "id": 2,
        "items": [
          {"product_name": "Vitale", "quantity": 1},
          {"product_name": "Voltic", "quantity": 1}
        ],
        "total_amount": 1000,
        "date": "2024-01-23T14:30:00",
        "status": "completed",
        "gps_lat": 6.124567,
        "gps_lng": 1.235678
      },
    ];
  }

  Future<void> _generateAndPrintPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("RECEPISSE D'HISTORIQUE - ESSIVI Sarl", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                pw.Text(DateTime.now().toString().substring(0, 16)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text("Historique des livraisons pour le client : ${_orders.isNotEmpty ? 'Client ESSIVI' : 'Utilisateur'}", 
            style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            headers: ['ID', 'Date', 'Type', 'Statut', 'Montant (F)'],
            data: [
              ..._orders.map((o) => [
                o['id'].toString(),
                _formatDate(o['created_at']),
                'Commande',
                o['status'],
                o['total_amount'].toString(),
              ]),
              ..._deliveries.map((d) => [
                d['id'].toString(),
                _formatDate(d['date']),
                'Livraison',
                d['status'],
                d['total_amount'].toString(),
              ]),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total cumulé: ${[..._orders, ..._deliveries].fold(0.0, (sum, item) {
                final amt = item['total_amount'];
                double val = 0.0;
                if (amt is num) val = amt.toDouble();
                else if (amt is String) val = double.tryParse(amt) ?? 0.0;
                return sum + val;
              }).toStringAsFixed(0)} F CFA",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
            ),
          ),
          pw.SizedBox(height: 50),
          pw.Center(child: pw.Text("Merci pour votre confiance en ESSIVI Sarl", style: pw.TextStyle(fontStyle: pw.FontStyle.italic))),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("MON HISTORIQUE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            onPressed: () {
              if (_orders.isEmpty && _deliveries.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune donnée à exporter")));
                return;
              }
              _generateAndPrintPdf();
            },
            tooltip: "Exporter Rapport",
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // TABS
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 'orders'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'orders' ? const Color(0xFF0F172A) : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        "COMMANDES",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'orders' ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 'deliveries'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'deliveries' ? const Color(0xFF0F172A) : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        "LIVRAISONS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'deliveries' ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // CONTENT
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _selectedTab == 'orders'
                    ? _buildOrdersList()
                    : _buildDeliveriesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 24),
            Text(
              "Aucune commande", 
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Commande #${order['id']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    _buildStatusBadge(order['status']),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: (order['items'] as List? ?? []).map((i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildQuantityBadge(i['product_name'], i['quantity'], Colors.blue),
                  )).toList(),
                ),
                if (order['preferred_time']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        "Préférence: ${order['preferred_time']}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
                if (order['special_instructions']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order['special_instructions'],
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Date: ${_formatDate(order['created_at'])}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      "${order['total_amount']} F",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliveriesList() {
    if (_deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 24),
            Text(
              "Aucune livraison", 
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _deliveries.length,
      itemBuilder: (context, index) {
        final delivery = _deliveries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Livraison #${delivery['id']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    _buildStatusBadge(delivery['status']),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: (delivery['items'] as List? ?? []).map((item) {
                    final pName = item['product_name'] ?? 'Produit';
                    final qty = item['quantity'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildQuantityBadge(pName, qty is int ? qty : int.tryParse(qty.toString()) ?? 0, Colors.blue),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Date: ${_formatDate(delivery['date'])}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (delivery['status'] == 'completed') 
                      ElevatedButton.icon(
                        onPressed: () => _showRatingDialog(delivery['id']),
                        icon: const Icon(Icons.star_rounded, size: 14),
                        label: const Text("NOTER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    Text(
                      "${delivery['total_amount']} F",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'completed':
        color = Colors.green;
        text = "TERMINÉE";
        break;
      case 'pending':
        color = Colors.orange;
        text = "EN ATTENTE";
        break;
      case 'cancelled':
        color = Colors.red;
        text = "ANNULÉE";
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildQuantityBadge(String label, int quantity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$label: $quantity",
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _showRatingDialog(int deliveryId) {
    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Noter le service", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Quelle note donnez-vous à cette livraison ?"),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(
                    index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.orange,
                    size: 32,
                  ),
                  onPressed: () => setDialogState(() => rating = index + 1),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: "Un commentaire ? (Optionnel)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Appel API via dataServiceProvider ou directement Dio
                  await ref.read(dataServiceProvider).postEvaluation({
                    "delivery_id": deliveryId,
                    "rating": rating,
                    "comment": commentController.text,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Merci pour votre avis !")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              child: const Text("ENVOYER"),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
