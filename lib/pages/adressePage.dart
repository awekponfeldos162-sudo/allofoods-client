// lib/pages/adressePage.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/env_config.dart';
import '../models/cart_model.dart';
import '../models/delivery_model.dart'
    show DeliveryCalculator, DeliveryLocation, DeliveryProvider, LatLngPoint;
import 'RecapPage.dart';
import '../services/adresse_search_service.dart';

// Centre de Cotonou — utilisé comme origine et biais de localisation
const LatLng _cotonou = LatLng(6.3654, 2.4183);

class AdressePage extends StatefulWidget {
  final int? totalAmount;
  final String restaurantId;
  final String? prefillType; // 'home' | 'work' | null

  const AdressePage({
    super.key,
    this.totalAmount,
    this.restaurantId = '',
    this.prefillType,
  });

  @override
  State<AdressePage> createState() => _AdressePageState();
}

class _AdressePageState extends State<AdressePage> {
  // Carte
  final Completer<GoogleMapController> _mapCtrl = Completer();
  LatLng _marker = _cotonou;
  bool _mapReady = false;

  // États
  bool _locating = false;
  bool _geocoding = false;
  bool _searching = false;
  String _gpsError = '';
  String _address = '';
  double _distanceKm = 0;
  int _deliveryFee = 500;

  // Champs
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Autocomplete
  Timer? _debounce;
  List<LieuSuggestion> _results = [];
  bool _showResults = false;

  // Jeton de session Places API (New) — regroupe autocomplete + place details
  // en une seule session pour optimiser la facturation.
  String? _sessionToken;

  // Adresses récentes
  List<Map<String, dynamic>> _recentAddresses = [];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // Génère un jeton de session aléatoire (UUID-like, URL-safe)
  String _newSessionToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recalc(_cotonou);
      _getLocation();
      _loadRecentAddresses();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ─── Adresses récentes ────────────────────────────────────────────────────

  Future<void> _loadRecentAddresses() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recentAddresses')
          .orderBy('usedAt', descending: true)
          .limit(7)
          .get();
      if (!mounted) return;
      setState(() {
        _recentAddresses = snap.docs.map((d) => d.data()).toList();
      });
    } catch (_) {}
  }

  Future<void> _saveToRecent(String address, double lat, double lng) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recentAddresses');
      final existing =
          await ref.where('address', isEqualTo: address).limit(1).get();
      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference
            .update({'usedAt': FieldValue.serverTimestamp()});
      } else {
        await ref.add({
          'address': address,
          'lat': lat,
          'lng': lng,
          'usedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  // ─── Géocodage inverse ────────────────────────────────────────────────────

  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() {
      _geocoding = true;
      _gpsError = '';
    });
    try {
      final key = Env.googleMapsKey;
      if (key.isNotEmpty && !key.contains('REMPLACER')) {
        // Geocoding API (reste inchangée — pas de nouvelle version)
        final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${pos.latitude},${pos.longitude}'
          '&key=$key&language=fr',
        );
        final resp = await http.get(uri).timeout(const Duration(seconds: 8));
        if (!mounted) return;
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>? ?? [];
          if (results.isNotEmpty) {
            final formatted =
                (results.first as Map<String, dynamic>)['formatted_address']
                    as String?;
            if (formatted != null && formatted.isNotEmpty) {
              setState(() => _address = _stripBenin(formatted));
              return;
            }
          }
        }
      }
      // Fallback geocoding local
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude)
              .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.name?.isNotEmpty == true && p.name != p.subLocality) p.name!,
          if (p.thoroughfare?.isNotEmpty == true) p.thoroughfare!,
          if (p.subLocality?.isNotEmpty == true) p.subLocality!,
          if (p.locality?.isNotEmpty == true) p.locality!,
        ];
        setState(() => _address =
            parts.isNotEmpty ? parts.take(3).join(', ') : _coordFallback(pos));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _address = _coordFallback(pos));
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  String _coordFallback(LatLng pos) =>
      '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

  // Supprime ", Bénin" / ", Benin" en fin d'adresse pour un affichage plus propre
  String _stripBenin(String s) => s
      .replaceAll(RegExp(r',?\s*Bénin\s*$'), '')
      .replaceAll(RegExp(r',?\s*Benin\s*$'), '')
      .trim();

  // ─── Recherche de lieux — délègue à AdresseSearchService ────────────────

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 300), () => _fetchPredictions(val.trim()));
  }

  Future<void> _fetchPredictions(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    _sessionToken ??= _newSessionToken();
    try {
      final suggestions = await AdresseSearchService.rechercher(
        query: query,
        googleMapsKey: Env.googleMapsKey,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      if (suggestions.isNotEmpty) {
        setState(() {
          _results = suggestions;
          _showResults = true;
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ─── Sélection d'un résultat ─────────────────────────────────────────────

  Future<void> _selectResult(LieuSuggestion result) async {
    setState(() {
      _showResults = false;
      _searchCtrl.text = result.titre;
    });
    setState(() => _geocoding = true);
    try {
      final coords = await AdresseSearchService.getCoordinates(
        lieu: result,
        googleMapsKey: Env.googleMapsKey,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      if (coords != null) {
        final ll = LatLng(coords.lat, coords.lng);
        setState(() {
          _address =
              coords.adresse.isNotEmpty ? coords.adresse : result.adresseComplete;
          _marker = ll;
          _searchCtrl.text = result.titre;
        });
        _recalc(ll);
        await _animateCamera(ll);
        if (result.lat != null) await _reverseGeocode(ll);
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
      _sessionToken = null;
    }
  }

  // ─── Utilitaires carte ────────────────────────────────────────────────────

  void _recalc(LatLng pos) {
    try {
      final rp = context.read<DeliveryProvider>().restaurantPos;
      final d = DeliveryCalculator.calculateDistance(
          pos.latitude, pos.longitude, rp.lat, rp.lng);
      setState(() {
        _distanceKm = d;
        _deliveryFee = DeliveryCalculator.calculateDeliveryFee(d);
      });
    } catch (_) {}
  }

  Future<void> _animateCamera(LatLng ll, {double zoom = 15}) async {
    if (!_mapReady) return;
    final ctrl = await _mapCtrl.future;
    ctrl.animateCamera(CameraUpdate.newLatLngZoom(ll, zoom));
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
    if (!mounted) return;
    setState(() {
      _locating = true;
      _gpsError = '';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _gpsError = 'GPS désactivé. Placez le marqueur manuellement.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _gpsError = 'Permission GPS refusée.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _marker = ll);
      _recalc(ll);
      await _reverseGeocode(ll);
      if (mounted) await _animateCamera(ll);
    } catch (_) {
      if (!mounted) return;
      setState(() => _gpsError = 'Impossible d\'obtenir la position GPS.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ─── Confirmation ─────────────────────────────────────────────────────────

  void _onConfirmTap() {
    if (widget.totalAmount != null) {
      _showDeliveryDetailsSheet();
    } else {
      _showSaveSheet();
    }
  }

  void _showDeliveryDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Ajouter un contact à cette adresse',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Renseigner les contacts pour permettre au livreur de vous joindre facilement',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _Input(_nameCtrl, 'Entrer le nom (Optionnel)', Icons.person_outlined),
            const SizedBox(height: 10),
            _PhoneInput(_phoneCtrl),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Description / Repères (optionnel)',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon:
                    const Icon(Icons.info_outline, size: 18, color: Colors.black54),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submitCheckout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              child: Text(
                'Confirmer à ${widget.totalAmount! + _deliveryFee} FCFA',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitCheckout() {
    final addrName = _address.isNotEmpty ? _address : 'Position sélectionnée';
    _saveToRecent(addrName, _marker.latitude, _marker.longitude);

    final delivery = context.read<DeliveryProvider>();
    delivery.setClientPosition(
        LatLngPoint(_marker.latitude, _marker.longitude), addrName);

    final deliveryLocation = DeliveryLocation(
      lat: _marker.latitude,
      lng: _marker.longitude,
      addressName: addrName,
      description: _noteCtrl.text.trim(),
      recipientContact: _phoneCtrl.text.trim(),
      recipientName: _nameCtrl.text.trim(),
      isCustomAddress: false,
    );

    final cart = context.read<CartProvider>();
    final restaurantName = cart.restaurantName.isNotEmpty
        ? cart.restaurantName
        : (cart.items.isNotEmpty ? cart.items.first.restaurantName : '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecapPage(
          deliveryFee: _deliveryFee,
          distanceKm: _distanceKm,
          restaurantName: restaurantName,
          restaurantId: widget.restaurantId.isNotEmpty
              ? widget.restaurantId
              : cart.restaurantId,
          deliveryAddress: addrName,
          deliveryLat: _marker.latitude,
          deliveryLng: _marker.longitude,
          deliveryNote: _noteCtrl.text.trim(),
          deliveryLocation: deliveryLocation,
        ),
      ),
    );
  }

  void _showSaveSheet() {
    final labelCtrl = TextEditingController(
      text: widget.prefillType == 'home'
          ? 'Domicile'
          : widget.prefillType == 'work'
              ? 'Travail'
              : '',
    );
    String selectedType = widget.prefillType ?? 'custom';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Enregistrer l\'adresse',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in ['home', 'work', 'custom'])
                    ChoiceChip(
                      label: Text(t == 'home'
                          ? 'Domicile'
                          : t == 'work'
                              ? 'Travail'
                              : 'Personnalisé'),
                      selected: selectedType == t,
                      selectedColor: Colors.orange.shade100,
                      onSelected: (v) {
                        if (v) {
                          setModal(() => selectedType = t);
                          if (t == 'home') labelCtrl.text = 'Domicile';
                          if (t == 'work') labelCtrl.text = 'Travail';
                          if (t == 'custom') labelCtrl.clear();
                        }
                      },
                    ),
                ],
              ),
              if (selectedType == 'custom') ...[
                const SizedBox(height: 12),
                _Input(labelCtrl, 'Nom de l\'adresse (ex: Chez maman)',
                    Icons.label_outline),
              ],
              const SizedBox(height: 12),
              _Input(
                  _nameCtrl, 'Nom du contact (optionnel)', Icons.person_outlined),
              const SizedBox(height: 10),
              _PhoneInput(_phoneCtrl),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _saveAddress(selectedType, labelCtrl.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                child: const Text('Enregistrer',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAddress(String type, String label) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final addrName = _address.isNotEmpty ? _address : 'Position sélectionnée';
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedAddresses');

      if (type == 'home' || type == 'work') {
        final existing =
            await col.where('type', isEqualTo: type).limit(1).get();
        final docData = {
          'address': addrName,
          'lat': _marker.latitude,
          'lng': _marker.longitude,
          'phone': _phoneCtrl.text.trim(),
          'contactName': _nameCtrl.text.trim(),
        };
        if (existing.docs.isNotEmpty) {
          await existing.docs.first.reference
              .update({...docData, 'updatedAt': FieldValue.serverTimestamp()});
        } else {
          await col.add({
            'type': type,
            'label': type == 'home' ? 'Domicile' : 'Travail',
            ...docData,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await col.add({
          'type': 'custom',
          'label': label.isNotEmpty ? label : addrName,
          'address': addrName,
          'lat': _marker.latitude,
          'lng': _marker.longitude,
          'phone': _phoneCtrl.text.trim(),
          'contactName': _nameCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Adresse enregistrée !'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de l\'enregistrement.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canConfirm = _address.isNotEmpty && !_geocoding;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── CARTE (55% de l'écran) ──────────────────────────────────────
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      const CameraPosition(target: _cotonou, zoom: 13),
                  markers: {
                    Marker(
                      markerId: const MarkerId('delivery'),
                      position: _marker,
                      draggable: true,
                      onDragEnd: (ll) async {
                        setState(() => _marker = ll);
                        _recalc(ll);
                        await _reverseGeocode(ll);
                      },
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen),
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('zone'),
                      center: _marker,
                      radius: 150,
                      fillColor: Colors.orange.withValues(alpha: 0.08),
                      strokeColor: Colors.orange.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (c) {
                    if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
                    setState(() => _mapReady = true);
                  },
                  onTap: (ll) async {
                    setState(() {
                      _marker = ll;
                      _showResults = false;
                    });
                    _recalc(ll);
                    await _reverseGeocode(ll);
                  },
                ),

                // Bouton retour
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: _MapBtn(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black87, size: 20),
                    onTap: () => Navigator.pop(context),
                  ),
                ),

                // Bouton GPS
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _MapBtn(
                    icon: _locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.orange),
                          )
                        : const Icon(Icons.my_location,
                            color: Colors.orange, size: 22),
                    onTap: _locating ? null : _getLocation,
                  ),
                ),

                // Indicateur géocodage
                if (_geocoding)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 60,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.orange),
                          ),
                          SizedBox(width: 8),
                          Text('Identification du lieu...',
                              style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── PANNEAU BAS (45% de l'écran) ───────────────────────────────
          Expanded(
            flex: 45,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, -3))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on,
                              color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sélectionnez l\'adresse',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Barre de recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.search,
                                color: Colors.black45, size: 20),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _onSearchChanged,
                              decoration: const InputDecoration(
                                hintText: 'Trouver une adresse',
                                hintStyle: TextStyle(
                                    fontSize: 14, color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (_searching)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.orange),
                              ),
                            )
                          else if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Colors.grey),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _results = [];
                                _showResults = false;
                                _sessionToken = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Adresse sélectionnée (chip)
                  if (_address.isNotEmpty && !_showResults)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _address,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _address = '';
                                _searchCtrl.clear();
                              }),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.black38),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Erreur GPS
                  if (_gpsError.isNotEmpty && !_geocoding)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      child: Text(_gpsError,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.deepOrange)),
                    ),

                  // Liste : prédictions OU adresses récentes
                  Expanded(
                    child: _showResults
                        ? _PredictionsList(
                            results: _results,
                            onSelect: _selectResult,
                          )
                        : _RecentList(
                            items: _recentAddresses,
                            onSelect: (addr) async {
                              final lat = addr['lat'] as double?;
                              final lng = addr['lng'] as double?;
                              final address =
                                  addr['address'] as String? ?? '';
                              if (lat != null && lng != null) {
                                final ll = LatLng(lat, lng);
                                setState(() {
                                  _marker = ll;
                                  _address = address;
                                  _searchCtrl.text = address;
                                });
                                _recalc(ll);
                                await _animateCamera(ll);
                              }
                            },
                          ),
                  ),

                  // Bouton confirmer
                  if (canConfirm)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          16, 8, 16, bottomPad > 0 ? bottomPad : 16),
                      child: ElevatedButton(
                        onPressed: _onConfirmTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                          elevation: 2,
                        ),
                        child: Text(
                          widget.totalAmount != null
                              ? 'Confirmer l\'adresse et passer aux détails'
                              : 'Confirmer l\'adresse',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Liste prédictions ─────────────────────────────────────────────────────────
// Affiche texte principal + secondaire comme préconisé par la documentation
// Places API (New) — structuredFormat.mainText / structuredFormat.secondaryText

class _PredictionsList extends StatelessWidget {
  final List<LieuSuggestion> results;
  final Future<void> Function(LieuSuggestion result) onSelect;

  const _PredictionsList({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: results.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (_, i) {
        final r = results[i];
        final titleText =
            r.titre.isNotEmpty ? r.titre : r.adresseComplete.split(',').first.trim();
        final subtitleText =
            r.sousTitre.isNotEmpty ? r.sousTitre : null;
        final distKm = r.distanceKm;

        return InkWell(
          onTap: () => onSelect(r),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.orange, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitleText != null && subtitleText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (distKm != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      distKm < 1
                          ? '${(distKm * 1000).round()} m'
                          : '${distKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Liste adresses récentes ───────────────────────────────────────────────────

class _RecentList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onSelect;

  const _RecentList({required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (_, i) {
        final item = items[i];
        final address = item['address'] as String? ?? '';
        // Séparer nom du lieu et reste de l'adresse
        final parts = address.split(',');
        final title = parts.first.trim();
        final subtitle =
            parts.length > 1 ? parts.skip(1).join(',').trim() : null;

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Icon(Icons.history, color: Colors.grey.shade500, size: 18),
          title: Text(title,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: subtitle != null && subtitle.isNotEmpty
              ? Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
              : null,
          onTap: () => onSelect(item),
        );
      },
    );
  }
}

// ── Bouton carte rond ─────────────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;

  const _MapBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2))
            ],
          ),
          child: Center(child: icon),
        ),
      );
}

// ── Champ texte générique ─────────────────────────────────────────────────────

class _Input extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;

  const _Input(this.ctrl, this.hint, this.icon);

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: Icon(icon, size: 18, color: Colors.black54),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      );
}

// ── Champ téléphone avec drapeau ──────────────────────────────────────────────

class _PhoneInput extends StatelessWidget {
  final TextEditingController ctrl;

  const _PhoneInput(this.ctrl);

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          hintText: '+229',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇧🇯', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('+229',
                    style: TextStyle(
                        color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      );
}
