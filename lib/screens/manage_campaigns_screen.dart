// lib/screens/manage_campaigns_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/campaign_service.dart';
import '../models/campaign_menu.dart';
import 'add_edit_campaign_screen.dart';
import '../widgets/admin/admin_confirmation_dialog.dart';
import '../utils/currency_formatter.dart'; // Para formatlayıcı eklendi

class ManageCampaignsScreen extends StatefulWidget {
  final String token;
  final int businessId;

  const ManageCampaignsScreen({
    Key? key,
    required this.token,
    required this.businessId,
  }) : super(key: key);

  @override
  _ManageCampaignsScreenState createState() => _ManageCampaignsScreenState();
}

class _ManageCampaignsScreenState extends State<ManageCampaignsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<CampaignMenu> _campaigns = [];
  bool _isDataFetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataFetched) {
      _fetchCampaigns();
      _isDataFetched = true;
    }
  }

  Future<void> _fetchCampaigns() async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final campaigns =
          await CampaignService.fetchCampaigns(widget.token, widget.businessId);
      if (mounted) {
        setState(() {
          _campaigns = campaigns;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.manageCampaignsErrorFetching(
              e.toString().replaceFirst("Exception: ", ""));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToAddEditCampaignScreen({CampaignMenu? campaign}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCampaignScreen(
          token: widget.token,
          businessId: widget.businessId,
          campaignMenu: campaign,
        ),
      ),
    );
    if (result == true && mounted) {
      _fetchCampaigns();
    }
  }

  Future<void> _deleteCampaign(CampaignMenu campaign) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmationDialog(
        title: l10n.manageCampaignsDeleteDialogTitle,
        content: l10n.manageCampaignsDeleteDialogContent(campaign.name),
        confirmButtonText: l10n.manageCampaignsDeleteDialogConfirmButton,
        isDestructive: true,
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await CampaignService.deleteCampaign(widget.token, campaign.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.manageCampaignsSuccessDelete(campaign.name)),
                backgroundColor: Colors.orangeAccent),
          );
          _fetchCampaigns();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.manageCampaignsErrorDelete(e.toString())),
                backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildCampaignCard(CampaignMenu campaign, AppLocalizations l10n) {
    final statusText = campaign.isActive
        ? l10n.manageCampaignsStatusActive
        : l10n.manageCampaignsStatusInactive;
    
    String dateInfo = '';
    if (campaign.startDate != null && campaign.startDate!.isNotEmpty) {
      dateInfo += l10n.manageCampaignsStartDate(DateFormat('dd/MM/yy').format(DateTime.parse(campaign.startDate!)));
    }
    if (campaign.endDate != null && campaign.endDate!.isNotEmpty) {
      if (dateInfo.isNotEmpty) dateInfo += " - ";
      dateInfo += l10n.manageCampaignsEndDate(DateFormat('dd/MM/yy').format(DateTime.parse(campaign.endDate!)));
    }

    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToAddEditCampaignScreen(campaign: campaign),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: campaign.image != null && campaign.image!.isNotEmpty
                  ? Image.network(
                      campaign.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    )
                  : Icon(Icons.campaign_outlined, size: 50, color: Colors.grey.shade700),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(campaign.campaignPrice),
                    style: TextStyle(fontSize: 14, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                  ),
                  if (dateInfo.isNotEmpty)
                    Text(
                      dateInfo,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              color: Colors.black.withOpacity(0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // +++ DEĞİŞİKLİK BURADA BAŞLIYOR +++
                  // Chip widget'ı, butonlar sabit alan kaplarken kalan alanı doldurması için
                  // Expanded widget'ı ile sarmalandı. Bu, taşma hatasını önler.
                  Expanded(
                    child: Chip(
                      label: Text(
                        statusText,
                        overflow: TextOverflow.ellipsis, // Uzun metinler için güvenlik önlemi
                      ),
                      backgroundColor: campaign.isActive ? Colors.green.shade100 : Colors.red.shade100,
                      labelStyle: TextStyle(
                        color: campaign.isActive ? Colors.green.shade900 : Colors.red.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.bold
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  // --- DEĞİŞİKLİK BURADA BİTİYOR ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                        tooltip: l10n.tooltipEdit,
                        onPressed: () => _navigateToAddEditCampaignScreen(campaign: campaign),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.redAccent.shade200, size: 20),
                        tooltip: l10n.tooltipDelete,
                        onPressed: () => _deleteCampaign(campaign),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageCampaignsScreenTitle,
            style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: l10n.manageCampaignsTooltipAdd,
            onPressed: () => _navigateToAddEditCampaignScreen(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage,
                        style: const TextStyle(
                            color: Colors.orangeAccent, fontSize: 16),
                        textAlign: TextAlign.center),
                  ))
                : _campaigns.isEmpty
                    ? Center(
                        child: Text(l10n.manageCampaignsNoCampaigns,
                            style: TextStyle(color: Colors.white.withOpacity(0.7))))
                    : RefreshIndicator(
                        onRefresh: _fetchCampaigns,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 250,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16
                          ),
                          itemCount: _campaigns.length,
                          itemBuilder: (context, index) {
                            final campaign = _campaigns[index];
                            return _buildCampaignCard(campaign, l10n);
                          },
                        ),
                      ),
      ),
    );
  }
}