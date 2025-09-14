// lib/models/business_website.dart

import 'package:flutter/foundation.dart';

class BusinessWebsite {
  final String? aboutTitle;
  final String? aboutDescription;
  final String? aboutImage;
  final String? contactPhone;
  final String? contactEmail;
  final String? contactAddress;
  final String? contactWorkingHours;
  final String? websiteTitle;
  final String? websiteDescription;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? twitterUrl;
  final String primaryColor;
  final String secondaryColor;
  final bool showMenu;
  final bool showContact;
  final bool showMap;
  final bool isActive;

  BusinessWebsite({
    this.aboutTitle,
    this.aboutDescription,
    this.aboutImage,
    this.contactPhone,
    this.contactEmail,
    this.contactAddress,
    this.contactWorkingHours,
    this.websiteTitle,
    this.websiteDescription,
    this.facebookUrl,
    this.instagramUrl,
    this.twitterUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.showMenu,
    required this.showContact,
    required this.showMap,
    required this.isActive,
  });

  factory BusinessWebsite.fromJson(Map<String, dynamic> json) {
    return BusinessWebsite(
      aboutTitle: json['about_title'] as String?,
      aboutDescription: json['about_description'] as String?,
      aboutImage: json['about_image'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactAddress: json['contact_address'] as String?,
      contactWorkingHours: json['contact_working_hours'] as String?,
      websiteTitle: json['website_title'] as String?,
      websiteDescription: json['website_description'] as String?,
      facebookUrl: json['facebook_url'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      twitterUrl: json['twitter_url'] as String?,
      primaryColor: json['primary_color'] as String? ?? '#3B82F6',
      secondaryColor: json['secondary_color'] as String? ?? '#10B981',
      showMenu: json['show_menu'] as bool? ?? true,
      showContact: json['show_contact'] as bool? ?? true,
      showMap: json['show_map'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Sadece güncellenebilir alanları içeren bir JSON haritası oluşturur.
  Map<String, dynamic> toJsonForUpdate({
    required String aboutTitle,
    required String aboutDescription,
    String? aboutImage, // Resim değişmediyse null olabilir
    required String contactPhone,
    required String contactEmail,
    required String contactAddress,
    required String contactWorkingHours,
    required String websiteTitle,
    required String websiteDescription,
    required String facebookUrl,
    required String instagramUrl,
    required String twitterUrl,
    required String primaryColor,
    required String secondaryColor,
    required bool showMenu,
    required bool showContact,
    required bool showMap,
  }) {
    final Map<String, dynamic> data = {
      'about_title': aboutTitle,
      'about_description': aboutDescription,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'contact_address': contactAddress,
      'contact_working_hours': contactWorkingHours,
      'website_title': websiteTitle,
      'website_description': websiteDescription,
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'twitter_url': twitterUrl,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'show_menu': showMenu,
      'show_contact': showContact,
      'show_map': showMap,
    };
    // Sadece yeni bir resim URL'si varsa payload'a ekle
    if (aboutImage != null && aboutImage.isNotEmpty) {
      data['about_image'] = aboutImage;
    }
    return data;
  }
}