// lib/screens/map_picker_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
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
    _addMarker(_pickedLocation!);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('picked-location'),
          position: position,
          infoWindow: const InfoWindow(
            title: 'Seçilen Konum',
            snippet: 'İşletmenizin konumu burası mı?',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _pickedLocation = position;
      _addMarker(position);
      _placePredictions = [];
    });
  }

  Future<void> _searchPlaces(String input) async {
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
          'language': 'tr',
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Google API error status kontrolü
        if (data.containsKey('status') && data['status'] == 'REQUEST_DENIED') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Maps API anahtarı hatası. Lütfen yöneticinize başvurun.'),
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
          const SnackBar(
            content: Text('API anahtarı hatası. Lütfen yöneticinize başvurun.'),
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
            content: Text('Arama yapılırken hata oluştu: ${response.statusCode}'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _placePredictions = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı hatası. İnternet bağlantınızı kontrol edin.'),
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
            _addMarker(newPosition);
            _placePredictions = [];
            _searchController.clear();
          });

          _mapController.animateCamera(CameraUpdate.newLatLngZoom(newPosition, 17.0));
          _sessionToken = const Uuid().v4();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum detayları alınırken hata oluştu.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı hatası oluştu.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haritadan Konum Seç'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
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
                  hintText: 'Restoran veya adres arayın...',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    final description = prediction['description'] ?? 'Bilinmeyen Yer';
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
        label: const Text("Bu Konumu Onayla"),
        icon: const Icon(Icons.pin_drop),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}