// lib/widgets/home/user_profile_avatar.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Eklendi
import '../../services/user_session.dart';

/// AppBar'da kullanıcı profil resmini ve çıkış yap menüsünü gösteren widget.
class UserProfileAvatar extends StatelessWidget {
  final VoidCallback onLogout;

  const UserProfileAvatar({
    Key? key,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // AppLocalizations nesnesini build context'i üzerinden alıyoruz.
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'logout') {
          onLogout();
        }
      },
      color: Colors.white, // Menü arkaplanı
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.exit_to_app, color: Colors.redAccent),
              const SizedBox(width: 8),
              // "Çıkış Yap" metni dil dosyasından alınıyor.
              Text(l10n.logout), // Değiştirildi
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.5),
          backgroundImage: (UserSession.profileImageUrl != null && UserSession.profileImageUrl!.isNotEmpty)
              ? NetworkImage(UserSession.profileImageUrl!)
              : null,
          child: (UserSession.profileImageUrl == null || UserSession.profileImageUrl!.isEmpty)
              ? Icon(Icons.person, color: Colors.blue.shade900)
              : null,
        ),
      ),
    );
  }
}