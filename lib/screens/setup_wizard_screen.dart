// lib/screens/setup_wizard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/api_service.dart';
import 'business_owner_home.dart';
import '../widgets/setup_wizard/step_localization_settings_widget.dart';
import '../widgets/setup_wizard/step_tables_widget.dart';
import '../widgets/setup_wizard/step_kds_widget.dart';
import '../widgets/setup_wizard/step_staff_widget.dart';
import '../widgets/setup_wizard/categories/step_categories_widget.dart';
import '../widgets/setup_wizard/menu_items/step_menu_items_widget.dart';

// Key'ler güncellendi
final GlobalKey<StepTablesWidgetState> _tablesStepKey = GlobalKey();
final GlobalKey<StepKdsWidgetState> _kdsStepKey = GlobalKey();
final GlobalKey<StepStaffWidgetState> _staffStepKey = GlobalKey();
final GlobalKey<StepCategoriesWidgetState> _categoriesStepKey = GlobalKey();
final GlobalKey<StepMenuItemsWidgetState> _menuItemsStepKey = GlobalKey();

class SetupWizardScreen extends StatefulWidget {
  final String token;
  final int businessId;

  const SetupWizardScreen({
    Key? key,
    required this.token,
    required this.businessId,
  }) : super(key: key);

  @override
  _SetupWizardScreenState createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmittingFinal = false;

  late List<Widget> _wizardPages;

  // --- Animasyon değişkenleri ---
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _wizardPages = [
      StepLocalizationSettingsWidget(
          key: const PageStorageKey("localization"),
          token: widget.token,
          businessId: widget.businessId,
          onNext: () => _handleNext()),
      StepTablesWidget(
          key: _tablesStepKey,
          token: widget.token,
          businessId: widget.businessId,
          onNext: () {}),
      StepKdsWidget(
          key: _kdsStepKey,
          token: widget.token,
          businessId: widget.businessId,
          onNext: () {}),
      StepStaffWidget(
          key: _staffStepKey,
          token: widget.token,
          businessId: widget.businessId,
          onNext: () => _handleNext()),
      StepCategoriesWidget(
          key: _categoriesStepKey,
          token: widget.token,
          businessId: widget.businessId,
          onNext: () {}),
      StepMenuItemsWidget(
          key: _menuItemsStepKey,
          token: widget.token,
          businessId: widget.businessId,
          onNext: () {}),
    ];

    // --- Animasyon ayarları ---
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleNext({bool isOptional = false}) {
    if (isOptional) {
      _moveToNextPage();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    bool canProceed = true;

    switch (_currentPage) {
      case 1: // Masa
        if (_tablesStepKey.currentState?.createdTableCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.setupTablesErrorNoTablesCreated),
            backgroundColor: Colors.orangeAccent,
          ));
          canProceed = false;
        }
        break;
      case 2: // KDS
        if (_kdsStepKey.currentState?.createdKdsScreens.isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.setupKdsErrorNoScreensCreated),
            backgroundColor: Colors.orangeAccent,
          ));
          canProceed = false;
        }
        break;
      case 3:
        final staffState = _staffStepKey.currentState;
        if (staffState != null &&
            staffState.createdStaffCount > 0 &&
            !staffState.areAllStaffShiftsAssigned()) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.setupStaffErrorAssignShift),
            backgroundColor: Colors.orangeAccent,
          ));
          canProceed = false;
        }
        break;
      case 4: // Kategoriler
        if (_categoriesStepKey.currentState?.categories.isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.setupCategoriesErrorNoCategoriesCreated),
            backgroundColor: Colors.orangeAccent,
          ));
          canProceed = false;
        }
        break;
      case 5: // Menü Ürünleri - Son adım
        if (_menuItemsStepKey.currentState?.addedMenuItems.isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.setupMenuItemsErrorNoItemsCreated),
            backgroundColor: Colors.orangeAccent,
          ));
          canProceed = false;
        }
        break;
    }

    if (canProceed) {
      _moveToNextPage();
    }
  }

  void _moveToNextPage() {
    if (_currentPage < _wizardPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSetup();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipPage() {
    if (_currentPage == _wizardPages.length - 1) {
      _finishSetup();
    } else {
      _moveToNextPage();
    }
  }

  Future<void> _finishSetup() async {
    if (!mounted) return;
    setState(() => _isSubmittingFinal = true);
    try {
      await ApiService.markSetupComplete(widget.token, widget.businessId);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.setupWizardSuccessMessage),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessOwnerHome(
              token: widget.token,
              businessId: widget.businessId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.setupWizardErrorMessage(
                e.toString().replaceFirst("Exception: ", ""),
              ),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSubmittingFinal = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final List<String> pageTitles = [
      l10n.setupWizardStepLocalizationTitle,
      l10n.setupWizardStep1Title, // Masalar
      l10n.setupWizardStep2Title, // KDS
      l10n.setupWizardStepStaffTitle,
      l10n.setupWizardStep3Title, // Kategoriler
      l10n.setupWizardStep4Title, // Ürünler
    ];

    bool isLastStep = _currentPage == _wizardPages.length - 1;
    bool currentStepIsOptional = _currentPage == 3;

    return Scaffold(
      // 🎨 DÜZELTİLDİ: AppBar backgroundColor ve elevation kaldırıldı
      appBar: AppBar(
        title: Text(
          l10n.setupWizardTitle(
            (_currentPage + 1).toString(),
            _wizardPages.length.toString(),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent, // 🎨 EKLENDI: Şeffaf arka plan
        elevation: 0, // 🎨 EKLENDI: Gölge kaldırıldı
        flexibleSpace: Container( // 🎨 DÜZELTİLDİ: DecoratedBox yerine Container
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF512DA8), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF42A5F5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // 🎨 DÜZELTİLDİ: Step title container'ı gradient background ile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1976D2).withOpacity(0.9), // 🎨 EKLENDI: Mavi gradient
                    const Color(0xFF0D47A1).withOpacity(0.8), // 🎨 EKLENDI: Koyu mavi
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                // 🎨 EKLENDI: Alt köşeleri yuvarlatma
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                // 🎨 EKLENDI: Hafif gölge efekti
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                pageTitles[_currentPage],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  // 🎨 EKLENDI: Text shadow
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // 🎨 DÜZELTİLDİ: Progress bar styling
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // 🎨 EKLENDI: Margin
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8), // 🎨 EKLENDI: Rounded corners
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8), // 🎨 EKLENDI: Clip rounded corners
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _wizardPages.length,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8, // 🎨 DÜZELTİLDİ: Biraz daha kalın
                ),
              ),
            ),
            
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                        _animationController.forward(from: 0);
                      });
                    },
                    physics: const NeverScrollableScrollPhysics(),
                    children: _wizardPages,
                  ),
                ),
              ),
            ),
            
            // 🎨 DÜZELTİLDİ: Footer styling
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                // 🎨 EKLENDI: Footer gradient
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D47A1).withOpacity(0.8),
                    const Color(0xFF1976D2).withOpacity(0.9),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.0,
                  ),
                ),
                // 🎨 EKLENDI: Üst köşeleri yuvarlatma
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      label: Text(
                        l10n.setupWizardBackButton,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _isSubmittingFinal ? null : _previousPage,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    )
                  else
                    Opacity(
                      opacity: 0,
                      child: TextButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.arrow_back_ios_new),
                        label: const Text(""),
                      ),
                    ),
                  if (currentStepIsOptional)
                    Flexible(
                      child: TextButton(
                        onPressed: _isSubmittingFinal ? null : _skipPage,
                        child: Text(
                          l10n.setupWizardSkipButton,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: _isSubmittingFinal
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isLastStep
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward_ios,
                            size: 18,
                          ),
                    label: Text(
                      isLastStep
                          ? l10n.setupWizardFinishButton
                          : l10n.setupWizardNextButton,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _isSubmittingFinal
                        ? null
                        : () => _handleNext(
                              isOptional:
                                  currentStepIsOptional && _currentPage != 3,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}