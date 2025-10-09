// lib/screens/check_in_location_management_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/check_in_location.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';
import '../services/user_session.dart';

class CheckInLocationManagementScreen extends StatefulWidget {
  const CheckInLocationManagementScreen({Key? key}) : super(key: key);

  @override
  _CheckInLocationManagementScreenState createState() => _CheckInLocationManagementScreenState();
}

class _CheckInLocationManagementScreenState extends State<CheckInLocationManagementScreen> {
  List<CheckInLocation> _locations = [];
  bool _isLoading = true;
  String _errorMessage = '';

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

  Future<void> _showAddLocationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddLocationDialog(),
    );

    if (result == true) {
      _fetchLocations();
    }
  }

  Future<void> _showEditLocationDialog(CheckInLocation location) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditLocationDialog(location: location),
    );

    if (result == true) {
      _fetchLocations();
    }
  }

  Future<void> _deleteLocation(CheckInLocation location) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLocation),
        content: Text(l10n.deleteLocationConfirmation(location.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AttendanceService.deleteCheckInLocation(UserSession.token, location.id);
        _fetchLocations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.locationDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteError(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.checkInLocations,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade900, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showAddLocationDialog,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade900.withOpacity(0.9),
              Colors.green.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                          onPressed: _fetchLocations,
                          child: Text(l10n.tryAgain),
                        ),
                      ],
                    ),
                  )
                : _locations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_off,
                              size: 64,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noLocationAdded,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddLocationDialog,
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addLocation),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final location = _locations[index];
                          return Card(
                            color: Colors.white.withOpacity(0.9),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                location.isActive ? Icons.location_on : Icons.location_off,
                                color: location.isActive ? Colors.green : Colors.red,
                              ),
                              title: Text(
                                location.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.radiusMeters(location.radiusMeters.toInt())),
                                  Text(
                                    l10n.status(location.isActive ? l10n.active : l10n.inactive),
                                    style: TextStyle(
                                      color: location.isActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(l10n.edit),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete, color: Colors.red),
                                        const SizedBox(width: 8),
                                        Text(l10n.delete),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditLocationDialog(location);
                                  } else if (value == 'delete') {
                                    _deleteLocation(location);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _AddLocationDialog extends StatefulWidget {
  @override
  _AddLocationDialogState createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      } else {
        throw Exception('location_not_obtained');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.locationError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _createLocation() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseGetLocationFirst),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      await AttendanceService.createCheckInLocation(
        UserSession.token,
        name: _nameController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        radiusMeters: double.parse(_radiusController.text),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.locationCreatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.creationError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.addNewLocation),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.locationName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.locationNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                decoration: InputDecoration(
                  labelText: l10n.radiusMeter,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.radiusRequired;
                  }
                  final radius = double.tryParse(value);
                  if (radius == null || radius <= 0) {
                    return l10n.enterValidRadius;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                      icon: _isGettingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(_isGettingLocation ? l10n.getting : l10n.getLocation),
                    ),
                  ),
                ],
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.locationCoordinates(_latitude!.toStringAsFixed(6), _longitude!.toStringAsFixed(6)),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createLocation,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.create),
        ),
      ],
    );
  }
}

class _EditLocationDialog extends StatefulWidget {
  final CheckInLocation location;

  const _EditLocationDialog({required this.location});

  @override
  _EditLocationDialogState createState() => _EditLocationDialogState();
}

class _EditLocationDialogState extends State<_EditLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _radiusController;
  late bool _isActive;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location.name);
    _radiusController = TextEditingController(text: widget.location.radiusMeters.toString());
    _isActive = widget.location.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _updateLocation() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await AttendanceService.updateCheckInLocation(
        UserSession.token,
        widget.location.id,
        name: _nameController.text.trim(),
        radiusMeters: double.parse(_radiusController.text),
        isActive: _isActive,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.locationUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.updateError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.editLocation),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.locationName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.locationNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                decoration: InputDecoration(
                  labelText: l10n.radiusMeter,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.radiusRequired;
                  }
                  final radius = double.tryParse(value);
                  if (radius == null || radius <= 0) {
                    return l10n.enterValidRadius;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.active),
                subtitle: Text(_isActive ? l10n.thisLocationIsActive : l10n.thisLocationIsInactive),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateLocation,
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.update),
        ),
      ],
    );
  }
}