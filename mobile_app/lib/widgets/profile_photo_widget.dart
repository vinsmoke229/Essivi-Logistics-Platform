import 'package:flutter/material.dart';
import 'dart:io';

class ProfilePhotoWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool showEditButton;
  final VoidCallback? onEditTap;

  const ProfilePhotoWidget({
    super.key,
    this.imageUrl,
    this.size = 80,
    this.showEditButton = true,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipOval(
            child: _buildImage(),
          ),
          if (showEditButton && onEditTap != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: onEditTap,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(size * 0.15),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Si c'est un fichier local
      if (imageUrl!.startsWith('/') || imageUrl!.contains('\\')) {
        return Image.file(
          File(imageUrl!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }
      // Si c'est une URL
      else {
        return Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFF1F5F9),
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: Colors.grey.shade400,
      ),
    );
  }
}
