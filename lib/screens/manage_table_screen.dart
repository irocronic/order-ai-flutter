// lib/screens/manage_table_screen.dart

import '../services/notification_center.dart';
import '../services/refresh_manager.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import 'subscription_screen.dart';
import '../services/qr_export_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:printing/printing.dart';
// Web desteği için ekle:
import 'package:flutter/foundation.dart' show kIsWeb;
// HATA DÜZELTMESİ: 'dart:html' import'u mobil derlemede hataya neden olduğu için kaldırıldı.
// import 'dart:html' as html;

class ManageTableScreen extends StatefulWidget {
  final String token;
  final int businessId;
  const ManageTableScreen({Key? key, required this.token, required this.businessId})
      : super(key: key);
  @override
  _ManageTableScreenState createState() => _ManageTableScreenState();
}

class _ManageTableScreenState extends State<ManageTableScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> tables = [];
  bool _isInitialLoad = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    NotificationCenter.instance.addObserver('refresh_all_screens', (data) {
      if (mounted) {
        final refreshKey = 'manage_table_screen_${widget.businessId}';
        RefreshManager.throttledRefresh(refreshKey, () async {
          await fetchTables();
        });
      }
    });
    NotificationCenter.instance.addObserver('screen_became_active', (data) {
      if (mounted) {
        final refreshKey = 'manage_table_screen_active_${widget.businessId}';
        RefreshManager.throttledRefresh(refreshKey, () async {
          await fetchTables();
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      fetchTables();
      _isInitialLoad = false;
    }
  }

  Future<void> fetchTables() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final response = await http.get(
        ApiService.getUrl('/tables/'),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          tables = jsonDecode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = l10n.manageTablesErrorLoading(response.statusCode.toString());
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = l10n.errorGeneral(e.toString());
          isLoading = false;
        });
      }
    }
  }

  /// GÜNCELLENEN FONKSİYON: Tüm QR kodları ayrı PDF olarak export eder
  Future<void> _exportAllQrCodes() async {
    if (_isExporting || tables.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Tüm QR kodlar PDF olarak kaydediliyor...")),
    );

    try {
      for (final table in tables) {
        await QrExportService.exportSingleTableQrPdf(table);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tüm QR kodlar başarıyla kaydedildi!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("QR PDF export hatası: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _downloadQrImage(String data, String tableNumber) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
      );
      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode;
        final painter = QrPainter.withQr(
          qr: qrCode!,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: false,
        );
        final picData = await painter.toImageData(800);
        if (picData == null) throw Exception("QR kodu oluşturulamadı.");
        final bytes = picData.buffer.asUint8List();

        final fileName = 'masa_${tableNumber}_qr_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';

        if (kIsWeb) {
          // HATA DÜZELTMESİ: Web'de dosya indirme işlemi, mobil derlemede hataya neden olan 'dart:html'
          // kütüphanesini kullandığı için bu blok geçici olarak devre dışı bırakılmıştır.
          // Bu özelliğin hem mobil hem de web'de çalışması için platforma özel kodların
          // ayrı dosyalara taşınarak koşullu import (conditional import) ile kullanılması gerekir.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Web'de indirme özelliği şu an desteklenmiyor."),
                backgroundColor: Colors.orange),
          );
        } else {
          // Mobil için olan kod değiştirilmedi.
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) {
              throw Exception("Depolama izni verilmedi.");
            }
          }

          final io.Directory? dir = await getDownloadsDirectory();
          if (dir == null) throw Exception("İndirilenler klasörü bulunamadı.");
          final filePath = '${dir.path}/$fileName';
          final file = io.File(filePath);
          await file.writeAsBytes(bytes);

          final result = await OpenFile.open(filePath);
          if (result.type != ResultType.done) throw Exception("Dosya açılamadı: ${result.message}");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.manageTablesSuccessQrDownloaded}: $filePath'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTablesErrorQrDownload(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLimitReachedDialog(String message) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogLimitReachedTitle),
        content: Text(message),
        actions: [
          TextButton(
            child: Text(l10n.dialogButtonLater),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
           ElevatedButton(
            child: Text(l10n.dialogButtonUpgradePlan),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showTableDialog({Map<String, dynamic>? table}) async {
    final l10n = AppLocalizations.of(context)!;
    final currentLimits = UserSession.limitsNotifier.value;
    if (table == null && tables.length >= currentLimits.maxTables) {
      _showLimitReachedDialog(
        l10n.manageTablesErrorLimitExceeded(currentLimits.maxTables.toString())
      );
      return;
    }

    final TextEditingController tableNumberController = TextEditingController(
      text: table != null ? table['table_number'].toString() : '',
    );
    final GlobalKey<FormState> _formKeyDialog = GlobalKey<FormState>();
    bool isDialogSubmitting = false;
    String dialogMessage = '';
    await showDialog(
      context: context,
      barrierDismissible: !isDialogSubmitting,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(table == null 
                ? dialogL10n.manageTablesDialogAddTitle : dialogL10n.manageTablesDialogEditTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Form(
              key: _formKeyDialog,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: tableNumberController,
                    decoration: InputDecoration(
                      labelText: dialogL10n.manageTablesLabelTableNumber,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return dialogL10n.manageTablesValidatorEnterNumber;
                      }
                      if (int.tryParse(value) == null) {
                        return dialogL10n.manageTablesValidatorInvalidNumber;
                      }
                      return null;
                    },
                  ),
                  if (dialogMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        dialogMessage,
                        style: TextStyle(color: dialogMessage.contains(dialogL10n.manageTablesInfoCreated.substring(0, 10)) || dialogMessage.contains(dialogL10n.manageTablesInfoUpdated.substring(0, 10)) ? Colors.green : Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDialogSubmitting ? null : () => Navigator.pop(dialogContext),
                child: Text(dialogL10n.dialogButtonCancel),
              ),
              ElevatedButton(
                onPressed: isDialogSubmitting
                    ? null
                    : () async {
                        if (_formKeyDialog.currentState!.validate()) {
                          setStateDialog(() {
                            isDialogSubmitting = true;
                            dialogMessage = '';
                          });
                          int tableNumber = int.parse(tableNumberController.text);

                          try {
                            http.Response response;
                            if (table == null) {
                              response = await http.post(
                                ApiService.getUrl('/tables/'),
                                 headers: {
                                  "Content-Type": "application/json",
                                  "Authorization": "Bearer ${widget.token}",
                                 },
                                body: jsonEncode({
                                  'business': widget.businessId,
                                  'table_number': tableNumber,
                                }),
                              );
                            } else {
                              response = await http.put(
                                ApiService.getUrl('/tables/${table['id']}/'),
                                headers: {
                                  "Content-Type": "application/json",
                                  "Authorization": "Bearer ${widget.token}",
                                   },
                                body: jsonEncode({
                                  'business': widget.businessId,
                                   'table_number': tableNumber,
                                }),
                              );
                            }

                            if (!mounted) return;
                            if (response.statusCode == 201 || response.statusCode == 200) {
                              setStateDialog(() {
                                dialogMessage = table == null
                                    ? dialogL10n.manageTablesInfoCreated
                                    : dialogL10n.manageTablesInfoUpdated;
                              });
                              await fetchTables();
                              Future.delayed(const Duration(seconds: 1), () {
                                if (mounted) Navigator.pop(dialogContext);
                              });
                            } else {
                              String errorMsg = dialogL10n.manageTablesErrorGeneric(response.statusCode.toString());
                              try {
                                final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
                                if (errorBody is Map && errorBody['code'] == 'limit_reached') {
                                  Navigator.of(dialogContext).pop();
                                  _showLimitReachedDialog(errorBody['detail']);
                                  errorMsg = ''; 
                                } else if (errorBody is Map && errorBody['table_number'] is List && errorBody['table_number'].isNotEmpty) {
                                  errorMsg = errorBody['table_number'][0];
                                } else if (errorBody is Map && errorBody['detail'] is String) {
                                  errorMsg = errorBody['detail'];
                                }
                              } catch (_) {}
                              if (errorMsg.isNotEmpty) {
                                setStateDialog(() => dialogMessage = errorMsg);
                              }
                            }
                          } catch (e) {
                            if (mounted) setStateDialog(() => dialogMessage = dialogL10n.errorGeneral(e.toString()));
                          } finally {
                            if (mounted) setStateDialog(() => isDialogSubmitting = false);
                          }
                        }
                      },
                child: isDialogSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(table == null ? dialogL10n.manageTablesButtonCreate : l10n.updateButton),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteTable(int tableId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(dialogL10n.manageTablesDialogDeleteTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(dialogL10n.manageTablesDialogDeleteContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogL10n.dialogButtonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogL10n.dialogButtonDelete, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (confirm != true || !mounted) return;

    setState(() => isLoading = true);
    try {
      final response = await http.delete(
        ApiService.getUrl('/tables/$tableId/'),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (!mounted) return;
      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTablesInfoDeleted), backgroundColor: Colors.green),
        );
        fetchTables();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTablesErrorDeleting(response.statusCode.toString()))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTablesErrorDeleting(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _copyGuestLink(String uuid) {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse(ApiService.baseUrl.replaceAll('/api', ''));
    final guestLink = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/guest/tables/$uuid/';

    Clipboard.setData(ClipboardData(text: guestLink)).then((_) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.manageTablesInfoGuestLinkCopied)),
        );
      }
    });
  }

  Future<void> _showQrDialog(BuildContext context, String guestLink, String tableNumber) async {
    final l10n = AppLocalizations.of(context)!;
    if (guestLink.contains('Link Yok') || guestLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.manageTablesErrorNoGuestLink)),
      );
      return;
    }
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(dialogL10n.manageTablesDialogQrTitle(tableNumber), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 250,
            height: 350,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                QrImageView(
                  data: guestLink,
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(40, 40),
                  ),
                  errorStateBuilder: (cxt, err) {
                    return Center(
                      child: Text(
                        dialogL10n.manageTablesErrorCreatingQr,
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SelectableText(
                  guestLink,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: Text(dialogL10n.manageTablesButtonDownloadQr),
                  onPressed: () => _downloadQrImage(guestLink, tableNumber),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              child: Text(dialogL10n.dialogButtonClose, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          l10n.manageTablesTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF283593),
                Color(0xFF455A64),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (!_isExporting)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
              tooltip: l10n.manageTablesTooltipExportQr,
              onPressed: isLoading || tables.isEmpty ? null : _exportAllQrCodes,
            ),
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
          ValueListenableBuilder<SubscriptionLimits>(
            valueListenable: UserSession.limitsNotifier,
            builder: (context, limits, child) {
              final bool canAddMore = tables.length < limits.maxTables;
              return IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: isLoading || !canAddMore ? null : () => _showTableDialog(),
                tooltip: l10n.manageTablesTooltipAdd,
              );
            },
          ),
        ],
      ),
      body: Container(
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
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : errorMessage.isNotEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(errorMessage, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16), textAlign: TextAlign.center),
                    ))
                  : RefreshIndicator(
                      onRefresh: fetchTables,
                      color: Colors.white,
                      backgroundColor: Colors.blue.shade700,
                      child: tables.isEmpty
                          ? Center(child: Text(l10n.manageTablesNoTablesFound, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, height: 1.5), textAlign: TextAlign.center,))
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 350.0,
                                mainAxisSpacing: 16.0,
                                crossAxisSpacing: 16.0,
                                childAspectRatio: 1.5,
                              ),
                              itemCount: tables.length,
                              itemBuilder: (context, index) {
                                final table = tables[index];
                                final String tableUuid = table['uuid'] ?? '';
                                final uri = Uri.parse(ApiService.baseUrl.replaceAll('/api', ''));
                                final String guestLink = tableUuid.isNotEmpty ?
                                    '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/guest/tables/$tableUuid/' : l10n.manageTablesErrorNoGuestLink;

                                return Card(
                                  color: Colors.white.withOpacity(0.8),
                                  elevation: 8,
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          l10n.manageTablesCardTitle(table['table_number'].toString()),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                        Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                           children: [
                                            Text(
                                              l10n.manageTablesCardGuestLink,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54),
                                            ),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: SelectableText(
                                                    guestLink,
                                                    style: const TextStyle(fontSize: 14, color: Colors.blueAccent),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                if (tableUuid.isNotEmpty)
                                                  IconButton(
                                                    icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                                                    tooltip: l10n.manageTablesTooltipCopyLink,
                                                    onPressed: () => _copyGuestLink(tableUuid),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                         Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (tableUuid.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.qr_code_2, color: Colors.deepPurpleAccent),
                                                tooltip: l10n.manageTablesTooltipShowQr,
                                                onPressed: () => _showQrDialog(context, guestLink, table['table_number'].toString()),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                              tooltip: l10n.tooltipEdit,
                                              onPressed: () => _showTableDialog(table: table),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                                              tooltip: l10n.tooltipDelete,
                                              onPressed: () => _deleteTable(table['id']),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ),
    );
  }
}