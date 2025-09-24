// lib/widgets/setup_wizard/categories/components/image_picker_widget.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(XFile?, Uint8List?) onImageChanged;
  final XFile? initialImageFile;
  final Uint8List? initialImageBytes;

  const ImagePickerWidget({
    Key? key,
    required this.onImageChanged,
    this.initialImageFile,
    this.initialImageBytes,
  }) : super(key: key);

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  XFile? _pickedImageXFile;
  Uint8List? _webImageBytes;

  @override
  void initState() {
    super.initState();
    _pickedImageXFile = widget.initialImageFile;
    _webImageBytes = widget.initialImageBytes;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          _webImageBytes = null; // Will be loaded async
          _pickedImageXFile = null;
          image.readAsBytes().then((bytes) {
            setState(() {
              _webImageBytes = bytes;
            });
            widget.onImageChanged(null, bytes);
          });
        } else {
          _pickedImageXFile = image;
          _webImageBytes = null;
          widget.onImageChanged(image, null);
        }
      });
    }
  }

  Widget _buildImagePreview() {
    Widget placeholder = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white38),
      ),
      child: const Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 40),
    );

    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(_webImageBytes!, height: 100, width: 100, fit: BoxFit.cover),
      );
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(_pickedImageXFile!.path), height: 100, width: 100, fit: BoxFit.cover),
      );
    }
    return placeholder;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildImagePreview(),
        const SizedBox(width: 12),
        Expanded(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.imagePickerSelectButton),
          ),
        ),
      ],
    );
  }
}