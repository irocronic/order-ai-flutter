// lib/widgets/designer/controls_panel_widget.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/business_card_model.dart';
import '../../models/shape_style.dart';
import '../../providers/business_card_provider.dart';
import 'icon_gallery_dialog.dart';
import 'template_gallery_dialog.dart';

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
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.qrCodeData),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.qrCodeHint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _addElement(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _addElement,
          child: Text(l10n.add),
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

    const int elementSettingsTabIndex = 4;

    if (selectedElements.isEmpty &&
        _tabController.index == elementSettingsTabIndex) {
      _tabController.animateTo(0);
    } else if (selectedElements.isNotEmpty &&
        _tabController.index != elementSettingsTabIndex) {
      _tabController.animateTo(elementSettingsTabIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  void _showTemplateGallery(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const TemplateGalleryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessCardProvider>();
    final selectedElements = provider.selectedElements;
    final l10n = AppLocalizations.of(context)!;
    
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade800,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.blue.shade800,
                isScrollable: true,
                tabs: [
                  Tab(icon: const Icon(Icons.palette_outlined), text: l10n.generalSettings),
                  Tab(icon: const Icon(Icons.add_box_outlined), text: l10n.addElement),
                  Tab(icon: const Icon(Icons.collections_outlined), text: l10n.templates),
                  Tab(icon: const Icon(Icons.layers_outlined), text: l10n.layers),
                  Tab(icon: const Icon(Icons.edit_outlined), text: l10n.element),
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
                      child: _buildBackgroundControls(context, provider),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildAddElementControls(context, provider),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildTemplateControls(context, provider),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildLayersControls(context, provider),
                  ),
                  selectedElements.isEmpty
                      ? Center(
                          child: Text(
                            l10n.selectElementToEdit,
                            style: const TextStyle(
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

  Widget _buildBackgroundControls(
      BuildContext context, BusinessCardProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.backgroundSettings, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _buildGradientControls(provider),
      ],
    );
  }

  Widget _buildAddElementControls(
      BuildContext context, BusinessCardProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.addElement, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                // GÜNCELLEME: Lokalizasyon metni parametre olarak geçiliyor
                onPressed: () => provider.addTextElement(localizedText: l10n.newText),
                icon: const Icon(Icons.text_fields),
                label: Text(l10n.text),
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
                label: Text(l10n.image),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showQrCodeDialog(context),
                icon: const Icon(Icons.qr_code),
                label: Text(l10n.qrCode),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PopupMenuButton<ShapeType>(
                onSelected: provider.addShapeElement,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ShapeType.rectangle,
                    child: Text(l10n.rectangle),
                  ),
                  PopupMenuItem(
                    value: ShapeType.ellipse,
                    child: Text(l10n.ellipse),
                  ),
                  PopupMenuItem(
                    value: ShapeType.line,
                    child: Text(l10n.line),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.format_shapes, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(l10n.shape, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: provider.addSvgElement,
          icon: const Icon(Icons.star_outline),
          label: Text(l10n.addSvgObject),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade400,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const IconGalleryDialog(),
            );
          },
          icon: const Icon(FontAwesomeIcons.icons),
          label: Text(l10n.addReadyIcon),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateControls(
      BuildContext context, BusinessCardProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.templates, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showTemplateGallery(context),
                icon: const Icon(Icons.collections),
                label: Text(l10n.templateGallery),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  provider.saveCardAsTemplate(l10n.newTemplate);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.designSavedAsTemplate)));
                },
                icon: const Icon(Icons.save_as),
                label: Text(l10n.saveAs),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayersControls(
      BuildContext context, BusinessCardProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.layers, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Expanded(
          child: _buildLayersPanel(context, provider),
        ),
      ],
    );
  }

  Widget _buildGradientControls(BusinessCardProvider provider) {
    final model = provider.cardModel;
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(l10n.useGradient),
          value: model.gradientEndColor != null && model.gradientType != null,
          onChanged: (useGradient) {
            final currentStartColor = model.gradientStartColor;

            if (useGradient) {
              final endColor = currentStartColor == Colors.white
                  ? Colors.blue.shade200
                  : HSLColor.fromColor(currentStartColor)
                      .withLightness(0.8)
                      .toColor();
              provider.updateBackgroundColor(
                  currentStartColor, endColor, GradientType.linear);
            } else {
              provider.updateBackgroundColor(currentStartColor, null, null, true);
            }
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(model.gradientEndColor == null
              ? l10n.color
              : l10n.startColor),
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
            title: Text(l10n.endColor),
            trailing: CircleAvatar(
                backgroundColor: model.gradientEndColor, radius: 15),
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
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ReorderableListView.builder(
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
                        : element.type == CardElementType.shape
                            ? Icons.format_shapes
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
    final l10n = AppLocalizations.of(context)!;
    
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
              l10n.selectedElement(provider.selectedElementIds.length),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 28),
              tooltip: l10n.deleteElement,
              onPressed: provider.deleteSelectedElements,
            )
          ],
        ),
        const Divider(),
        if (element.type == CardElementType.text) ...[
          TextFormField(
            key: ValueKey(element.id),
            initialValue: element.content,
            decoration: InputDecoration(
                labelText: l10n.textContent, 
                border: const OutlineInputBorder()),
            onChanged: (text) =>
                updateProperty(text, (e, v) => e.copyWith(content: v)),
          ),
          const SizedBox(height: 16),
        ],
        if (element.type != CardElementType.qrCode &&
            element.type != CardElementType.shape &&
            element.type != CardElementType.fontAwesomeIcon)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.color_lens_outlined),
            title: Text(l10n.elementColor),
            trailing:
                CircleAvatar(backgroundColor: element.style.color, radius: 15),
            onTap: () => _showColorPicker(context, element.style.color!,
                (color) {
              updateProperty(
                  color, (e, v) => e.copyWith(style: e.style.copyWith(color: v)));
            }),
          ),
        if (element.type == CardElementType.fontAwesomeIcon)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.color_lens_outlined),
            title: Text(l10n.iconColor),
            trailing:
                CircleAvatar(backgroundColor: element.style.color, radius: 15),
            onTap: () => _showColorPicker(context, element.style.color!,
                (color) {
              updateProperty(
                  color, (e, v) => e.copyWith(style: e.style.copyWith(color: v)));
            }),
          ),
        if (element.type == CardElementType.shape &&
            element.shapeStyle != null) ...[
          _buildShapeStyleControls(provider, element),
          const Divider(),
        ],
        Text(l10n.opacity, style: const TextStyle(color: Colors.black54)),
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
          _buildAdvancedTextStyleControls(provider, element),
          const Divider(),
          _buildFontFamilySelector(provider, element),
          const Divider(),
        ],
        _buildLayerOrderControls(provider),
      ],
    );
  }

  Widget _buildShapeStyleControls(
      BusinessCardProvider provider, CardElement element) {
    final style = element.shapeStyle!;
    final l10n = AppLocalizations.of(context)!;

    void updateShapeStyle(ShapeStyle newStyle) {
      provider.updateSelectedElementsProperties(
          (e) => e.copyWith(shapeStyle: newStyle));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.shapeStyle, style: Theme.of(context).textTheme.titleSmall),
        if (style.shapeType != ShapeType.line)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.fillColor),
            trailing:
                CircleAvatar(backgroundColor: style.fillColor, radius: 15),
            onTap: () => _showColorPicker(context, style.fillColor, (color) {
              updateShapeStyle(style.copyWith(fillColor: color));
            }),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.borderColor),
          trailing:
              CircleAvatar(backgroundColor: style.borderColor, radius: 15),
          onTap: () => _showColorPicker(context, style.borderColor, (color) {
            updateShapeStyle(style.copyWith(borderColor: color));
          }),
        ),
        Row(children: [
          Text(l10n.borderWidth),
          Expanded(
            child: Slider(
              value: style.borderWidth,
              min: 0,
              max: 20,
              onChanged: (val) {
                updateShapeStyle(style.copyWith(borderWidth: val));
              },
            ),
          ),
          Text(style.borderWidth.toStringAsFixed(1)),
        ]),
      ],
    );
  }

  Widget _buildAdvancedTextStyleControls(
      BusinessCardProvider provider, CardElement element) {
    final style = element.style;
    final hasShadow = style.shadows != null && style.shadows!.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

    void updateStyle(TextStyle newStyle) {
      provider
          .updateSelectedElementsProperties((e) => e.copyWith(style: newStyle));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.advancedTextStyle,
            style: Theme.of(context).textTheme.titleSmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.addShadow),
          value: hasShadow,
          onChanged: (addShadow) {
            final newShadows = addShadow
                ? [
                    const Shadow(
                      blurRadius: 4.0,
                      color: Colors.black54,
                      offset: Offset(2.0, 2.0),
                    ),
                  ]
                : <Shadow>[];
            updateStyle(style.copyWith(shadows: newShadows));
          },
        ),
        Text(l10n.letterSpacing, style: const TextStyle(color: Colors.black54)),
        Slider(
          value: style.letterSpacing ?? 0.0,
          min: -2.0,
          max: 10.0,
          divisions: 120,
          label: (style.letterSpacing ?? 0.0).toStringAsFixed(1),
          onChanged: (val) {
            updateStyle(style.copyWith(letterSpacing: val));
          },
        ),
        Text(l10n.lineHeight, style: const TextStyle(color: Colors.black54)),
        Slider(
          value: style.height ?? 1.0,
          min: 0.5,
          max: 3.0,
          divisions: 25,
          label: (style.height ?? 1.0).toStringAsFixed(1),
          onChanged: (val) {
            updateStyle(style.copyWith(height: val));
          },
        ),
        Text(
          l10n.shadowNote,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTransformControls(
      BusinessCardProvider provider, CardElement element) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sizeRotation,
            style: Theme.of(context).textTheme.titleSmall),
        Row(children: [
          Text(l10n.width),
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
          Text(l10n.height),
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
              provider.updateSelectedElementsProperties(
                  (e) => e.copyWith(rotation: val * math.pi / 180));
            },
          )),
          Text("${(element.rotation * 180 / math.pi).round()}°"),
        ]),
      ],
    );
  }

  Widget _buildTextStyleControls(
      BusinessCardProvider provider, CardElement element) {
    final l10n = AppLocalizations.of(context)!;
    final isBold = element.style.fontWeight == FontWeight.bold;
    final isItalic = element.style.fontStyle == FontStyle.italic;
    
    return Wrap(
      spacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        IconButton(
          tooltip: l10n.bold,
          icon: const Icon(Icons.format_bold),
          color: isBold ? Colors.blue : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties((e) => e
              .copyWith(
                  style: e.style.copyWith(
                      fontWeight:
                          isBold ? FontWeight.normal : FontWeight.bold))),
        ),
        IconButton(
          tooltip: l10n.italic,
          icon: const Icon(Icons.format_italic),
          color: isItalic ? Colors.blue : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties((e) => e
              .copyWith(
                  style: e.style.copyWith(
                      fontStyle:
                          isItalic ? FontStyle.normal : FontStyle.italic))),
        ),
        const VerticalDivider(),
        IconButton(
          tooltip: l10n.alignLeft,
          icon: const Icon(Icons.format_align_left),
          color:
              element.textAlign == TextAlign.left ? Colors.blue : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties(
              (e) => e.copyWith(textAlign: TextAlign.left)),
        ),
        IconButton(
          tooltip: l10n.alignCenter,
          icon: const Icon(Icons.format_align_center),
          color: element.textAlign == TextAlign.center
              ? Colors.blue
              : Colors.black54,
          onPressed: () => provider.updateSelectedElementsProperties(
              (e) => e.copyWith(textAlign: TextAlign.center)),
        ),
        IconButton(
          tooltip: l10n.alignRight,
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
    final l10n = AppLocalizations.of(context)!;
    
    return DropdownButtonFormField<String>(
      value: fontFamilies.contains(element.style.fontFamily)
          ? element.style.fontFamily
          : 'Roboto',
      decoration: InputDecoration(
          labelText: l10n.fontFamily, 
          border: const OutlineInputBorder()),
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
    final l10n = AppLocalizations.of(context)!;
    
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
          label: Text(l10n.sendToBack),
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
          label: Text(l10n.bringToFront),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context, Color initialColor,
      ValueChanged<Color> onColorChanged) {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: onColorChanged,
          ),
        ),
        actions: [
          TextButton(
              child: Text(l10n.ok),
              onPressed: () => Navigator.of(context).pop())
        ],
      ),
    );
  }
}