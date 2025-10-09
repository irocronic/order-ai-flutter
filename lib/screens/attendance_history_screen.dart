// lib/screens/attendance_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../services/user_session.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  _AttendanceHistoryScreenState createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    // Default olarak son 7 günü getir
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final records = await AttendanceService.fetchAttendanceHistory(
        UserSession.token,
        startDate: _startDate?.toIso8601String().split('T')[0],
        endDate: _endDate?.toIso8601String().split('T')[0],
      );

      if (mounted) {
        setState(() {
          _records = records;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
        end: _endDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchRecords();
    }
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final isCheckIn = record.type == AttendanceType.checkIn;
    final color = isCheckIn ? Colors.green : Colors.orange;
    final icon = isCheckIn ? Icons.login : Icons.logout;
    final typeText = isCheckIn ? 'Giriş' : 'Çıkış';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          typeText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_dateFormat.format(record.timestamp)} - ${_timeFormat.format(record.timestamp)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (record.notes != null && record.notes!.isNotEmpty)
              Text(
                record.notes!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: record.isManualEntry
            ? Chip(
                label: const Text(
                  'Manuel',
                  style: TextStyle(fontSize: 10),
                ),
                backgroundColor: Colors.blue.withOpacity(0.1),
                side: const BorderSide(color: Colors.blue, width: 1),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Giriş-Çıkış Geçmişi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade900, Colors.orange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Tarih Aralığı Seç',
          ),
          IconButton(
            onPressed: _fetchRecords,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade900.withOpacity(0.9),
              Colors.orange.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Tarih aralığı göstergesi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white.withOpacity(0.1),
              child: Text(
                '${_startDate != null ? _dateFormat.format(_startDate!) : "Başlangıç"} - ${_endDate != null ? _dateFormat.format(_endDate!) : "Bitiş"}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            
            // İçerik
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.orangeAccent),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchRecords,
                                child: const Text('Yeniden Dene'),
                              ),
                            ],
                          ),
                        )
                      : _records.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 64,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Seçilen tarih aralığında kayıt bulunamadı',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _records.length,
                              itemBuilder: (context, index) {
                                return _buildRecordCard(_records[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}