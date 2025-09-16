// lib/screens/reservations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../services/user_session.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({Key? key}) : super(key: key);

  @override
  _ReservationsScreenState createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Reservation>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _refreshReservations();
      }
    });
    _refreshReservations();
  }

  void _refreshReservations() {
    setState(() {
      _reservationsFuture = ReservationService.fetchReservations(UserSession.token);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirm(int reservationId) async {
    await ReservationService.confirmReservation(UserSession.token, reservationId);
    _refreshReservations();
  }

  Future<void> _cancel(int reservationId) async {
    await ReservationService.cancelReservation(UserSession.token, reservationId);
    _refreshReservations();
  }
    Future<void> _markSeated(int reservationId) async {
    await ReservationService.markSeated(UserSession.token, reservationId);
    _refreshReservations();
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // DEĞİŞİKLİK: AppBar tasarımı güncellendi.
      appBar: AppBar(
        title: Text(l10n.reservationsTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // DEĞİŞİKLİK: Arka plana gradyan eklendi.
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          // DEĞİŞİKLİK: TabBar renkleri gradyana uyumlu hale getirildi.
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: l10n.reservationsTabPending),
            Tab(text: l10n.reservationsTabConfirmed),
            Tab(text: l10n.reservationsTabPast),
          ],
        ),
      ),
      // DEĞİŞİKLİK: Body'e gradyan arka planı eklendi.
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
        child: FutureBuilder<List<Reservation>>(
          future: _reservationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(child: Text(l10n.reservationsErrorLoading('${snapshot.error}'), style: const TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text(l10n.reservationsNoReservationsFound, style: const TextStyle(color: Colors.white, fontSize: 16)));
            }

            final allReservations = snapshot.data!;
            return TabBarView(
              controller: _tabController,
              children: [
                _buildReservationList(allReservations.where((r) => r.status == 'pending').toList(), l10n),
                _buildReservationList(allReservations.where((r) => r.status == 'confirmed').toList(), l10n),
                _buildReservationList(allReservations.where((r) => r.status != 'pending' && r.status != 'confirmed').toList(), l10n),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReservationList(List<Reservation> reservations, AppLocalizations l10n) {
    if (reservations.isEmpty) {
      return Center(child: Text(l10n.reservationsNoReservationsInThisCategory, style: const TextStyle(color: Colors.white, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8), // Liste için boşluk eklendi
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final res = reservations[index];
        // DEĞİŞİKLİK: Card tasarımı güncellendi.
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.white.withOpacity(0.9),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Tooltip(
                message: l10n.reservationsPartySizeTooltip(res.partySize),
                child: Text(
                  res.partySize.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),
            title: Text(res.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
            subtitle: Text(
              '${l10n.tableLabel} ${res.tableNumber} - ${DateFormat('dd.MM.yyyy HH:mm').format(res.reservationTime)}',
               style: TextStyle(color: Colors.black54),
            ),
            trailing: _buildTrailingForRow(res, l10n),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    _buildDetailRow(Icons.phone, res.customerPhone, l10n),
                    if (res.customerEmail != null && res.customerEmail!.isNotEmpty)
                      _buildDetailRow(Icons.email, res.customerEmail!, l10n),
                    if (res.notes != null && res.notes!.isNotEmpty)
                      _buildDetailRow(Icons.notes, res.notes!, l10n),
                    const SizedBox(height: 8),
                    _buildStatusChip(res, l10n),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrailingForRow(Reservation res, AppLocalizations l10n) {
    if (res.status == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            tooltip: l10n.reservationsConfirmTooltip,
            onPressed: () => _confirm(res.id),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            tooltip: l10n.reservationsCancelTooltip,
            onPressed: () => _cancel(res.id),
          ),
        ],
      );
    }
    if (res.status == 'confirmed') {
      return Tooltip(
        message: l10n.reservationsMarkSeatedTooltip,
        // DEĞİŞİKLİK: Buton tasarımı güncellendi.
        child: ElevatedButton.icon(
          icon: const Icon(Icons.event_seat, size: 18),
          label: Text(l10n.reservationsMarkSeatedButton),
          onPressed: () => _markSeated(res.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 5,
          ),
        ),
      );
    }
    return const SizedBox(width: 48); // Diğer durumlar için boşluk bırak
  }

  Widget _buildDetailRow(IconData icon, String text, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(text, style: TextStyle(color: Colors.grey.shade800))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Reservation res, AppLocalizations l10n) {
    Color chipColor;
    Color textColor;
    String statusText = res.statusDisplay;

    switch (res.status) {
      case 'confirmed':
        chipColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        break;
      case 'seated':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case 'cancelled':
        chipColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        break;
      default: // pending ve diğer durumlar
        chipColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Chip(
        label: Text(
          statusText,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: chipColor,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}