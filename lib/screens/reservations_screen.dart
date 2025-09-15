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

  Future<void> _confirm(int id) async {
    await ReservationService.confirmReservation(UserSession.token, id);
    _refreshReservations();
  }

  Future<void> _cancel(int id) async {
    await ReservationService.cancelReservation(UserSession.token, id);
    _refreshReservations();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reservationsTitle, style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade700, Colors.purple.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          tabs: [
            Tab(text: l10n.reservationsTabPending),
            Tab(text: l10n.reservationsTabConfirmed),
            Tab(text: l10n.reservationsTabPast),
          ],
        ),
      ),
      body: FutureBuilder<List<Reservation>>(
        future: _reservationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.errorGeneral(snapshot.error.toString())));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.reservationsNoReservations));
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
    );
  }

  Widget _buildReservationList(List<Reservation> reservations, AppLocalizations l10n) {
    if (reservations.isEmpty) {
      return Center(child: Text(l10n.reservationsNoReservationsInThisCategory));
    }
    return ListView.builder(
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final res = reservations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(child: Text(res.partySize.toString())),
            title: Text(res.customerName),
            subtitle: Text('Masa ${res.tableNumber} - ${DateFormat('dd.MM.yyyy HH:mm').format(res.reservationTime)}'),
            trailing: res.status == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _confirm(res.id)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _cancel(res.id)),
                    ],
                  )
                : Text(res.statusDisplay),
          ),
        );
      },
    );
  }
}