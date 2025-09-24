// lib/widgets/setup_wizard/menu_items/step_menu_items_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../models/menu_item.dart';
import '../../../services/user_session.dart';
import '../../../services/setup_wizard_audio_service.dart';
import 'components/quick_start_section.dart';
import 'components/manual_form_section.dart';
import 'components/menu_items_list_section.dart';
import 'services/menu_item_service.dart';

class StepMenuItemsWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepMenuItemsWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepMenuItemsWidgetState createState() => StepMenuItemsWidgetState();
}

class StepMenuItemsWidgetState extends State<StepMenuItemsWidget> {
  final MenuItemService _menuItemService = MenuItemService();
  
  List<dynamic> _availableCategories = [];
  List<dynamic> addedMenuItems = [];
  bool _isLoadingScreenData = true;
  String _message = '';
  String _successMessage = '';

  late final AppLocalizations l10n;
  bool _didFetchData = false;

  final SetupWizardAudioService _audioService = SetupWizardAudioService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchInitialData();
      _didFetchData = true;
      
      _startVoiceGuidance();
    }
  }

  void _startVoiceGuidance() {
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _audioService.playMenuItemsStepAudio(context: context);
      }
    });
  }

  @override
  void dispose() {
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
      final data = await _menuItemService.fetchInitialData(widget.token);
      if (mounted) {
        setState(() {
          _availableCategories = data['categories'];
          addedMenuItems = data['menuItems'];
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

  void _onMenuItemAdded() {
    _fetchInitialData();
  }

  void _onMenuItemDeleted() {
    _fetchInitialData();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    
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

  Widget _buildAudioControlButton() {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: ValueNotifier(_audioService.isMuted),
      builder: (context, isMuted, child) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        l10n.audioGuideActive,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
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
                tooltip: isMuted ? l10n.audioGuideTooltipUnmute : l10n.audioGuideTooltipMute,
                style: IconButton.styleFrom(
                  backgroundColor: isMuted 
                    ? Colors.red.withOpacity(0.2) 
                    : Colors.blue.withOpacity(0.2),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              
              IconButton(
                icon: Icon(
                  Icons.replay,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                onPressed: _audioService.isMuted ? null : () {
                  _audioService.playMenuItemsStepAudio(context: context);
                },
                tooltip: l10n.audioGuideTooltipReplay,
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildAudioControlButton(),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            l10n.setupMenuItemsDescription,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          const SizedBox(height: 24),
          
          QuickStartSection(
              token: widget.token,
              availableCategories: _availableCategories,
              currentMenuItemCount: addedMenuItems.length,
              onMenuItemsAdded: _onMenuItemAdded,
              onMessageChanged: _showMessage,
              businessId: widget.businessId,
          ),
          
          ManualFormSection(
            token: widget.token,
            businessId: widget.businessId,
            availableCategories: _availableCategories,
            isLoadingScreenData: _isLoadingScreenData,
            onMenuItemAdded: _onMenuItemAdded,
            onMessageChanged: _showMessage,
          ),
          
          const SizedBox(height: 24),
          
          MenuItemsListSection(
            token: widget.token,
            menuItems: addedMenuItems,
            availableCategories: _availableCategories,
            isLoading: _isLoadingScreenData,
            onMenuItemDeleted: _onMenuItemDeleted,
            onMessageChanged: _showMessage,
            businessId: widget.businessId,
          ),
          
          const SizedBox(height: 10),
          
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
          
          if (!_isLoadingScreenData)
            ValueListenableBuilder<SubscriptionLimits>(
              valueListenable: UserSession.limitsNotifier,
              builder: (context, limits, child) {
                return Text(
                  l10n.setupMenuItemsTotalCreatedWithLimit(
                    addedMenuItems.length.toString(), 
                    limits.maxMenuItems.toString()
                  ),
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