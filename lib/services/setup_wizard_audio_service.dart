// lib/services/setup_wizard_audio_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/user_session.dart';

class SetupWizardAudioService {
  static final SetupWizardAudioService _instance = SetupWizardAudioService._internal();
  static SetupWizardAudioService get instance => _instance;
  SetupWizardAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  String? _currentStep;
  
  // Ses dosyası cooldown kontrolü
  static const Duration _audioCooldown = Duration(seconds: 2);
  DateTime? _lastPlayTime;

  /// Ses seviyesi kontrolü
  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;
  String? get currentStep => _currentStep;

  /// Dil kodunu al (varsayılan Türkçe)
  String _getCurrentLanguageCode(BuildContext? context) {
    try {
      if (context != null) {
        // Provider'dan dil kodunu al
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        final locale = languageProvider.currentLocale;
        if (locale != null) {
          return locale.languageCode == 'en' ? 'en' : 'tr';
        }
      }
      
      // 🔧 DÜZELTME: UserSession'dan doğru şekilde kontrol et
      try {
        // Eğer UserSession'da locale bilgisi varsa (varsa kullan)
        // Aksi takdirde varsayılan Türkçe döndür
        return 'tr'; // Geçici olarak varsayılan
      } catch (e) {
        debugPrint('[SetupWizardAudioService] UserSession kontrol hatası: $e');
      }
      
      // Varsayılan Türkçe
      return 'tr';
    } catch (e) {
      debugPrint('[SetupWizardAudioService] Dil kodu alınamadı: $e');
      return 'tr'; // Fallback
    }
  }

  /// Adım sesini çal
  Future<void> playStepAudio(String stepName, {BuildContext? context, Duration? delay}) async {
    if (kIsWeb || _isMuted) {
      debugPrint('[SetupWizardAudioService] Web platformu veya sessize alınmış, ses çalınmıyor');
      return;
    }

    // Cooldown kontrolü
    if (_lastPlayTime != null) {
      final timeSinceLastPlay = DateTime.now().difference(_lastPlayTime!);
      if (timeSinceLastPlay < _audioCooldown) {
        debugPrint('[SetupWizardAudioService] Cooldown aktif, ses atlandı');
        return;
      }
    }

    try {
      // Önceki ses varsa durdur
      await stopAudio();

      final languageCode = _getCurrentLanguageCode(context);
      // 🔧 DÜZELTME: Doğru asset yolu - assets/ prefix'i eklendi
      final audioPath = 'assets/sounds/setup/$languageCode/$stepName.mp3';
      
      debugPrint('[SetupWizardAudioService] 🎵 Adım sesi çalınıyor: $audioPath');
      
      _currentStep = stepName;
      _isPlaying = true;
      _lastPlayTime = DateTime.now();

      // Belirtilen süre kadar bekle (varsayılan 1.5 saniye)
      if (delay != null) {
        await Future.delayed(delay);
      } else {
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // 🔧 DÜZELTME: AssetSource için doğru yol - assets/ olmadan
      await _audioPlayer.play(AssetSource('sounds/setup/$languageCode/$stepName.mp3'));
      
      // Ses bittiğinde durumu güncelle
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _currentStep = null;
        debugPrint('[SetupWizardAudioService] ✅ Ses tamamlandı: $stepName');
      });

      // 30 saniye timeout (uzun sesler için)
      _playbackTimer?.cancel();
      _playbackTimer = Timer(const Duration(seconds: 30), () {
        if (_isPlaying) {
          debugPrint('[SetupWizardAudioService] ⏰ Ses timeout, durduruldu');
          stopAudio();
        }
      });

    } catch (e) {
      debugPrint('[SetupWizardAudioService] ❌ Ses çalma hatası: $e');
      _isPlaying = false;
      _currentStep = null;
    }
  }

  /// Sesi durdur
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentStep = null;
      _playbackTimer?.cancel();
      debugPrint('[SetupWizardAudioService] 🛑 Ses durduruldu');
    } catch (e) {
      debugPrint('[SetupWizardAudioService] Ses durdurma hatası: $e');
    }
  }

  /// Sessizlik modunu aç/kapat
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted && _isPlaying) {
      stopAudio();
    }
    debugPrint('[SetupWizardAudioService] 🔊 Sessize alma: $_isMuted');
  }

  /// Sessizlik modunu ayarla
  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted && _isPlaying) {
      stopAudio();
    }
    debugPrint('[SetupWizardAudioService] 🔊 Sessizlik durumu: $_isMuted');
  }

  /// Tekrar çal (aynı adımı)
  Future<void> replayCurrentStep({BuildContext? context}) async {
    if (_currentStep != null) {
      await playStepAudio(_currentStep!, context: context);
    }
  }

  /// Kaynakları temizle
  void dispose() {
    _playbackTimer?.cancel();
    _audioPlayer.dispose();
    debugPrint('[SetupWizardAudioService] 🧹 Kaynaklar temizlendi');
  }

  // === Setup Wizard Adımları için Özel Metodlar ===

  /// Masa Kurulumu adımı
  Future<void> playTablesStepAudio({BuildContext? context}) async {
    await playStepAudio('step_tables', context: context);
  }

  /// Kategori Kurulumu adımı
  Future<void> playCategoriesStepAudio({BuildContext? context}) async {
    await playStepAudio('step_categories', context: context);
  }

  /// Menü Öğeleri adımı
  Future<void> playMenuItemsStepAudio({BuildContext? context}) async {
    await playStepAudio('step_menu_items', context: context);
  }

  /// Varyantlar adımı
  Future<void> playVariantsStepAudio({BuildContext? context}) async {
    await playStepAudio('step_variants', context: context);
  }

  /// Stok adımı
  Future<void> playStockStepAudio({BuildContext? context}) async {
    await playStepAudio('step_stock', context: context);
  }

  /// Personel adımı
  Future<void> playStaffStepAudio({BuildContext? context}) async {
    await playStepAudio('step_staff', context: context);
  }

  /// KDS adımı
  Future<void> playKdsStepAudio({BuildContext? context}) async {
    await playStepAudio('step_kds', context: context);
  }

  /// Yerelleştirme adımı
  Future<void> playLocalizationStepAudio({BuildContext? context}) async {
    await playStepAudio('step_localization', context: context);
  }

  /// Hoş geldiniz/Başlangıç adımı
  Future<void> playWelcomeStepAudio({BuildContext? context}) async {
    await playStepAudio('step_welcome', context: context);
  }
}