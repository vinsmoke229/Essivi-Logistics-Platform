import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/data_service_provider.dart';
import '../presentation/providers/client_provider.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _timeController = TextEditingController();
  final _instructionsController = TextEditingController();
  
  List<dynamic> _products = [];
  final Map<int, int> _quantities = {};
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ref.read(dataServiceProvider).getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          for (var p in products) {
            _quantities[p['id']] = 0;
          }
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  void _submitOrder() async {
    final items = _quantities.entries
        .where((e) => e.value > 0)
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez commander au moins un article")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();

    final success = await ref.read(clientProvider.notifier).createOrder(
      items: items,
      preferredTime: _timeController.text,
      instructions: _instructionsController.text,
    );
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Commande envoyée au gestionnaire ! 📝"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'envoi de la commande"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("NOUVELLE COMMANDE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("COMMANDEZ VOS PAQUETS"),
                const SizedBox(height: 16),
                
                if (_isLoadingProducts)
                  const Center(child: CircularProgressIndicator())
                else if (_products.isEmpty)
                   const Text("Aucun produit disponible")
                else
                  ..._products.map((prod) {
                    final int pid = prod['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod['name'].toString().toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B)),
                                ),
                                Text("${prod['price']} FCFA / unité", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.blue, size: 20),
                                onPressed: () {
                                  if ((_quantities[pid] ?? 0) > 0) {
                                    setState(() {
                                      _quantities[pid] = _quantities[pid]! - 1;
                                    });
                                  }
                                },
                              ),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  "${_quantities[pid] ?? 0}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _quantities[pid] = (_quantities[pid] ?? 0) + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                
                const SizedBox(height: 32),
                _buildSectionHeader("LOGISTIQUE DE LIVRAISON"),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _timeController,
                  label: "HEURE DE LIVRAISON PRÉFÉRÉE",
                  icon: Icons.access_time_filled_rounded,
                  hint: "Ex: Demain avant 10h",
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("INSTRUCTIONS SUPPLÉMENTAIRES"),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _instructionsController,
                  label: "NOTES",
                  icon: Icons.note_add_rounded,
                  hint: "Précisions sur le lieu ou le contact...",
                  maxLines: 3,
                ),

                const SizedBox(height: 48),
                
                 
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: clientState.isLoading ? Colors.transparent : Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: clientState.isLoading || _isLoadingProducts ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: clientState.isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("VALIDER LA COMMANDE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5),
    );
  }

  Widget _buildQuantityField({required TextEditingController controller, required String label, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: Colors.blue, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
