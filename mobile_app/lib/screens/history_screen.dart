import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/data_service_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<dynamic> _deliveries = [];
  List<dynamic> _filteredDeliveries = [];
  bool _isLoading = true;
  bool _showFilters = false;

   
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedClient;
  double? _minAmount;
  double? _maxAmount;
  String _searchQuery = '';

   
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _loadHistory() async {
    try {
      final data = await ref.read(dataServiceProvider).getMyDeliveries();
      if (!mounted) return;
      
       
      if (data.isEmpty) {
        _deliveries = _getMockDeliveries();
      } else {
        _deliveries = data;
      }
      
      _applyFilters();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
       
      setState(() {
        _deliveries = _getMockDeliveries();
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDeliveries = _deliveries.where((delivery) {
         
        if (_searchQuery.isNotEmpty) {
          final clientName = delivery['client_name']?.toString().toLowerCase() ?? '';
          if (!clientName.contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

         
        if (_selectedClient != null && _selectedClient!.isNotEmpty) {
          if (delivery['client_name'] != _selectedClient) {
            return false;
          }
        }

         
        if (_minAmount != null) {
          final amount = (delivery['total_amount'] as num?)?.toDouble() ?? 0;
          if (amount < _minAmount!) {
            return false;
          }
        }

         
        if (_maxAmount != null) {
          final amount = (delivery['total_amount'] as num?)?.toDouble() ?? 0;
          if (amount > _maxAmount!) {
            return false;
          }
        }

         
        if (_startDate != null || _endDate != null) {
          final deliveryDateStr = delivery['created_at']?.toString() ?? '';
          try {
             
            final parts = deliveryDateStr.split(' ');
            if (parts.isNotEmpty) {
              final dateParts = parts[0].split('-');
              if (dateParts.length == 3) {
                final deliveryDate = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );

                if (_startDate != null && deliveryDate.isBefore(_startDate!)) {
                  return false;
                }

                if (_endDate != null) {
                  final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
                  if (deliveryDate.isAfter(endOfDay)) {
                    return false;
                  }
                }
              }
            }
          } catch (e) {
             
          }
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedClient = null;
      _minAmount = null;
      _maxAmount = null;
      _searchQuery = '';
      _searchController.clear();
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    _applyFilters();
  }

  List<Map<String, dynamic>> _getMockDeliveries() {
    return [
      {
        'id': 1,
        'client_name': 'IAI TOGO',
        'quantity_vitale': 2,
        'quantity_voltic': 3,
        'total_amount': 2500,
        'created_at': '2024-01-20 08:30',
        'status': 'completed'
      },
      {
        'id': 2,
        'client_name': 'Boutique Test',
        'quantity_vitale': 1,
        'quantity_voltic': 2,
        'total_amount': 1500,
        'created_at': '2024-01-21 09:15',
        'status': 'completed'
      },
      {
        'id': 3,
        'client_name': 'Marché Central',
        'quantity_vitale': 5,
        'quantity_voltic': 4,
        'total_amount': 4500,
        'created_at': '2024-01-22 10:45',
        'status': 'completed'
      },
      {
        'id': 4,
        'client_name': 'Supermarché ESSIVI',
        'quantity_vitale': 3,
        'quantity_voltic': 6,
        'total_amount': 5100,
        'created_at': '2024-01-23 14:20',
        'status': 'completed'
      },
      {
        'id': 5,
        'client_name': 'Pharmacie Centrale',
        'quantity_vitale': 4,
        'quantity_voltic': 2,
        'total_amount': 3200,
        'created_at': '2024-01-24 11:00',
        'status': 'completed'
      },
    ];
  }

  List<String> _getUniqueClients() {
    final clients = _deliveries.map((d) => d['client_name']?.toString() ?? '').where((name) => name.isNotEmpty).toSet().toList();
    clients.sort();
    return clients;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("HISTORIQUE", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, color: Colors.white),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
           
          if (_showFilters) _buildFiltersSection(),
          
           
          Container(
            margin: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            ),
          ),

           
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Total", "${_filteredDeliveries.length}", Colors.blue),
                _buildStatItem(
                  "Articles", 
                  "${_filteredDeliveries.fold<int>(0, (sum, delivery) {
                    final items = delivery['items'] as List? ?? [];
                    return sum + items.fold<int>(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0));
                  })}", 
                  Colors.orange
                ),
                _buildStatItem(
                  "CA", 
                  "${(_filteredDeliveries.fold<num>(0, (sum, item) => sum + (item['total_amount'] ?? 0)).toInt())} F", 
                  Colors.green
                ),
              ],
            ),
          ),
          
           
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _filteredDeliveries.isEmpty
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
                              child: Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey.shade200),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _deliveries.isEmpty 
                                    ? "Aucune livraison trouvée ou erreur réseau" 
                                    : "Aucune livraison ne correspond aux filtres",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadHistory,
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
                    : RefreshIndicator(
                        onRefresh: () async => _loadHistory(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredDeliveries.length,
                          itemBuilder: (context, index) {
                            final item = _filteredDeliveries[index];
                            final items = item['items'] as List? ?? [];
                            
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _showDeliveryDetails(item);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Row(
                                        children: [
                                           
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 24),
                                          ),
                                          const SizedBox(width: 16),
                                          
                                           
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['client_name'] ?? 'Client Inconnu',
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                SingleChildScrollView(
                                                  scrollDirection: Axis.horizontal,
                                                  child: Row(
                                                    children: items.map((i) => Padding(
                                                      padding: const EdgeInsets.only(right: 4),
                                                      child: _buildBadge("${i['product_name']} x${i['quantity']}", Colors.blue),
                                                    )).toList(),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade400),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      item['created_at'] ?? 'Date inconnue',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                           
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                "${item['total_amount']} F",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900, 
                                                  fontSize: 16, 
                                                  color: Color(0xFF10B981)
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  "TERMINÉE",
                                                  style: TextStyle(fontSize: 9, color: Color(0xFF065F46), fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                                ),
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "FILTRES",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text("Effacer tout", style: TextStyle(color: Color(0xFFEF4444))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
           
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _startDate != null 
                                ? "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}"
                                : "Date début",
                            style: TextStyle(fontSize: 14, color: _startDate != null ? Colors.black : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(false),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _endDate != null 
                                ? "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}"
                                : "Date fin",
                            style: TextStyle(fontSize: 14, color: _endDate != null ? Colors.black : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
           
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Client',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedClient,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous les clients')),
              ..._getUniqueClients().map((client) {
                return DropdownMenuItem(value: client, child: Text(client));
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedClient = value;
              });
              _applyFilters();
            },
          ),
          
          const SizedBox(height: 12),
          
           
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minAmountController,
                  decoration: InputDecoration(
                    labelText: 'Montant min',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _minAmount = value.isNotEmpty ? double.tryParse(value) : null;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxAmountController,
                  decoration: InputDecoration(
                    labelText: 'Montant max',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _maxAmount = value.isNotEmpty ? double.tryParse(value) : null;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate 
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _applyFilters();
    }
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900),
      ),
    );
  }

  void _showDeliveryDetails(Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Détails Livraison #${delivery['id']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Client: ${delivery['client_name'] ?? 'Inconnu'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Contenu:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ...(delivery['items'] as List? ?? []).map((i) => Text("• ${i['product_name']}: ${i['quantity']}")),
            const SizedBox(height: 8),
            Text("Montant: ${delivery['total_amount']} F", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            Text("Date: ${delivery['created_at']}"),
          ],
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
