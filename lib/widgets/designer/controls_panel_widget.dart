// lib/widgets/designer/controls_panel_widget.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/business_card_model.dart';
import '../../providers/business_card_provider.dart';

class _QrCodeDialog extends StatefulWidget {
  const _QrCodeDialog();

  @override
  State<_QrCodeDialog> createState() => _QrCodeDialogState();
}

class _QrCodeDialogState extends State<_QrCodeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addElement() {
    if (_controller.text.isNotEmpty) {
      context.read<BusinessCardProvider>().addQrCodeElement(_controller.text);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("QR Kod Verisi"),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: "https://example.com",
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _addElement(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("İptal"),
        ),
        ElevatedButton(
          onPressed: _addElement,
          child: const Text("Ekle"),
        ),
      ],
    );
  }
}


class ControlsPanelWidget extends StatefulWidget {
  const ControlsPanelWidget({Key? key}) : super(key: key);

  @override
  State<ControlsPanelWidget> createState() => _ControlsPanelWidgetState();
}

class _ControlsPanelWidgetState extends State<ControlsPanelWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BusinessCardProvider _provider;

  void _handleTabChange() {
    final selectedElements = _provider.selectedElements;
    if (!mounted) return;

    if (selectedElements.isEmpty && _tabController.index != 0) {
      _tabController.animateTo(0);
    } else if (selectedElements.isNotEmpty && _tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _provider = context.read<BusinessCardProvider>();
    _provider.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _provider.removeListener(_handleTabChange);
    super.dispose();
  }
  
  void _showQrCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _QrCodeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessCardProvider>();
    final selectedElements = provider.selectedElements;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade800,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.blue.shade800,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_customize),
                    text: "Genel Ayarlar",
                  ),
                  Tab(
                    icon: Icon(Icons.edit),
                    text: "Eleman Ayarları",
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildGeneralControls(context, provider),
                    ),
                  ),
                  selectedElements.isEmpty
                      ? const Center(
                          child: Text(
                            "Düzenlemek için bir eleman seçin",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildElementSpecificControls(
                              context,
                              provider,
                              selectedElements.first,
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

  Widget _buildGeneralControls(
      BuildContext context, BusinessCardProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Genel Ayarlar", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _buildGradientControls(provider),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: provider.addTextElement,
                icon: const Icon(Icons.text_fields),
                label: const Text("Metin"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final file =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (file != null) {
                    final bytes = await file.readAsBytes();
                    provider.addImageElement(bytes);
                  }
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text("Görsel"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _showQrCodeDialog(context),
          icon: const Icon(Icons.qr_code),
          label: const Text("QR Kodu Ekle"),
        ),
        const Divider(height: 32),
        Text("Katmanlar", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _buildLayersPanel(context, provider),
      ],
    );
  }

  Widget _buildGradientControls(BusinessCardProvider provider) {
    final model = provider.cardModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text("Gradyan Kullan"),
          value: model.gradientEndColor != null,
          onChanged: (useGradient) {
            final startColor = model.gradientStartColor;
            if (useGradient) {
              final endColor = startColor == Colors.white
                  ? Colors.blue.shade200
                  : HSLColor.fromColor(startColor)
                      .withLightness(0.8)
                      .toColor();
              provider.updateBackgroundColor(
                  startColor, endColor, GradientType.linear);
            } else {
              provider.updateBackgroundColor(startColor, null, null);
            }
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(model.gradientEndColor == null
              ? "Renk"
              : "Başlangıç Rengi"),
          trailing: CircleAvatar(
              backgroundColor: model.gradientStartColor, radius: 15),
          onTap: () => _showColorPicker(
            context,
            model.gradientStartColor,
            (color) => provider.updateBackgroundColor(
                color, model.gradientEndColor, model.gradientType),
          ),
        ),
        if (model.gradientEndColor != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text("Bitiş Rengi"),
            trailing:
                CircleAvatar(backgroundColor: model.gradientEndColor, radius: 15),
            onTap: () => _showColorPicker(
              context,
              model.gradientEndColor!,
              (color) => provider.updateBackgroundColor(
                  model.gradientStartColor, color, model.gradientType),
            ),
          ),
      ],
    );
  }

  Widget _buildLayersPanel(
      BuildContext context, BusinessCardProvider provider) {
    final elements = provider.cardModel.elements.reversed.toList();
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ReorderableListView.builder(
        primary: false, // <-- DÜZELTME BURADA
        itemCount: elements.length,
        itemBuilder: (context, index) {
          final element = elements[index];
          final isSelected = provider.selectedElementIds.contains(element.id);
          return ListTile(
            key: ValueKey(element.id),
            tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
            leading: Icon(element.type == CardElementType.text
                ? Icons.text_fields
                : element.type == CardElementType.image
                    ? Icons.image
                    : element.type == CardElementType.qrCode
                        ? Icons.qr_code
                        : Icons.star),
            title: Text(
              element.content.isEmpty ? element.type.name : element.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => provider.selectElement(
              element.id,
              addToSelection: provider.isShiftPressed,
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          final reversedOldIndex = elements.length - 1 - oldIndex;
          final reversedNewIndex = elements.length - 1 - newIndex;
          provider.reorderElement(reversedOldIndex, reversedNewIndex);
        },
      ),
    );
  }

  Widget _buildElementSpecificControls(
      BuildContext context, BusinessCardProvider provider, CardElement element) {
    void updateProperty<T>(
        T value, CardElement Function(CardElement, T) updater) {
      provider.updateSelectedElementsProperties((e) => updater(e, value));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Seçili Eleman (${provider.selectedElementIds.length})",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 28),
              tooltip: "Elemanı Sil",
              onPressed: provider.deleteSelectedElements,
            )
          ],
        ),
        const Divider(),
        if (element.type == CardElementType.text) ...[
          TextFormField(
            key: ValueKey(element.id),
            initialValue: element.content,
            decoration: const InputDecoration(
                labelText: "Metin İçeriği", border: OutlineInputBorder()),
            onChanged: (text) =>
                updateProperty(text, (e, v) => e.copyWith(content: v)),
          ),
          const SizedBox(height: 16),
        ],
        if (element.type != CardElementType.qrCode)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text("Eleman Rengi"),
            trailing: CircleAvatar(
                backgroundColor: element.style.color, radius: 15),
            onTap: () => _showColorPicker(
                context, element.style.color!, (color) {
              updateProperty(color,
                  (e, v) => e.copyWith(style: e.style.copyWith(color: v)));
            }),
          ),
        const Text("Opaklık", style: TextStyle(color: Colors.black54)),
        Slider(
          value: element.opacity,
          min: 0.0,
          max: 1.0,
          label: "${(element.opacity * 100).round()}%",
          onChanged: (opacity) {
            updateProperty(opacity, (e, v) => e.copyWith(opacity: v));
          },
        ),
        const Divider(),
        _buildTransformControls(provider, element),
        const Divider(),
        if (element.type == CardElementType.text) ...[
          _buildTextStyleControls(provider, element),
          const Divider(),
          _buildFontFamilySelector(provider, element),
          const Divider(),
        ],
        _buildLayerOrderControls(provider),
      ],
    );
  }

  Widget _buildTransformControls(
      BusinessCardProvider provider, CardElement element) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Boyut & Döndürme",
            style: Theme.of(context).textTheme.titleSmall),
        Row(children: [
          const Text("G: "),
          Expanded(
              child: Slider(
            value: element.size.width,
            min: 10,
            max: 400,
            onChanged: (val) {
              provider.updateSelectedElementsProperties(
                  (e) => e.copyWith(size: Size(val, e.size.height)));
            },
          )),
          Text(element.size.width.round().toString()),
        ]),
        Row(children: [
          const Text("Y: "),
          Expanded(
              child: Slider(
            value: element.size.height,
            min: 10,
            max: 400,
            onChanged: (val) {
              provider.updateSelectedElementsProperties(
                  (e) => e.copyWith(size: Size(e.size.width, val)));
            },
          )),
          Text(element.size.height.round().toString()),
        ]),
        Row(children: [
          const Icon(Icons.rotate_90_degrees_cw),
          Expanded(
              child: Slider(
            value: element.rotation * 180 / math.pi,
            min: -180,
            max: 180,
            onChanged: (val) {
              provider.updateSelectedElementsProperties((e) =>
                  e.copyWith(rotation: val * math.pi / 180));
            },
          )),
          Text("${(element.rotation * 180 / math.pi).round()}°"),
        ]),
      ],
    );
  }

  Widget _buildTextStyleControls(
      BusinessCardProvider provider, CardElement element) {
    final isBold = element.style.fontWeight == FontWeight.bold;
    final isItalic = element.style.fontStyle == FontStyle.italic;
    return Wrap(
      spacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        IconButton(
          tooltip: "Kalın",
          icon: const Icon(Icons.format_bold),
          color: isBold ? Colors.blue : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties((e) =>
              e.copyWith(
                  style: e.style.copyWith(
                      fontWeight:
                          isBold ? FontWeight.normal : FontWeight.bold))),
        ),
        IconButton(
          tooltip: "İtalik",
          icon: const Icon(Icons.format_italic),
          color: isItalic ? Colors.blue : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties((e) =>
              e.copyWith(
                  style: e.style.copyWith(
                      fontStyle:
                          isItalic ? FontStyle.normal : FontStyle.italic))),
        ),
        const VerticalDivider(),
        IconButton(
          tooltip: "Sola Hizala",
          icon: const Icon(Icons.format_align_left),
          color: element.textAlign == TextAlign.left
              ? Colors.blue
              : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties(
              (e) => e.copyWith(textAlign: TextAlign.left)),
        ),
        IconButton(
          tooltip: "Ortala",
          icon: const Icon(Icons.format_align_center),
          color: element.textAlign == TextAlign.center
              ? Colors.blue
              : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties(
              (e) => e.copyWith(textAlign: TextAlign.center)),
        ),
        IconButton(
          tooltip: "Sağa Hizala",
          icon: const Icon(Icons.format_align_right),
          color: element.textAlign == TextAlign.right
              ? Colors.blue
              : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties(
              (e) => e.copyWith(textAlign: TextAlign.right)),
        ),
      ],
    );
  }

  Widget _buildFontFamilySelector(
      BusinessCardProvider provider, CardElement element) {
    const fontFamilies = [
      'Roboto',
      'Lato',
      'Montserrat',
      'Oswald',
      'Merriweather'
    ];
    return DropdownButtonFormField<String>(
      value: fontFamilies.contains(element.style.fontFamily)
          ? element.style.fontFamily
          : 'Roboto',
      decoration: const InputDecoration(
          labelText: "Font Ailesi", border: OutlineInputBorder()),
      items: fontFamilies
          .map((font) => DropdownMenuItem(value: font, child: Text(font)))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          provider.updateSelectedElementsProperties((e) =>
              e.copyWith(style: e.style.copyWith(fontFamily: value)));
        }
      },
    );
  }

  Widget _buildLayerOrderControls(BusinessCardProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton.icon(
          onPressed: () {
            final elements = provider.cardModel.elements;
            final selectedId = provider.selectedElements.first.id;
            final oldIndex = elements.indexWhere((e) => e.id == selectedId);
            if (oldIndex > 0) provider.reorderElement(oldIndex, 0);
          },
          icon: const Icon(Icons.layers_clear),
          label: const Text("Arkaya Gönder"),
        ),
        TextButton.icon(
          onPressed: () {
            final elements = provider.cardModel.elements;
            final selectedId = provider.selectedElements.first.id;
            final oldIndex = elements.indexWhere((e) => e.id == selectedId);
            if (oldIndex < elements.length - 1) {
              provider.reorderElement(oldIndex, elements.length);
            }
          },
          icon: const Icon(Icons.layers),
          label: const Text("Öne Getir"),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context, Color initialColor,
      ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Renk Seçin"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: onColorChanged,
          ),
        ),
        actions: [
          TextButton(
              child: const Text("Tamam"),
              onPressed: () => Navigator.of(context).pop())
        ],
      ),
    );
  }
}