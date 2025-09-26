import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class SetupWizardAudioService {
  static final SetupWizardAudioService _instance = SetupWizardAudioService._internal();
  static SetupWizardAudioService get instance => _instance;
  SetupWizardAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  String? _currentStep;
  static const Duration _audioCooldown = Duration(seconds: 2);
  DateTime? _lastPlayTime;

  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;
  String? get currentStep => _currentStep;

  /// Desteklenen diller
  static const List<String> _supportedLangs = [
    'tr', 'en', 'de', 'es', 'fr', 'it', 'ar', 'ru', 'zh'
  ];

  /// Geçerli dil kodunu bağlamdan çek
  String _getCurrentLanguageCode(BuildContext? context) {
    try {
      if (context != null) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        final locale = languageProvider.currentLocale;
        if (locale != null && _supportedLangs.contains(locale.languageCode)) {
          return locale.languageCode;
        }
      }
      // Fallback, sistem dili veya tr
      return 'tr';
    } catch (e) {
      debugPrint('[SetupWizardAudioService] Dil kodu alınamadı: $e');
      return 'tr';
    }
  }

  /// Adım sesi çal
  Future<void> playStepAudio(String stepName, {BuildContext? context, Duration? delay}) async {
    if (kIsWeb || _isMuted) {
      debugPrint('[SetupWizardAudioService] Web ya da mute, ses çalınmıyor');
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
      await stopAudio();

      String languageCode = _getCurrentLanguageCode(context);
      String assetPath = 'sounds/setup/$languageCode/$stepName.mp3';

      // Fallback: eğer dosya bulunamazsa İngilizce'ye düş
      // (AssetSource içinde try-catch ile kontrol)
      debugPrint('[SetupWizardAudioService] 🎵 Denenen ses dosyası: $assetPath');

      _currentStep = stepName;
      _isPlaying = true;
      _lastPlayTime = DateTime.now();

      if (delay != null) {
        await Future.delayed(delay);
      } else {
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      try {
        await _audioPlayer.play(AssetSource(assetPath));
      } catch (e) {
        // İngilizce fallback
        if (languageCode != 'en') {
          debugPrint('[SetupWizardAudioService] $assetPath bulunamadı, İngilizce fallback...');
          await _audioPlayer.play(AssetSource('sounds/setup/en/$stepName.mp3'));
        } else {
          rethrow;
        }
      }

      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _currentStep = null;
        debugPrint('[SetupWizardAudioService] ✅ Ses tamamlandı: $stepName');
      });

      _playbackTimer?.cancel();
      _playbackTimer = Timer(const Duration(seconds: 30), () {
        if (_isPlaying) {
          debugPrint('[SetupWizardAudioService] ⏰ Timeout, ses durduruldu');
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

  Future<void> playTablesStepAudio({BuildContext? context}) async {
    await playStepAudio('step_tables', context: context);
  }
  Future<void> playCategoriesStepAudio({BuildContext? context}) async {
    await playStepAudio('step_categories', context: context);
  }
  Future<void> playMenuItemsStepAudio({BuildContext? context}) async {
    await playStepAudio('step_menu_items', context: context);
  }
  Future<void> playVariantsStepAudio({BuildContext? context}) async {
    await playStepAudio('step_variants', context: context);
  }
  Future<void> playStockStepAudio({BuildContext? context}) async {
    await playStepAudio('step_stock', context: context);
  }
  Future<void> playStaffStepAudio({BuildContext? context}) async {
    await playStepAudio('step_staff', context: context);
  }
  Future<void> playKdsStepAudio({BuildContext? context}) async {
    await playStepAudio('step_kds', context: context);
  }
  Future<void> playLocalizationStepAudio({BuildContext? context}) async {
    await playStepAudio('step_localization', context: context);
  }
  Future<void> playWelcomeStepAudio({BuildContext? context}) async {
    await playStepAudio('step_welcome', context: context);
  }
}