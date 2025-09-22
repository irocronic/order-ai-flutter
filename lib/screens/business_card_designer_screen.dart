// lib/screens/business_card_designer_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/business_card_provider.dart';
import '../services/pdf_export_service.dart';
import '../widgets/designer/canvas_widget.dart';
import '../widgets/designer/controls_panel_widget.dart';

class BusinessCardDesignerScreen extends StatefulWidget {
  const BusinessCardDesignerScreen({Key? key}) : super(key: key);
  @override
  State<BusinessCardDesignerScreen> createState() =>
      _BusinessCardDesignerScreenState();
}

class _BusinessCardDesignerScreenState
    extends State<BusinessCardDesignerScreen> with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();
  final TransformationController _controller = TransformationController();
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != currentOrientation) {
      _controller.value = Matrix4.identity(); // reset zoom & pan
      _lastOrientation = currentOrientation;
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    final provider = context.read<BusinessCardProvider>();
    provider.setShiftPressedStatus(event.isShiftPressed);
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        provider.moveSelectedElements(const Offset(0, -1));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        provider.moveSelectedElements(const Offset(0, 1));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        provider.moveSelectedElements(const Offset(-1, 0));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        provider.moveSelectedElements(const Offset(1, 0));
      } else if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        provider.deleteSelectedElements();
      }

      final isControlPressed = event.isControlPressed || event.isMetaPressed;
      if (isControlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyC) {
          provider.copySelectedElements();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Seçili elemanlar kopyalandı!"),
              duration: Duration(seconds: 1),
            ),
          );
        } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
          provider.pasteElements();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kartvizit Tasarımcısı",
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        actions: [
          Consumer<BusinessCardProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.undo),
                    tooltip: "Geri Al",
                    onPressed: provider.canUndo ? provider.undo : null,
                  ),
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.redo),
                    tooltip: "Yinele",
                    onPressed: provider.canRedo ? provider.redo : null,
                  ),
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.save),
                    tooltip: "Kaydet",
                    onPressed: () async {
                      await provider.saveCard();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Tasarım kaydedildi!")),
                      );
                    },
                  ),
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.folder_open),
                    tooltip: "Yükle",
                    onPressed: () async {
                      await provider.loadCard();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Tasarım yüklendi!")),
                      );
                    },
                  ),
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: "Dışa Aktar (PDF)",
                    onPressed: () {
                      PdfExportService.generateAndShareCard(
                          context, provider.cardModel);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKeyEvent,
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.9),
                  Colors.blue.shade400.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final provider = context.watch<BusinessCardProvider>();

                if (constraints.maxWidth > 700) {
                  // Yatay mod: mevcut davranışı koruyoruz
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: InteractiveViewer(
                            transformationController: _controller,
                            alignment: Alignment.center,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: const CanvasWidget(),
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: ControlsPanelWidget(),
                      ),
                    ],
                  );
                } else {
                  // Dikey mod — kalan alana göre kesin bir boyut hesaplayıp
                  // Canvas'ı o boyuta sarmalıyoruz.
                  final controlsHeight =
                      math.min(constraints.maxHeight * 0.4, 320.0);

                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight - controlsHeight;

                  // provider.cardModel.dimensions: kartın gerçek genişlik/yükseklikleri
                  final cardWidth = provider.cardModel.dimensions.width;
                  final cardHeight = provider.cardModel.dimensions.height;
                  final cardAspect = cardWidth / cardHeight;

                  // Hedef genişlik ve yükseklik; alana sığacak şekilde hesapla
                  double targetWidth = availableWidth;
                  double targetHeight = targetWidth / cardAspect;

                  if (targetHeight > availableHeight) {
                    targetHeight = availableHeight;
                    targetWidth = targetHeight * cardAspect;
                  }

                  // Eğer availableHeight veya availableWidth NaN/0 ise fallback uygulaması
                  if (availableWidth.isInfinite ||
                      availableHeight.isInfinite ||
                      availableWidth <= 0 ||
                      availableHeight <= 0) {
                    // Bu durumda önceki basit düzeni kullan
                    return Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: controlsHeight,
                          child: Center(
                            child: InteractiveViewer(
                              transformationController: _controller,
                              alignment: Alignment.center,
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: const CanvasWidget(),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: controlsHeight,
                            child: const ControlsPanelWidget(),
                          ),
                        ),
                      ],
                    );
                  }

                  return Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: controlsHeight,
                        child: Center(
                          child: SizedBox(
                            width: targetWidth,
                            height: targetHeight,
                            child: InteractiveViewer(
                              transformationController: _controller,
                              alignment: Alignment.center,
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: const CanvasWidget(),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: controlsHeight,
                          child: const ControlsPanelWidget(),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
