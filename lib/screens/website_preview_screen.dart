// lib/screens/website_preview_screen.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';

class WebsitePreviewScreen extends StatefulWidget {
  final String businessSlug;

  const WebsitePreviewScreen({Key? key, required this.businessSlug}) : super(key: key);

  @override
  _WebsitePreviewScreenState createState() => _WebsitePreviewScreenState();
}

class _WebsitePreviewScreenState extends State<WebsitePreviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final String publicUrl = '${ApiService.baseUrl.replaceAll('/api', '')}/website/${widget.businessSlug}/';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(publicUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Sitesi Önizlemesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}