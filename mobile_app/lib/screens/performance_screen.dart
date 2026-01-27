import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../presentation/providers/data_service_provider.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  List<dynamic> _deliveries = [];
  bool _isLoading = true;
  String _selectedPeriod = '7j'; // 7j, 30j, 90j

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  void _loadPerformanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ref.read(dataServiceProvider).getMyDeliveries();
      if (!mounted) return;
      
      // Si aucune donnée, ajouter des données de test
      if (data.isEmpty) {
        _deliveries = _getMockDeliveries();
      } else {
        _deliveries = data;
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deliveries = _getMockDeliveries();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMockDeliveries() {
    final now = DateTime.now();
    return List.generate(30, (index) {
      final date = now.subtract(Duration(days: index));
      return {
        'id': index + 1,
        'client_name': ['IAI TOGO', 'Boutique Test', 'Marché Central', 'Supermarché ESSIVI', 'Pharmacie Centrale'][index % 5],
        'quantity_vitale': (index % 5) + 1,
        'quantity_voltic': (index % 4) + 2,
        'total_amount': 1500 + (index * 100),
        'created_at': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        'status': 'completed'
      };
    });
  }

  List<Map<String, dynamic>> _getFilteredDeliveries() {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedPeriod) {
      case '7j':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '30j':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case '90j':
        startDate = now.subtract(const Duration(days: 90));
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    return _deliveries.where((delivery) {
      try {
        final dateStr = delivery['created_at']?.toString() ?? '';
        final parts = dateStr.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('-');
          if (dateParts.length == 3) {
            final deliveryDate = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
            );
            return deliveryDate.isAfter(startDate) || deliveryDate.isAtSameMomentAs(startDate);
          }
        }
      } catch (e) {
        // Ignorer les erreurs de parsing
      }
      return false;
    }).cast<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _getStatistics() {
    final filtered = _getFilteredDeliveries();
    
    final totalDeliveries = filtered.length;
    final totalAmount = filtered.fold<double>(0, (sum, item) => sum + ((item['total_amount'] as num?)?.toDouble() ?? 0));
    final totalVitale = filtered.fold<int>(0, (sum, item) => sum + ((item['quantity_vitale'] as num?)?.toInt() ?? 0));
    final totalVoltic = filtered.fold<int>(0, (sum, item) => sum + ((item['quantity_voltic'] as num?)?.toInt() ?? 0));
    
    final avgAmount = totalDeliveries > 0 ? totalAmount / totalDeliveries : 0;
    
    return {
      'totalDeliveries': totalDeliveries,
      'totalAmount': totalAmount,
      'totalVitale': totalVitale,
      'totalVoltic': totalVoltic,
      'avgAmount': avgAmount,
    };
  }

  List<BarChartGroupData> _getDailySalesData() {
    final filtered = _getFilteredDeliveries();
    final Map<String, double> dailyData = {};
    
    for (final delivery in filtered) {
      try {
        final dateStr = delivery['created_at']?.toString() ?? '';
        final date = dateStr.split(' ')[0];
        final amount = (delivery['total_amount'] as num?)?.toDouble() ?? 0;
        dailyData[date] = (dailyData[date] ?? 0) + amount;
      } catch (e) {
        // Ignorer les erreurs
      }
    }
    
    final sortedDates = dailyData.keys.toList()..sort();
    final maxAmount = dailyData.values.isNotEmpty ? dailyData.values.reduce((a, b) => a > b ? a : b) : 1000;
    
    return sortedDates.map((date) {
      final amount = dailyData[date] ?? 0;
      final parts = date.split('-');
      final day = parts.length >= 3 ? parts[2] : '';
      
      return BarChartGroupData(
        x: sortedDates.indexOf(date),
        barRods: [
          BarChartRodData(
            toY: amount,
            color: const Color(0xFF3B82F6),
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _getProductDistribution() {
    final filtered = _getFilteredDeliveries();
    final totalVitale = filtered.fold<int>(0, (sum, item) => sum + ((item['quantity_vitale'] as num?)?.toInt() ?? 0));
    final totalVoltic = filtered.fold<int>(0, (sum, item) => sum + ((item['quantity_voltic'] as num?)?.toInt() ?? 0));
    final total = totalVitale + totalVoltic;
    
    if (total == 0) return [];
    
    return [
      PieChartSectionData(
        color: const Color(0xFF06B6D4),
        value: totalVitale.toDouble(),
        title: 'Vitale\n${((totalVitale / total) * 100).toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFFF97316),
        value: totalVoltic.toDouble(),
        title: 'Voltic\n${((totalVoltic / total) * 100).toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStatistics();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("PERFORMANCE", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPerformanceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PÉRIODE SELECTOR
                  _buildPeriodSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // KPI CARDS
                  _buildKPICards(stats),
                  
                  const SizedBox(height: 24),
                  
                  // VENTES PAR JOUR GRAPH
                  _buildDailySalesChart(),
                  
                  const SizedBox(height: 24),
                  
                  // PRODUITS DISTRIBUTION
                  Row(
                    children: [
                      Expanded(child: _buildProductDistributionChart()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTopClients()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPeriodButton('7j', '7 jours'),
          _buildPeriodButton('30j', '30 jours'),
          _buildPeriodButton('90j', '90 jours'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String value, String label) {
    final isSelected = _selectedPeriod == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPICards(Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKPICard('Livraisons', '${stats['totalDeliveries']}', Icons.local_shipping, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('CA Total', '${stats['totalAmount'].toStringAsFixed(0)} F', Icons.attach_money, Colors.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard('Panier Moyen', '${stats['avgAmount'].toStringAsFixed(0)} F', Icons.shopping_cart, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('Produits', '${stats['totalVitale'] + stats['totalVoltic']}', Icons.inventory, Colors.purple)),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: Colors.green.shade400, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySalesChart() {
    final dailyData = _getDailySalesData();
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Ventes par jour',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: dailyData.isNotEmpty 
                    ? (dailyData.map((group) => group.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2)
                    : 1000,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final value = rod.toY.toStringAsFixed(0);
                      return BarTooltipItem(
                        '$value F',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dailyData.length) return const Text('');
                        
                        // Récupérer la date depuis les données filtrées
                        final filtered = _getFilteredDeliveries();
                        if (filtered.isEmpty) return const Text('');
                        
                        try {
                          final dateStr = filtered[index]['created_at']?.toString() ?? '';
                          final parts = dateStr.split(' ');
                          if (parts.isNotEmpty) {
                            final dateParts = parts[0].split('-');
                            if (dateParts.length >= 3) {
                              final day = dateParts[2];
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  day,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Ignorer les erreurs
                        }
                        
                        return const Text('');
                      },
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: dailyData,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDistributionChart() {
    final pieData = _getProductDistribution();
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Distribution produits',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: pieData,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Vitale', const Color(0xFF06B6D4)),
              const SizedBox(width: 20),
              _buildLegendItem('Voltic', const Color(0xFFF97316)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTopClients() {
    final filtered = _getFilteredDeliveries();
    final Map<String, int> clientCounts = {};
    
    for (final delivery in filtered) {
      final client = delivery['client_name']?.toString() ?? '';
      clientCounts[client] = (clientCounts[client] ?? 0) + 1;
    }
    
    final sortedClients = clientCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Top clients',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          ...sortedClients.take(5).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value} livraisons',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
