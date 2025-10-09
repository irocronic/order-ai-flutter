// lib/screens/attendance_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/check_in_location.dart';
import '../services/attendance_service.dart';
import '../services/user_session.dart';
import 'check_in_location_management_screen.dart';
import 'attendance_history_screen.dart';
import 'qr_generator_screen.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({Key? key}) : super(key: key);

  @override
  _AttendanceManagementScreenState createState() => _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends State<AttendanceManagementScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<CheckInLocation> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final locations = await AttendanceService.fetchCheckInLocations(UserSession.token);
      if (mounted) {
        setState(() {
          _locations = locations;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.attendanceManagementTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.orangeAccent),
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildManagementCard(
                          l10n.locationManagement,
                          l10n.locationManagementDescription,
                          Icons.location_on,
                          Colors.green.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CheckInLocationManagementScreen(),
                            ),
                          ).then((_) => _fetchLocations()),
                        ),
                        const SizedBox(height: 16),
                        _buildManagementCard(
                          l10n.qrCodeGeneration,
                          l10n.qrCodeGenerationDescription,
                          Icons.qr_code,
                          Colors.purple.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QRGeneratorScreen(locations: _locations),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildManagementCard(
                          l10n.attendanceHistory,
                          l10n.attendanceHistoryDescription,
                          Icons.history,
                          Colors.orange.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AttendanceHistoryScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_locations.isNotEmpty) ...[
                          Text(
                            l10n.activeLocations,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._locations.where((l) => l.isActive).map((location) {
                            return Card(
                              color: Colors.white.withOpacity(0.9),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.green),
                                title: Text(location.name),
                                subtitle: Text(
                                  l10n.radiusMeters(location.radiusMeters.toInt()),
                                ),
                                trailing: Icon(
                                  location.isActive ? Icons.check_circle : Icons.cancel,
                                  color: location.isActive ? Colors.green : Colors.red,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildManagementCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}