// lib/screens/map_picker_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerScreen({
    Key? key,
    this.initialLocation = const LatLng(39.9334, 32.8597), // Ankara
  }) : super(key: key);

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late GoogleMapController _mapController;
  LatLng? _pickedLocation;
  final Set<Marker> _markers = {};

  final TextEditingController _searchController = TextEditingController();
  String _sessionToken = const Uuid().v4();
  List<dynamic> _placePredictions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    // Marker ekleme işlemi onMapCreated içinde yapılacak.
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addMarker(LatLng position, String title, String snippet) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('picked-location'),
          position: position,
          infoWindow: InfoWindow(
            title: title,
            snippet: snippet,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }

  void _onMapTapped(LatLng position) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _pickedLocation = position;
      _addMarker(
        position,
        l10n.mapPickerMarkerTitle,
        l10n.mapPickerMarkerSnippet,
      );
      _placePredictions = [];
    });
  }

  Future<void> _searchPlaces(String input) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final currentLanguageCode = l10n.localeName.split('_').first;

    if (input.isEmpty) {
      setState(() {
        _placePredictions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final url = ApiService.getUrl('/google-places/autocomplete/').replace(
        queryParameters: {
          'input': input,
          'sessiontoken': _sessionToken,
          'language': currentLanguageCode,
          'components': 'country:tr',
        },
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${UserSession.token}",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Google API error status kontrolü
        if (data.containsKey('status') && data['status'] == 'REQUEST_DENIED') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.mapPickerErrorApiKey),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _placePredictions = [];
            _isSearching = false;
          });
          return;
        }

        if (data.containsKey('predictions')) {
          final predictions = data['predictions'] ?? [];
          setState(() {
            _placePredictions = predictions;
            _isSearching = false;
          });
        } else {
          setState(() {
            _placePredictions = [];
            _isSearching = false;
          });
        }
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.mapPickerErrorApiKey),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _placePredictions = [];
          _isSearching = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(l10n.mapPickerErrorSearch(response.statusCode.toString())),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _placePredictions = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapPickerErrorConnection),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _placePredictions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final url = ApiService.getUrl('/google-places/details/').replace(
        queryParameters: {
          'place_id': placeId,
          'sessiontoken': _sessionToken,
          'fields': 'geometry',
        },
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${UserSession.token}",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final details = data['result'];

        if (details != null && details['geometry'] != null) {
          final location = details['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final newPosition = LatLng(lat, lng);

          setState(() {
            _pickedLocation = newPosition;
            _addMarker(
              newPosition,
              l10n.mapPickerMarkerTitle,
              l10n.mapPickerMarkerSnippet,
            );
            _placePredictions = [];
            _searchController.clear();
          });

          _mapController
              .animateCamera(CameraUpdate.newLatLngZoom(newPosition, 17.0));
          _sessionToken = const Uuid().v4();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.mapPickerErrorLocationDetails),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapPickerErrorConnection),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapPickerAppBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: l10n.mapPickerConfirmButton,
            onPressed: _pickedLocation == null
                ? null
                : () {
                    Navigator.of(context).pop(_pickedLocation);
                  },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 16.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Harita oluşturulduğunda başlangıç ​​marker'ını ekliyoruz.
              if (_pickedLocation != null) {
                _addMarker(
                  _pickedLocation!,
                  l10n.mapPickerMarkerTitle,
                  l10n.mapPickerMarkerSnippet,
                );
              }
            },
            onTap: _onMapTapped,
            markers: _markers,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
          ),
          // ARAMA ÇUBUĞU
          Positioned(
            top: 10,
            right: 15,
            left: 15,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchPlaces(value);
                },
                decoration: InputDecoration(
                  hintText: l10n.mapPickerSearchHint,
                  prefixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _placePredictions = [];
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // ARAMA SONUÇLARI LİSTESİ
          if (_placePredictions.isNotEmpty)
            Positioned(
              top: 70,
              right: 15,
              left: 15,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _placePredictions.length,
                  itemBuilder: (context, index) {
                    final prediction = _placePredictions[index];
                    final description =
                        prediction['description'] ?? l10n.mapPickerUnknownPlace;
                    final placeId = prediction['place_id'] ?? '';

                    return ListTile(
                      title: Text(description),
                      leading: const Icon(Icons.location_on, color: Colors.grey),
                      onTap: () {
                        _getPlaceDetails(placeId);
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_pickedLocation != null) {
            Navigator.of(context).pop(_pickedLocation);
          }
        },
        label: Text(l10n.mapPickerConfirmButton),
        icon: const Icon(Icons.pin_drop),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}