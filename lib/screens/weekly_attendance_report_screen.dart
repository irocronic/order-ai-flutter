// lib/screens/weekly_attendance_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../services/user_session.dart';

class WeeklyAttendanceReportScreen extends StatefulWidget {
  const WeeklyAttendanceReportScreen({Key? key}) : super(key: key);

  @override
  _WeeklyAttendanceReportScreenState createState() => _WeeklyAttendanceReportScreenState();
}

class _WeeklyAttendanceReportScreenState extends State<WeeklyAttendanceReportScreen> {
  Map<String, List<AttendanceRecord>> _weeklyData = {};
  Map<String, Map<String, double>> _staffWeeklyHours = {};
  bool _isLoading = true;
  String _errorMessage = '';
  
  DateTime _selectedWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchWeeklyData();
  }

  DateTime get _weekEnd => _selectedWeekStart.add(const Duration(days: 6));

  Future<void> _fetchWeeklyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final records = await AttendanceService.fetchAttendanceHistory(
        UserSession.token,
        startDate: _selectedWeekStart.toIso8601String().split('T')[0],
        endDate: _weekEnd.toIso8601String().split('T')[0],
      );

      if (mounted) {
        setState(() {
          _processWeeklyData(records);
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

  void _processWeeklyData(List<AttendanceRecord> records) {
    _weeklyData.clear();
    _staffWeeklyHours.clear();

    // Personellere göre kayıtları grupla
    for (final record in records) {
      final staffName = 'User ${record.userId}'; // API'den staff name alınabilir
      if (!_weeklyData.containsKey(staffName)) {
        _weeklyData[staffName] = [];
        _staffWeeklyHours[staffName] = {};
      }
      _weeklyData[staffName]!.add(record);
    }

    // Her personel için günlük ve haftalık saatleri hesapla
    for (final staffName in _weeklyData.keys) {
      _calculateStaffHours(staffName, _weeklyData[staffName]!);
    }
  }

  void _calculateStaffHours(String staffName, List<AttendanceRecord> records) {
    final Map<String, List<AttendanceRecord>> dailyRecords = {};
    
    // Günlere göre kayıtları grupla
    for (final record in records) {
      final dayKey = _dateFormat.format(record.timestamp);
      if (!dailyRecords.containsKey(dayKey)) {
        dailyRecords[dayKey] = [];
      }
      dailyRecords[dayKey]!.add(record);
    }

    double totalWeeklyHours = 0.0;
    _staffWeeklyHours[staffName] = {};

    // Her gün için çalışma saatini hesapla
    for (final dayKey in dailyRecords.keys) {
      final dayRecords = dailyRecords[dayKey]!;
      dayRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      double dailyHours = 0.0;
      AttendanceRecord? lastCheckIn;

      for (final record in dayRecords) {
        if (record.type == AttendanceType.checkIn) {
          lastCheckIn = record;
        } else if (record.type == AttendanceType.checkOut && lastCheckIn != null) {
          final duration = record.timestamp.difference(lastCheckIn.timestamp);
          dailyHours += duration.inMinutes / 60.0;
          lastCheckIn = null;
        }
      }

      _staffWeeklyHours[staffName]![dayKey] = dailyHours;
      totalWeeklyHours += dailyHours;
    }

    _staffWeeklyHours[staffName]!['TOTAL'] = totalWeeklyHours;
  }

  Future<void> _selectWeek() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Hafta Seçin',
    );

    if (picked != null) {
      // Seçilen tarihin haftasının başlangıcını bul (Pazartesi)
      final weekStart = picked.subtract(Duration(days: picked.weekday - 1));
      setState(() {
        _selectedWeekStart = weekStart;
      });
      _fetchWeeklyData();
    }
  }

  Widget _buildWeekSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seçili Hafta',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateFormat.format(_selectedWeekStart)} - ${_dateFormat.format(_weekEnd)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _selectWeek,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text('Değiştir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffWeeklyCard(String staffName) {
    final staffHours = _staffWeeklyHours[staffName] ?? <String, double>{};
    final totalHours = staffHours['TOTAL'] ?? 0.0;
    final staffRecords = _weeklyData[staffName] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personel bilgi başlığı
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    staffName.split(' ').map((e) => e[0]).take(2).join(),
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Toplam: ${totalHours.toStringAsFixed(1)} saat',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getHoursColor(totalHours).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${totalHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      color: _getHoursColor(totalHours),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Günlük detaylar
            _buildDailyDetails(staffHours),
            
            const SizedBox(height: 12),
            
            // Özet istatistikler
            _buildWeeklyStats(staffRecords, totalHours),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDetails(Map<String, double> staffHours) {
    final weekDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Günlük Çalışma Saatleri',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(7, (index) {
          final date = _selectedWeekStart.add(Duration(days: index));
          final dateKey = _dateFormat.format(date);
          final dayHours = staffHours[dateKey] ?? 0.0;
          final dayName = weekDays[index];
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (dayHours / 12).clamp(0.0, 1.0), // 12 saat maksimum
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getHoursColor(dayHours),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${dayHours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeeklyStats(List<AttendanceRecord> records, double totalHours) {
    final checkIns = records.where((r) => r.type == AttendanceType.checkIn).length;
    final checkOuts = records.where((r) => r.type == AttendanceType.checkOut).length;
    final workingDays = (totalHours / 8).ceil().clamp(0, 7); // 8 saat = 1 gün
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Giriş', checkIns.toString(), Icons.login),
          ),
          Expanded(
            child: _buildStatItem('Çıkış', checkOuts.toString(), Icons.logout),
          ),
          Expanded(
            child: _buildStatItem('Çalışma Günü', workingDays.toString(), Icons.work),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Color _getHoursColor(double hours) {
    if (hours >= 8) return Colors.green;
    if (hours >= 6) return Colors.orange;
    if (hours >= 4) return Colors.amber;
    return Colors.red;
  }

  Widget _buildSummaryCard() {
    final totalStaff = _weeklyData.length;
    final totalHours = _staffWeeklyHours.values
        .map((hours) => hours['TOTAL'] ?? 0.0)
        .fold(0.0, (sum, hours) => sum + hours);
    final avgHours = totalStaff > 0 ? totalHours / totalStaff : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Haftalık Özet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Toplam Personel',
                    totalStaff.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Toplam Saat',
                    '${totalHours.toStringAsFixed(1)}h',
                    Icons.access_time,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Ortalama/Kişi',
                    '${avgHours.toStringAsFixed(1)}h',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Haftalık Çalışma Raporu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade900, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchWeeklyData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade900.withOpacity(0.9),
              Colors.purple.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildWeekSelector(),
            
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
                                onPressed: _fetchWeeklyData,
                                child: const Text('Yeniden Dene'),
                              ),
                            ],
                          ),
                        )
                      : _weeklyData.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.work_off,
                                    size: 64,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Seçilen hafta için kayıt bulunamadı',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              children: [
                                _buildSummaryCard(),
                                ..._weeklyData.keys.map((staffName) => 
                                  _buildStaffWeeklyCard(staffName)
                                ).toList(),
                                const SizedBox(height: 20),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}