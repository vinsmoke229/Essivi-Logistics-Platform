import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/profile_service.dart';
import '../widgets/profile_photo_widget.dart';
import '../presentation/providers/auth_provider.dart';
import '../models/vehicle_model.dart';
import 'login_screen.dart';

class AgentProfileScreen extends ConsumerStatefulWidget {
  const AgentProfileScreen({super.key});

  @override
  ConsumerState<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends ConsumerState<AgentProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;
  bool _isLoading = false;

  // Informations agent initialisées vides (seront chargées depuis l'API)
  Map<String, dynamic> _agentInfo = {};

  @override
  void initState() {
    super.initState();
    _loadAgentProfile();
  }

  Future<void> _loadAgentProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final profileInfo = await _profileService.getProfileInfo();
      if (!mounted) return;
      if (profileInfo != null) {
        setState(() {
          _agentInfo = profileInfo;
        });
      }

      final localPhotoPath = await _profileService.getLocalProfilePhotoPath();
      if (!mounted) return;
      if (localPhotoPath != null && File(localPhotoPath).existsSync()) {
        setState(() {
          _profileImage = File(localPhotoPath);
        });
      }
    } catch (e) {
      print('Erreur chargement profil: $e');
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        await _uploadProfilePhoto();
      }
    } catch (e) {
      _showErrorDialog('Erreur lors de la sélection de l\'image: $e');
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_profileImage == null) return;

    try {
      // Sauvegarder localement d'abord
      await _profileService.saveLocalProfilePhotoPath(_profileImage!.path);
      
      // Uploader vers le backend
      final success = await _profileService.updateProfilePhoto(_profileImage!);
      
      if (success) {
        _showSuccessDialog('Photo de profil mise à jour avec succès !');
      } else {
        _showErrorDialog('Erreur lors de l\'upload. La photo a été sauvegardée localement.');
      }
    } catch (e) {
      _showErrorDialog('Erreur lors de l\'upload: $e');
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisir une photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _ImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            const Text('Succès'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            const Text('Erreur'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSection() {
    final tricyclePlate = _agentInfo['tricycle_plate'] ?? "Non assigné";
    
    final vehicle = VehicleModel(
      id: '1',
      plateNumber: tricyclePlate,
      brand: 'Tricycle ESSIVI',
      model: 'Transport Eau',
      color: 'Gris Métallique',
      year: 2024,
      status: tricyclePlate != "Non assigné" ? 'active' : 'inactive',
      assignedAt: DateTime.now().subtract(const Duration(days: 30)),
      assignedBy: 'Logistique',
    );

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
          Row(
            children: [
              Icon(Icons.motorcycle, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 12),
              const Text(
                'TRICYCLE ASSIGNÉ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: vehicle.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vehicle.statusDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: vehicle.statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Carte du véhicule
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.pedal_bike,
                        color: Colors.blue.shade600,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Année ${vehicle.year} • ${vehicle.color}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Informations détaillées
                Row(
                  children: [
                    Expanded(
                      child: _buildVehicleInfo(
                        Icons.confirmation_number,
                        'Plaque',
                        vehicle.plateNumber,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildVehicleInfo(
                        Icons.calendar_today,
                        'Assigné le',
                        vehicle.assignedAt != null 
                            ? '${vehicle.assignedAt!.day}/${vehicle.assignedAt!.month}/${vehicle.assignedAt!.year}'
                            : 'N/A',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showVehicleDetails(vehicle);
                  },
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Détails'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    side: BorderSide(color: Colors.blue.shade600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showMaintenanceDialog(vehicle);
                  },
                  icon: const Icon(Icons.build, size: 16),
                  label: const Text('Maintenance'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade600,
                    side: BorderSide(color: Colors.orange.shade600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
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
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  void _showVehicleDetails(VehicleModel vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.motorcycle, color: Colors.blue.shade600),
            const SizedBox(width: 12),
            const Text('Détails du véhicule'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Marque', vehicle.brand),
            _buildDetailRow('Modèle', vehicle.model),
            _buildDetailRow('Plaque', vehicle.plateNumber),
            _buildDetailRow('Couleur', vehicle.color),
            _buildDetailRow('Année', vehicle.year.toString()),
            _buildDetailRow('Statut', vehicle.statusDisplay),
            if (vehicle.assignedAt != null)
              _buildDetailRow('Date assignation', 
                '${vehicle.assignedAt!.day}/${vehicle.assignedAt!.month}/${vehicle.assignedAt!.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('FERMER'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(VehicleModel vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.build, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Maintenance'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Signaler un problème pour le véhicule ${vehicle.displayName} ?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: 'Description du problème',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demande de maintenance envoyée'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('ENVOYER'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label :',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DÉCONNECTER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "MON PROFIL",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // SECTION PHOTO DE PROFIL
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ProfilePhotoWidget(
                          imageUrl: _profileImage?.path,
                          size: 100,
                          showEditButton: true,
                          onEditTap: _showImagePicker,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _agentInfo['name']?.toString() ?? 'Agent...',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _agentInfo['matricule']?.toString() ?? _agentInfo['agent_id']?.toString() ?? 'ID Agent...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                   // SECTION INFORMATIONS PERSONNELLES
                  _buildInfoSection(
                    'INFORMATIONS PERSONNELLES',
                    [
                      _buildInfoRow(Icons.person, 'Nom complet', _agentInfo['name']?.toString() ?? 'Inconnu'),
                      _buildInfoRow(Icons.badge, 'ID Agent', _agentInfo['agent_id']?.toString() ?? 'Non défini'),
                      _buildInfoRow(Icons.credit_card, 'Matricule', _agentInfo['matricule']?.toString() ?? _agentInfo['identifier']?.toString() ?? 'N/A'),
                      _buildInfoRow(Icons.phone, 'Téléphone', _agentInfo['phone']?.toString() ?? 'Non renseigné'),
                      _buildInfoRow(Icons.email, 'Email', _agentInfo['email']?.toString() ?? 'Non renseigné'),
                      _buildInfoRow(Icons.business, 'Département', _agentInfo['department']?.toString() ?? 'Opérations'),
                      _buildInfoRow(Icons.location_on, 'Région', _agentInfo['region']?.toString() ?? 'Maritime'),
                      _buildInfoRow(Icons.calendar_today, 'Date d\'embauche', _agentInfo['join_date']?.toString() ?? 'Janvier 2024'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // SECTION TRICYCLE ASSIGNÉ
                  _buildVehicleSection(),

                  const SizedBox(height: 24),

                  // SECTION STATISTIQUES
                  _buildInfoSection(
                    'PERFORMANCE',
                    [
                      _buildInfoRow(Icons.local_shipping, 'Total livraisons', 
                          (_agentInfo['stats']?['total_deliveries'] ?? 0).toString()),
                      _buildInfoRow(Icons.attach_money, 'Montant total', 
                          _agentInfo['stats'] != null && _agentInfo['stats']['total_revenue'] != null 
                            ? "${NumberFormat("#,###", "fr_FR").format(_agentInfo['stats']['total_revenue'])} FCFA" 
                            : '0 FCFA'),
                      _buildInfoRow(Icons.star, 'Note moyenne', 
                          "${_agentInfo['stats']?['average_rating']?.toString() ?? '4.8'} ⭐"),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // BOUTON DÉCONNEXION
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.red],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        _showLogoutConfirmation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Text(
                        'DÉCONNEXION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ImagePickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF0EA5E9), width: 2),
            ),
            child: Icon(icon, color: const Color(0xFF0EA5E9), size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
