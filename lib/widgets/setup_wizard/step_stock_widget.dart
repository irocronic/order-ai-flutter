// lib/widgets/setup_wizard/step_stock_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/api_service.dart';
import '../../services/setup_wizard_audio_service.dart'; // 🎵 YENİ EKLENEN
import '../../models/menu_item.dart';
import '../../models/menu_item_variant.dart';

class StepStockWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepStockWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
    required this.onSkip,
  }) : super(key: key);

  @override
  _StepStockWidgetState createState() => _StepStockWidgetState();
}

class _StepStockWidgetState extends State<StepStockWidget> {
  bool _isLoadingPageData = true;
  String _errorMessage = '';
  String _successMessage = '';

  List<MenuItem> _menuItemsWithVariants = [];
  Map<int, dynamic> _existingStockMap = {};
  Map<int, TextEditingController> _quantityControllers = {};
  Map<int, bool> _isSavingStockForVariant = {};

  final Map<int, bool> _expanded = {};

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
        _audioService.playStockStepAudio(context: context);
      }
    });
  }

  @override
  void dispose() {
    // Sesli rehberliği durdur
    _audioService.stopAudio();
    _quantityControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPageData = true;
      _errorMessage = '';
      _successMessage = '';
    });
    try {
      final menuItemsData =
          await ApiService.fetchMenuItemsForBusiness(widget.token);
      final stockData = await ApiService.fetchBusinessStock(widget.token);

      if (mounted) {
        _menuItemsWithVariants = menuItemsData
            .map((itemJson) => MenuItem.fromJson(itemJson))
            .where((item) => item.variants != null && item.variants!.isNotEmpty)
            .toList();

        _existingStockMap = {
          for (var stock in stockData)
            if (stock['variant'] is int)
              stock['variant']: stock
            else if (stock['variant'] is Map && stock['variant']['id'] != null)
              stock['variant']['id']: stock
        };

        _quantityControllers.forEach((_, controller) => controller.dispose());
        _quantityControllers = {};
        _isSavingStockForVariant = {};

        for (var item in _menuItemsWithVariants) {
          for (var variant in item.variants!) {
            final currentStock = _existingStockMap[variant.id];
            _quantityControllers[variant.id] = TextEditingController(
              text:
                  currentStock != null ? currentStock['quantity'].toString() : '0',
            );
            _isSavingStockForVariant[variant.id] = false;
          }
        }
        setState(() => _isLoadingPageData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.errorLoadingInitialData(e.toString().replaceFirst("Exception: ", ""));
          _isLoadingPageData = false;
        });
      }
    }
  }

  Future<void> _saveStock(MenuItemVariant variant) async {
    if (!mounted) return;
    final controller = _quantityControllers[variant.id];
    final itemName = menuItemNameForVariant(l10n, variant.menuItem);

    if (controller == null || controller.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.setupStockErrorEnterQuantity(itemName, variant.name));
      _clearMessagesAfterDelay();
      return;
    }
    final quantity = int.tryParse(controller.text.trim());
    if (quantity == null || quantity < 0) {
      setState(() => _errorMessage = l10n.setupStockErrorInvalidQuantity(itemName, variant.name));
      _clearMessagesAfterDelay();
      return;
    }

    setState(() {
      _isSavingStockForVariant[variant.id] = true;
      _successMessage = '';
      _errorMessage = '';
    });

    try {
      final existingStockEntry = _existingStockMap[variant.id];
      await ApiService.createOrUpdateStock(
        widget.token,
        variantId: variant.id,
        quantity: quantity,
        stockId: existingStockEntry?['id'] as int?,
      );
      if (mounted) {
        setState(() {
          _successMessage = l10n.setupStockSuccessUpdated(itemName, variant.name, quantity.toString());
        });
        await _fetchInitialData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.setupStockErrorUpdating(itemName, variant.name, e.toString().replaceFirst("Exception: ", ""));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingStockForVariant[variant.id] = false);
        _clearMessagesAfterDelay();
      }
    }
  }

  void _incrementStock(int variantId) {
    final controller = _quantityControllers[variantId];
    if (controller == null) return;
    int currentValue = int.tryParse(controller.text) ?? 0;
    currentValue++;
    setState(() {
      controller.text = currentValue.toString();
    });
  }

  void _decrementStock(int variantId) {
    final controller = _quantityControllers[variantId];
    if (controller == null) return;
    int currentValue = int.tryParse(controller.text) ?? 0;
    if (currentValue > 0) {
      currentValue--;
      setState(() {
        controller.text = currentValue.toString();
      });
    }
  }

  void _clearMessagesAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && (_successMessage.isNotEmpty || _errorMessage.isNotEmpty)) {
        setState(() {
          _successMessage = '';
          _errorMessage = '';
        });
      }
    });
  }

  String menuItemNameForVariant(AppLocalizations l10n, int menuItemId) {
    final item = _menuItemsWithVariants.firstWhere(
      (mi) => mi.id == menuItemId,
      orElse: () => MenuItem(
          id: 0,
          name: l10n.setupStockUnknownProduct,
          image: '',
          description: ''),
    );
    return item.name;
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
                  _audioService.playStockStepAudio(context: context);
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

  // 🎵 YENİ EKLENEN: Hızlı stok güncelleme kartı
  Widget _buildQuickStockActionsCard() {
    if (_menuItemsWithVariants.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Hızlı Stok İpuçları',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade300, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stok takibi isteğe bağlıdır. Bu adımı atlayabilir, daha sonra ürün bazında ayarlayabilirsiniz.',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange.shade300, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stok bittiğinde müşterilerinize otomatik bildirim gösterilecektir.',
                  style: TextStyle(
                    color: Colors.orange.shade300,
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
    final l10n = AppLocalizations.of(context)!;
    final textStyle = const TextStyle(color: Colors.white);
    
    if (_isLoadingPageData) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_menuItemsWithVariants.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🎵 YENİ EKLENEN: Sesli rehber kontrolleri
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildAudioControlButton(),
              ],
            ),
            const SizedBox(height: 16),
            
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : l10n.setupStockErrorNoVariants,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: _errorMessage.isNotEmpty
                            ? Colors.redAccent
                            : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: widget.onSkip,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Bu Adımı Atla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // 🎵 YENİ EKLENEN: Sesli rehber kontrolleri
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildAudioControlButton(),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.setupStockDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
            ),
          ),
          
          // 🎵 YENİ EKLENEN: Hızlı stok ipuçları kartı
          _buildQuickStockActionsCard(),
          
          if (_successMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _successMessage,
                style: const TextStyle(
                    color: Colors.lightGreenAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _errorMessage,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          RefreshIndicator(
            onRefresh: _fetchInitialData,
            color: Colors.white,
            backgroundColor: Colors.blue.shade700,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _menuItemsWithVariants.length,
              itemBuilder: (context, itemIndex) {
                final menuItem = _menuItemsWithVariants[itemIndex];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 0,
                  color: Colors.white.withOpacity(0.1),
                   shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  child: ExpansionTile(
                    key: ValueKey(menuItem.id),
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white70,
                    initiallyExpanded: _expanded.containsKey(menuItem.id)
                        ? _expanded[menuItem.id]!
                        : (_menuItemsWithVariants.length < 3 || itemIndex < 2),
                    onExpansionChanged: (isOpen) {
                      setState(() => _expanded[menuItem.id] = isOpen);
                    },
                    title: Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            menuItem.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ),
                        // Toplam varyant sayısı badge'i
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${menuItem.variants?.length ?? 0} varyant',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: menuItem.variants?.map<Widget>((variant) {
                          final controller = _quantityControllers[variant.id];
                          final currentStockData = _existingStockMap[variant.id];
                          String lastUpdated = l10n.setupStockNoStockEntered;
                          if (currentStockData != null &&
                              currentStockData['last_updated'] != null) {
                            try {
                              final localDateTime = DateTime.parse(currentStockData['last_updated']).toLocal();
                              final formattedDate = DateFormat(l10n.dateTimeFormat, l10n.localeName).format(localDateTime);
                              lastUpdated = l10n.setupStockLastUpdate(formattedDate);
                            } catch (_) {}
                          }
                          final isCurrentlySaving =
                              _isSavingStockForVariant[variant.id] ?? false;

                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                            child: Column(
                              children: [
                                const Divider(color: Colors.white24),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.label, color: Colors.white.withOpacity(0.6), size: 14),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(variant.name,
                                                    style: textStyle.copyWith(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time, color: Colors.white.withOpacity(0.4), size: 12),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(lastUpdated,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white.withOpacity(0.6))),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline,
                                          color: Colors.red.shade300),
                                      onPressed: isCurrentlySaving
                                          ? null
                                          : () => _decrementStock(variant.id),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: TextFormField(
                                        controller: controller,
                                        style: textStyle,
                                        textAlign: TextAlign.center,
                                        enabled: !isCurrentlySaving,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.black.withOpacity(0.2),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8.0,
                                                  vertical: 10.0),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline,
                                          color: Colors.green.shade300),
                                      onPressed: isCurrentlySaving
                                          ? null
                                          : () => _incrementStock(variant.id),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: isCurrentlySaving
                                          ? null
                                          : () => _saveStock(variant),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 10.0),
                                        minimumSize: const Size(60, 38),
                                      ),
                                      child: isCurrentlySaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : Text(l10n.buttonSave,
                                              style:
                                                  const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList() ??
                        [],
                  ),
                );
              },
            ),
          ),
          
          // 🎵 YENİ EKLENEN: Alt kısım - Atla butonu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: widget.onSkip,
              icon: const Icon(Icons.skip_next),
              label: const Text('Bu Adımı Atla'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}