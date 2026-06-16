// lib/pages/TrackingPage.dart
// Suivi en temps réel : carte Google Maps + info livreur + statut
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_page.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/active_order_notifier.dart';

class TrackingPage extends StatefulWidget {
  final String orderId;
  final int orderAmount;
  final String restaurantName;

  const TrackingPage({
    super.key,
    required this.orderId,
    required this.orderAmount,
    required this.restaurantName,
  });

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage>
    with SingleTickerProviderStateMixin {
  // Animation pulsation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Données commande
  String _status = 'pending';
  String _paymentStatus = 'pending';
  String _transactionId = '';
  String _driverName = '';
  String _driverPhone = '';
  String _driverWhatsapp = '';
  String _estimatedArrival = '';
  int _totalAmount = 0;
  int _foodAmount = 0;
  int _deliveryFee = 0;
  int _serviceFee = 0;
  String _vehicleType = '';
  String _vehicleBrand = '';
  String _vehicleColor = '';
  String _vehiclePlate = '';

  // Carte
  GoogleMapController? _mapCtrl;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _driverPos;
  LatLng? _restaurantPos;
  LatLng? _clientPos;
  bool _deliveredDialogShown = false;
  BitmapDescriptor? _driverBitmap;
  String _driverIconKey = '';

  StreamSubscription<DocumentSnapshot>? _orderSub;
  StreamSubscription<Position>? _positionSub;
  ActiveOrderNotifier? _orderNotifier;

  static const _cotonou = LatLng(6.365, 2.418);

  // Steps du stepper visuel — correspondent aux vrais statuts Firestore
  static const _statusSteps = ['pending', 'delivering', 'en_route', 'delivered'];
  Map<String, String> _statusLabels(AppLocalizations t) => {
    'pending':          t.statusPending,
    'paid':             t.statusPending,          // payé mais restaurant n'a pas encore commencé
    'preparing':        t.statusPreparing,         // restaurant prépare
    'ready_for_pickup': t.statusReady,             // prêt, livreur vient chercher
    'delivering':       t.statusConfirmed,         // livreur accepté → "Confirmée"
    'en_route':         t.statusEnRoute,           // livreur en chemin vers client
    'delivered':        t.statusDeliveredLabel,
  };
  static const _statusColors = {
    'pending':          Colors.orange,
    'paid':             Colors.orange,
    'preparing':        Colors.purple,
    'ready_for_pickup': Colors.teal,
    'delivering':       Colors.blue,
    'en_route':         Colors.indigo,
    'delivered':        Colors.green,
  };
  static const _statusIcons = {
    'pending':          Icons.hourglass_empty,
    'paid':             Icons.hourglass_empty,
    'preparing':        Icons.restaurant,
    'ready_for_pickup': Icons.delivery_dining,
    'delivering':       Icons.check_circle_outline,
    'en_route':         Icons.delivery_dining,
    'delivered':        Icons.celebration,
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(_onOrderData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _orderNotifier = context.read<ActiveOrderNotifier>();
      _orderNotifier?.setOrderPageOpen(true);
    });
  }

  @override
  void dispose() {
    _orderNotifier?.setOrderPageOpen(false);
    _pulseCtrl.dispose();
    _orderSub?.cancel();
    _stopLiveTracking();
    _mapCtrl?.dispose();
    super.dispose();
  }

  void _startLiveTracking() {
    if (_positionSub != null) return;
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'customerLiveLat': pos.latitude,
        'customerLiveLng': pos.longitude,
      });
    });
  }

  void _stopLiveTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'customerLiveLat': FieldValue.delete(), 'customerLiveLng': FieldValue.delete()})
        .catchError((_) {});
  }

  int _n(dynamic v, {int fb = 0}) {
    if (v == null) return fb;
    if (v is num) return v.toInt();
    if (v is String)
      return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? fb;
    return fb;
  }

  Future<BitmapDescriptor> _buildDriverIcon(String name, bool isEnRoute) async {
    final bgColor = isEnRoute ? const Color(0xFF185FA5) : const Color(0xFFE24B4A);
    const h = 34.0;
    const hPad = 10.0;
    final label = '🛵 ${name.isEmpty ? 'Livreur' : name}';
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + hPad * 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(h / 2)),
      Paint()..color = bgColor,
    );
    tp.paint(canvas, Offset(hPad, (h - tp.height) / 2));
    canvas.drawPath(
      Path()
        ..moveTo(w / 2 - 6, h)
        ..lineTo(w / 2 + 6, h)
        ..lineTo(w / 2, h + 8)
        ..close(),
      Paint()..color = bgColor,
    );
    final picture = recorder.endRecording();
    final img = await picture.toImage(w.ceil(), (h + 8).ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  void _onOrderData(DocumentSnapshot snap) async {
    if (!snap.exists || !mounted) return;
    final d = snap.data() as Map<String, dynamic>;

    final status = d['status'] as String? ?? 'pending';

    if (status == 'en_route' || status == 'ready_for_pickup') {
      _startLiveTracking();
    } else if (status == 'delivered') {
      _stopLiveTracking();
    }

    // Positions
    final dLat = (d['driverLat'] as num?)?.toDouble();
    final dLng = (d['driverLng'] as num?)?.toDouble();
    final rLat = (d['restaurantLat'] as num?)?.toDouble();
    final rLng = (d['restaurantLng'] as num?)?.toDouble();
    final cLat = (d['clientLat'] as num?)?.toDouble();
    final cLng = (d['clientLng'] as num?)?.toDouble();

    LatLng? newDriver;
    if (dLat != null && dLng != null && dLat != 0 && dLng != 0) {
      newDriver = LatLng(dLat, dLng);
    }
    if (rLat != null && rLng != null && rLat != 0) {
      _restaurantPos = LatLng(rLat, rLng);
    }
    if (cLat != null && cLng != null && cLat != 0) {
      _clientPos = LatLng(cLat, cLng);
    }

    // Icône livreur personnalisée (pill colorée — bleue en_route, rouge sinon)
    final driverName = d['driverName'] as String? ?? '';
    final isEnRoute = status == 'en_route';
    final iconKey = '${driverName}_$isEnRoute';
    if (newDriver != null && (_driverBitmap == null || _driverIconKey != iconKey)) {
      _driverBitmap = await _buildDriverIcon(driverName, isEnRoute);
      _driverIconKey = iconKey;
    }
    if (!mounted) return;

    // Marqueurs
    final markers = <Marker>{};
    if (_restaurantPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: _restaurantPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow:
            InfoWindow(title: widget.restaurantName, snippet: 'Restaurant'),
      ));
    }
    if (_clientPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('client'),
        position: _clientPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow:
            InfoWindow(title: AppLocalizations.of(context).yourAddress, snippet: AppLocalizations.of(context).destination),
      ));
    }
    if (newDriver != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: newDriver,
        icon: _driverBitmap ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: driverName.isEmpty ? AppLocalizations.of(context).driverLabel : driverName,
          snippet: AppLocalizations.of(context).enRouteBike,
        ),
      ));
    }

    final vehicle = d['driverVehicle'] as Map<String, dynamic>? ?? {};

    // Polyline restaurant → livreur → client (visible uniquement en_route)
    final polylines = <Polyline>{};
    if (status == 'en_route' && _restaurantPos != null && newDriver != null) {
      final pts = [_restaurantPos!, newDriver];
      if (_clientPos != null) pts.add(_clientPos!);
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        color: Colors.orange,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    setState(() {
      _status = status;
      _paymentStatus = d['paymentStatus'] as String? ?? 'pending';
      _transactionId = d['transactionId'] as String? ?? '';
      _driverName = d['driverName'] as String? ?? '';
      _driverPhone = d['driverPhone'] as String? ?? '';
      _driverWhatsapp = d['driverWhatsapp'] as String? ?? _driverPhone;
      _estimatedArrival = d['estimatedArrival'] as String? ?? '';
      _totalAmount = _n(d['totalAmount'], fb: widget.orderAmount);
      _foodAmount = _n(d['foodAmount']);
      _deliveryFee = _n(d['deliveryFee']);
      _serviceFee = _n(d['serviceFee']);
      _vehicleType = vehicle['type'] as String? ?? '';
      _vehicleBrand = vehicle['brand'] as String? ?? '';
      _vehicleColor = vehicle['color'] as String? ?? '';
      _vehiclePlate = vehicle['plateNumber'] as String? ?? '';
      _markers = markers;
      _polylines = polylines;
      if (newDriver != null) _driverPos = newDriver;
    });

    // Suivre le livreur en route
    if (newDriver != null && _mapCtrl != null && status == 'en_route') {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLng(newDriver));
    }

    // Dialog livraison effectuée
    if (status == 'delivered' && !_deliveredDialogShown) {
      _deliveredDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDeliveredDialog();
      });
    }
  }

  void _fitBounds() {
    final pts =
        [_driverPos, _restaurantPos, _clientPos].whereType<LatLng>().toList();
    if (_mapCtrl == null || pts.isEmpty) return;
    if (pts.length == 1) {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
        northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
      ),
      70,
    ));
  }

  static String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s\-\(\)+]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('229')) return '+$digits';
    return '+229$digits';
  }

  Future<void> _openWhatsApp(String phone) async {
    final formatted = _formatPhone(phone);
    if (formatted.isEmpty) return;
    final number = formatted.replaceAll('+', '');
    final msg = Uri.encodeComponent('Bonjour, je suis votre client allofoods.');
    final url = Uri.parse('https://wa.me/$number?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).whatsappNotAvailable)));
    }
  }

  Future<void> _callPhone(String phone) async {
    final formatted = _formatPhone(phone);
    if (formatted.isEmpty) return;
    final url = Uri.parse('tel:$formatted');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showDeliveredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).deliveryDone,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).thankyouOrdered(widget.restaurantName),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('${widget.orderAmount} FCFA',
              style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: Text(AppLocalizations.of(context).greatThanks,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final statusColor = _statusColors[_status] ?? Colors.orange;
    final statusLabel = _statusLabels(t)[_status] ?? _status;
    final statusIcon = _statusIcons[_status] ?? Icons.info_outline;
    // Mapper les statuts intermédiaires vers leur step dans le stepper visuel
    final String stepKey;
    if (_status == 'paid' || _status == 'preparing' || _status == 'ready_for_pickup') {
      stepKey = 'pending';   // en attente du livreur
    } else {
      stepKey = _status;
    }
    final stepIdx = _statusSteps.indexOf(stepKey);

    final initialCam = CameraPosition(
      target: _clientPos ?? _restaurantPos ?? _cotonou,
      zoom: 14,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.liveTracking,
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('Live',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
      body: Stack(children: [
        // Carte Google Maps
        GoogleMap(
          initialCameraPosition: initialCam,
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (ctrl) {
            _mapCtrl = ctrl;
            Future.delayed(const Duration(milliseconds: 600), _fitBounds);
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: false,
          mapToolbarEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
        ),

        // Bouton recentrer
        Positioned(
          top: 12,
          right: 56,
          child: GestureDetector(
            onTap: _fitBounds,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]),
              child: const Icon(Icons.center_focus_strong,
                  color: Colors.orange, size: 22),
            ),
          ),
        ),

        // Légende marqueurs
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _MapLegend('🍽️', t.restaurantLabel),
              const SizedBox(width: 8),
              _MapLegend('📍', t.mapLegendYou),
              const SizedBox(width: 8),
              _MapLegend('🛵', t.driverLabel),
            ]),
          ),
        ),

        // Panneau info draggable
        // snap:true + snapSizes pour que le panel se colle à des positions fixes
        // et ne flotte pas au milieu de la carte
        DraggableScrollableSheet(
          initialChildSize: 0.40,
          minChildSize: 0.14,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.14, 0.40, 0.92],
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4))
              ],
            ),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Badge statut
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.2))),
                  child: Row(children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                          scale: _status == 'en_route' ? _pulseAnim.value : 1.0,
                          child: child),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle),
                        child: Icon(statusIcon, color: statusColor, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(statusLabel,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  fontSize: 14)),
                          if (_status == 'en_route' && _estimatedArrival.isNotEmpty)
                            Text('${t.estimatedArrivalLabel} $_estimatedArrival',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                        ])),
                  ]),
                ),
                const SizedBox(height: 12),

                // Stepper
                _StatusStepper(currentStep: stepIdx < 0 ? 0 : stepIdx),
                const SizedBox(height: 16),

                // Infos livreur + véhicule
                if (_driverName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.shade100)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.delivery_dining,
                                  color: Colors.purple, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(_driverName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  Text(t.yourDriver,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                ])),
                          ]),
                          if (_vehicleType.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Column(children: [
                                _VehicleRow(t.vehicleLabel,
                                    '$_vehicleType $_vehicleBrand'),
                                if (_vehicleColor.isNotEmpty)
                                  _VehicleRow(t.colorLabel, _vehicleColor),
                                if (_vehiclePlate.isNotEmpty)
                                  _VehicleRow(t.plateLabel, _vehiclePlate),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            if (_driverWhatsapp.isNotEmpty)
                              Expanded(
                                  child: ElevatedButton.icon(
                                onPressed: () => _openWhatsApp(_driverWhatsapp),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                icon: const Icon(Icons.chat, size: 16),
                                label: const Text('WhatsApp',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              )),
                            if (_driverWhatsapp.isNotEmpty &&
                                _driverPhone.isNotEmpty)
                              const SizedBox(width: 10),
                            if (_driverPhone.isNotEmpty)
                              Expanded(
                                  child: OutlinedButton.icon(
                                onPressed: () => _callPhone(_driverPhone),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side:
                                        const BorderSide(color: Colors.orange),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                icon: const Icon(Icons.phone, size: 16),
                                label: Text(t.callDriver,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              )),
                          ]),
                          const SizedBox(height: 8),
                          // Chat in-app
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    orderId: widget.orderId,
                                    driverName: _driverName,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade50,
                                foregroundColor: Colors.orange,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                side: BorderSide(color: Colors.orange.shade200),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon:
                                  const Icon(Icons.message_outlined, size: 16),
                              label: Text(t.messagingLabel,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Restaurant
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade100)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.restaurant,
                          color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(widget.restaurantName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(t.restaurantLabel,
                              style:
                                  const TextStyle(color: Colors.grey, fontSize: 11)),
                        ])),
                  ]),
                ),
                const SizedBox(height: 12),

                // Récap paiement
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _paymentStatus == 'PAID'
                              ? Colors.green.shade200
                              : Colors.orange.shade200)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              _paymentStatus == 'PAID'
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: _paymentStatus == 'PAID'
                                  ? Colors.green
                                  : Colors.orange,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                              _paymentStatus == 'PAID'
                                  ? t.paymentConfirmedCheck
                                  : t.paymentPending,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _paymentStatus == 'PAID'
                                      ? Colors.green
                                      : Colors.orange)),
                        ]),
                        if (_transactionId.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('ID: $_transactionId',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontFamily: 'monospace')),
                        ],
                        const Divider(height: 16),
                        if (_foodAmount > 0) ...[
                          _PayRow(t.foodLabel, '$_foodAmount FCFA'),
                          _PayRow(t.deliveryLabel, '$_deliveryFee FCFA'),
                          _PayRow(t.serviceLabel, '$_serviceFee FCFA'),
                          const Divider(height: 10),
                        ],
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.total,
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold)),
                              Text('$_totalAmount FCFA',
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ]),
                      ]),
                ),
                const SizedBox(height: 12),
                Center(
                    child: Text(
                        'Commande #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId}',
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontFamily: 'monospace'))),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// Légende carte
class _MapLegend extends StatelessWidget {
  final String emoji, label;
  const _MapLegend(this.emoji, this.label);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
      ]);
}

// Ligne véhicule
class _VehicleRow extends StatelessWidget {
  final String label, value;
  const _VehicleRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
        ]),
      );
}

// Ligne paiement
class _PayRow extends StatelessWidget {
  final String label, value;
  const _PayRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      );
}

// Stepper statut
class _StatusStepper extends StatelessWidget {
  final int currentStep;
  const _StatusStepper({required this.currentStep});

  static const _steps = [
    {'label': 'Reéue', 'icon': Icons.receipt_outlined},
    {'label': 'Confirmée', 'icon': Icons.check_circle_outline},
    {'label': 'En route', 'icon': Icons.delivery_dining},
    {'label': 'Livrée', 'icon': Icons.celebration},
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final idx = i ~/ 2;
          return Expanded(
              child: Container(
                  height: 2,
                  color: idx < currentStep
                      ? Colors.orange
                      : Colors.grey.shade200));
        }
        final idx = i ~/ 2;
        final done = idx <= currentStep;
        final active = idx == currentStep;
        final color = done ? Colors.orange : Colors.grey.shade300;

        return Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: active ? 40 : 32,
            height: active ? 40 : 32,
            decoration: BoxDecoration(
                color: done ? color : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: active ? 2 : 1),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2)
                      ]
                    : []),
            child: Icon(_steps[idx]['icon'] as IconData,
                color: done ? Colors.white : Colors.grey.shade400,
                size: active ? 20 : 16),
          ),
          const SizedBox(height: 4),
          Text(_steps[idx]['label'] as String,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: done ? Colors.orange : Colors.grey)),
        ]);
      }),
    );
  }
}
