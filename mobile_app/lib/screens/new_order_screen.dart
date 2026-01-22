import 'package:flutter/material.dart';
import '../services/data_service.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyVitaleController = TextEditingController(text: '0');
  final _qtyVolticController = TextEditingController(text: '0');
  final _timeController = TextEditingController();
  final _instructionsController = TextEditingController();
  
  bool _isLoading = false;
  final DataService _dataService = DataService();

  void _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await _dataService.sendOrder(
      qtyVitale: int.parse(_qtyVitaleController.text),
      qtyVoltic: int.parse(_qtyVolticController.text),
      preferredTime: _timeController.text,
      instructions: _instructionsController.text
    );
    
    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Commande envoyée au gestionnaire ! 📝"), backgroundColor: Colors.green),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    Expanded(
                      child: _buildQuantityField(
                        controller: _qtyVitaleController,
                        label: "VITALE",
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildQuantityField(
                        controller: _qtyVolticController,
                        label: "VOLTIC",
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                
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
                
                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _isLoading ? Colors.transparent : Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isLoading 
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
