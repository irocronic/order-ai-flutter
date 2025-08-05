// lib/widgets/shared/image_display.dart

import 'package:flutter/material.dart';

Widget buildImage(String? imageUrl, IconData defaultIcon, double size) {

  if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
    return Image.network(
      imageUrl, // Doğrudan Firebase URL'sini kullan
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, size: size * 0.6, color: Colors.grey[400]),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: size,
          height: size,
          color: Colors.grey[300]?.withOpacity(0.5),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.blueAccent,
            ),
          ),
        );
      },
    );
  } else {
    // Eğer geçerli bir URL yoksa veya boşsa varsayılan ikonu göster
    return Icon(defaultIcon, size: size * 0.6, color: Colors.grey[400]);
  }
}
