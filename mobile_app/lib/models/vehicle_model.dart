import 'package:flutter/material.dart';

class VehicleModel {
  final String id;
  final String plateNumber;
  final String brand;
  final String model;
  final String color;
  final int year;
  final String status; // 'active', 'maintenance', 'inactive'
  final DateTime? assignedAt;
  final String? assignedBy;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.brand,
    required this.model,
    required this.color,
    required this.year,
    required this.status,
    this.assignedAt,
    this.assignedBy,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      year: json['year']?.toInt() ?? DateTime.now().year,
      status: json['status']?.toString() ?? 'inactive',
      assignedAt: json['assigned_at'] != null 
          ? DateTime.parse(json['assigned_at']) 
          : null,
      assignedBy: json['assigned_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plate_number': plateNumber,
      'brand': brand,
      'model': model,
      'color': color,
      'year': year,
      'status': status,
      'assigned_at': assignedAt?.toIso8601String(),
      'assigned_by': assignedBy,
    };
  }

  String get displayName => '$brand $model ($plateNumber)';
  
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Actif';
      case 'maintenance':
        return 'En maintenance';
      case 'inactive':
        return 'Inactif';
      default:
        return 'Inconnu';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
