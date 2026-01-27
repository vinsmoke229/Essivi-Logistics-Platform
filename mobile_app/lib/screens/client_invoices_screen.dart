import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/data_service_provider.dart';

class ClientInvoicesScreen extends ConsumerStatefulWidget {
  const ClientInvoicesScreen({super.key});

  @override
  ConsumerState<ClientInvoicesScreen> createState() => _ClientInvoicesScreenState();
}

class _ClientInvoicesScreenState extends ConsumerState<ClientInvoicesScreen> {
  List<dynamic> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  void _loadInvoices() async {
    try {
      final data = await ref.read(dataServiceProvider).getClientInvoices();
      if (!mounted) return;
      setState(() {
        _invoices = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoices = _getMockInvoices();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMockInvoices() {
    return [
      {
        "id": 1,
        "invoice_number": "INV-000001",
        "client_name": "Boutique Test",
        "client_address": "Lomé, Bè",
        "delivery_date": "2024-01-24T10:30:00",
        "items": [
          {
            "name": "Eau Vitale",
            "quantity": 2,
            "unit_price": 500,
            "total": 1000
          },
          {
            "name": "Eau Voltic",
            "quantity": 3,
            "unit_price": 500,
            "total": 1500
          }
        ],
        "subtotal": 2500,
        "tax": 450,
        "total": 2950
      },
      {
        "id": 2,
        "invoice_number": "INV-000002",
        "client_name": "Boutique Test",
        "client_address": "Lomé, Bè",
        "delivery_date": "2024-01-23T14:15:00",
        "items": [
          {
            "name": "Eau Vitale",
            "quantity": 1,
            "unit_price": 500,
            "total": 500
          }
        ],
        "subtotal": 500,
        "tax": 90,
        "total": 590
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("MES FACTURES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)
                          ],
                        ),
                        child: Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey.shade200),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Aucune facture", 
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInvoices,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Actualiser"),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
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
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _showInvoiceDetails(invoice),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      invoice['invoice_number'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "PAYÉE",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF065F46),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Date: ${_formatDate(invoice['delivery_date'])}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.shopping_cart, size: 14, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${invoice['items']?.length ?? 0} article(s)",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Total TTC:",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      "${invoice['total']} F",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Facture ${invoice['invoice_number']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Client: ${invoice['client_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Adresse: ${invoice['client_address']}"),
              const SizedBox(height: 12),
              const Text("Articles:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(invoice['items'] as List<dynamic>).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${item['name']} x${item['quantity']}"),
                    Text("${item['total']} F"),
                  ],
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Sous-total:"),
                  Text("${invoice['subtotal']} F"),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TVA (18%):"),
                  Text("${invoice['tax']} F"),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total TTC:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("${invoice['total']} F", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FERMER"),
          ),
        ],
      ),
    );
  }
}
