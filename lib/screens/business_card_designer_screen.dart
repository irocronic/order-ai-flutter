// lib/screens/business_card_designer_screen.dart

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
  State<BusinessCardDesignerScreen> createState() => _BusinessCardDesignerScreenState();
}

class _BusinessCardDesignerScreenState extends State<BusinessCardDesignerScreen> {
  final FocusNode _focusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { 
          FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
      }
      else if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
        provider.deleteSelectedElements();
      }
      
      final isControlPressed = event.isControlPressed || event.isMetaPressed;
      if (isControlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyC) {
          provider.copySelectedElements();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Seçili elemanlar kopyalandı!"), duration: Duration(seconds: 1)),
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
        title: const Text("Kartvizit Tasarımcısı", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        actions: [
          Consumer<BusinessCardProvider>(
            builder: (context, provider, child) {
              return Row(
                 children: [
                  IconButton(
                    // GÜNCELLEME: İkon rengi beyaz yapıldı.
                    color: Colors.white,
                    icon: const Icon(Icons.undo),
                    tooltip: "Geri Al",
                    onPressed: provider.canUndo ? provider.undo : null,
                  ),
                  IconButton(
                    // GÜNCELLEME: İkon rengi beyaz yapıldı.
                    color: Colors.white,
                    icon: const Icon(Icons.redo),
                    tooltip: "Yinele",
                    onPressed: provider.canRedo ? provider.redo : null,
                  ),
                  IconButton(
                    // GÜNCELLEME: İkon rengi beyaz yapıldı.
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
                    // GÜNCELLEME: İkon rengi beyaz yapıldı.
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
                  // GÜNCELLEME: PDF Dışa Aktar butonu buraya eklendi.
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: "Dışa Aktar (PDF)",
                    onPressed: () {
                      PdfExportService.generateAndShareCard(context, provider.cardModel);
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
              if (constraints.maxWidth > 700) {
                return const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: CanvasWidget(),
                    ),
                    Expanded(
                      flex: 2,
                      child: ControlsPanelWidget(),
                    ),
                  ],
                );
              } else {
                return const Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: CanvasWidget(),
                    ),
                    Expanded(
                      flex: 4,
                      child: ControlsPanelWidget(),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
      // KALDIRILDI: FloatingActionButton buradan kaldırıldı.
    );
  }
}