// lib/widgets/setup_wizard/categories/step_categories_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../models/kds_screen_model.dart';
import '../../../services/user_session.dart';
import '../../../services/setup_wizard_audio_service.dart'; // 🎵 YENİ EKLENEN
import 'components/quick_start_section.dart';
import 'components/manual_form_section.dart';
import 'components/categories_list_section.dart';
import 'services/category_service.dart';

class StepCategoriesWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepCategoriesWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepCategoriesWidgetState createState() => StepCategoriesWidgetState();
}

class StepCategoriesWidgetState extends State<StepCategoriesWidget> {
  final CategoryService _categoryService = CategoryService();
  
  List<dynamic> categories = [];
  List<KdsScreenModel> _availableKdsScreens = [];
  bool _isLoadingScreenData = true;
  String _message = '';
  String _successMessage = '';

  late final AppLocalizations l10n;
  bool _didFetchData = false;

  // 🎵 YENİ EKLENEN: Audio servis referansı
  final SetupWizardAudioService _audioService = SetupWizardAudioService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchInitialData();
      _didFetchData = true;
      
      // 🎵 YENİ EKLENEN: Sesli rehberliği başlat
      _startVoiceGuidance();
    }
  }

  // 🎵 YENİ EKLENEN: Sesli rehberlik başlatma
  void _startVoiceGuidance() {
    // Biraz bekle ki kullanıcı ekranı görsün
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _audioService.playCategoriesStepAudio(context: context);
      }
    });
  }

  @override
  void dispose() {
    // Sesli rehberliği durdur
    _audioService.stopAudio();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingScreenData = true;
      _message = '';
      _successMessage = '';
    });

    try {
      final data = await _categoryService.fetchInitialData(widget.token, widget.businessId);
      if (mounted) {
        setState(() {
          categories = data['categories'];
          _availableKdsScreens = data['kdsScreens'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = l10n.errorLoadingInitialData(e.toString().replaceFirst("Exception: ", ""));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingScreenData = false);
    }
  }

  void _onCategoryAdded() {
    _fetchInitialData();
  }

  void _onCategoryDeleted() {
    _fetchInitialData();
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      if (isError) {
        _message = message;
        _successMessage = '';
      } else {
        _successMessage = message;
        _message = '';
      }
    });
    
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _message = '';
          _successMessage = '';
        });
      }
    });
  }

  // 🎵 YENİ EKLENEN: Ses kontrol butonu
  Widget _buildAudioControlButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: ValueNotifier(_audioService.isMuted),
      builder: (context, isMuted, child) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ses durumu göstergesi
              if (_audioService.isPlaying)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Sesli Rehber Aktif',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Sessizlik/Açma butonu
              IconButton(
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white.withOpacity(0.9),
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _audioService.toggleMute();
                  });
                },
                tooltip: isMuted ? 'Sesi Aç' : 'Sesi Kapat',
                style: IconButton.styleFrom(
                  backgroundColor: isMuted 
                    ? Colors.red.withOpacity(0.2) 
                    : Colors.blue.withOpacity(0.2),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              
              // Tekrar çal butonu
              IconButton(
                icon: Icon(
                  Icons.replay,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                onPressed: _audioService.isMuted ? null : () {
                  _audioService.playCategoriesStepAudio(context: context);
                },
                tooltip: 'Rehberi Tekrar Çal',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🎵 YENİ EKLENEN: Kategori bilgi kartı
  Widget _buildCategoryInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                'Kategoriler Hakkında',
                style: TextStyle(
                  color: Colors.teal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flash_on, color: Colors.teal.shade300, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hızlı başlangıç ile popüler kategorileri tek tıkla ekleyebilirsiniz.',
                  style: TextStyle(
                    color: Colors.teal.shade300,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.palette, color: Colors.teal.shade300, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Her kategori için özel renk ve ikon seçebilirsiniz.',
                  style: TextStyle(
                    color: Colors.teal.shade300,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tv, color: Colors.teal.shade300, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kategorileri KDS ekranlarında gösterilecek şekilde ayarlayabilirsiniz.',
                  style: TextStyle(
                    color: Colors.teal.shade300,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.white);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🎵 YENİ EKLENEN: Sesli rehber kontrolleri
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildAudioControlButton(),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            l10n.setupCategoriesDescription,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          const SizedBox(height: 24),
          
          // 🎵 YENİ EKLENEN: Kategori bilgi kartı
          _buildCategoryInfoCard(),
          
          // Hızlı Başlangıç Bölümü
          QuickStartSection(
            token: widget.token,
            businessId: widget.businessId,
            currentCategoryCount: categories.length,
            onCategoriesAdded: _onCategoryAdded,
            onMessageChanged: _showMessage,
          ),
          
          // Manuel Form Bölümü
          ManualFormSection(
            token: widget.token,
            businessId: widget.businessId,
            categories: categories,
            availableKdsScreens: _availableKdsScreens,
            isLoadingScreenData: _isLoadingScreenData,
            onCategoryAdded: _onCategoryAdded,
            onMessageChanged: _showMessage,
          ),
          
          const SizedBox(height: 24),
          
          // Mevcut Kategoriler Listesi
          CategoriesListSection(
            token: widget.token,
            categories: categories,
            availableKdsScreens: _availableKdsScreens,
            isLoading: _isLoadingScreenData,
            onCategoryDeleted: _onCategoryDeleted,
            onMessageChanged: _showMessage,
          ),
          
          const SizedBox(height: 10),
          
          // Başarı/Hata Mesajları
          if (_successMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Text(
                _successMessage,
                style: const TextStyle(
                  color: Colors.lightGreenAccent,
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          if (_message.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _message,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Limit Göstergesi
          if (!_isLoadingScreenData)
            ValueListenableBuilder<SubscriptionLimits>(
              valueListenable: UserSession.limitsNotifier,
              builder: (context, limits, child) {
                return Text(
                  '${categories.length} / ${limits.maxCategories} Kategori Oluşturuldu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.8)
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}