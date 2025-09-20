// lib/screens/map_picker_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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

  // --- YENİ EKLENEN DEĞİŞKENLER ---
  final TextEditingController _searchController = TextEditingController();
  String _sessionToken = const Uuid().v4();
  List<dynamic> _placePredictions = [];
  final String _apiKey = "AIzaSyBAgXbA85EJfjSCc5BdQtEdH3wXJ1trb80"; // API anahtarınız

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
      _placePredictions = []; // Tahmin listesini temizle
    });
  }

  // --- YENİ EKLENEN METOTLAR ---

  // Google Places Autocomplete API'sini kullanarak yer araması yapar.
  Future<void> _searchPlaces(String input) async {
    if (input.isEmpty) {
      setState(() {
        _placePredictions = [];
      });
      return;
    }

    final String baseUrl =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String url =
        '$baseUrl?input=$input&key=$_apiKey&sessiontoken=$_sessionToken&language=tr&components=country:tr';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _placePredictions = json.decode(response.body)['predictions'];
        });
      } else {
        // Hata durumunda kullanıcıya bilgi verilebilir.
        print('Places API Error: ${response.body}');
      }
    } catch (e) {
      print('Arama sırasında bir hata oluştu: $e');
    }
  }

  // Seçilen yerin detaylarını (enlem/boylam) alır.
  Future<void> _getPlaceDetails(String placeId) async {
    final String baseUrl =
        'https://maps.googleapis.com/maps/api/place/details/json';
    String url =
        '$baseUrl?place_id=$placeId&key=$_apiKey&sessiontoken=$_sessionToken&fields=geometry';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final details = json.decode(response.body)['result'];
        if (details != null && details['geometry'] != null) {
          final location = details['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final newPosition = LatLng(lat, lng);

          setState(() {
            _pickedLocation = newPosition;
            _addMarker(newPosition);
            _placePredictions = []; // Listeyi temizle
            _searchController.clear(); // Arama çubuğunu temizle
          });

          // Haritayı yeni konuma hareket ettir
          _mapController.animateCamera(CameraUpdate.newLatLngZoom(newPosition, 17.0));

          // Yeni bir arama oturumu için token'ı yenile
          _sessionToken = const Uuid().v4();
        }
      } else {
        print('Place Details API Error: ${response.body}');
      }
    } catch (e) {
      print('Yer detayı alınırken bir hata oluştu: $e');
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
      // YAPI DEĞİŞİKLİĞİ: Arama çubuğu ve sonuçlarını haritanın üzerine koymak için Stack kullanıldı.
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
                  prefixIcon: const Icon(Icons.search),
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
                constraints: BoxConstraints(maxHeight: 250),
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
                    return ListTile(
                      title: Text(_placePredictions[index]['description']),
                      onTap: () {
                        _getPlaceDetails(_placePredictions[index]['place_id']);
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
