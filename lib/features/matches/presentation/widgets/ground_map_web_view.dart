import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/maps_config.dart';
import '../../../../data/services/google_maps_location_service.dart';

/// Interactive Google Map (JavaScript API) — avoids native platform-view registration.
class GroundMapWebView extends StatefulWidget {
  const GroundMapWebView({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onPinMoved,
  });

  final double latitude;
  final double longitude;
  final ValueChanged<GeoCoords> onPinMoved;

  @override
  State<GroundMapWebView> createState() => GroundMapWebViewState();
}

class GroundMapWebViewState extends State<GroundMapWebView> {
  WebViewController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initController(widget.latitude, widget.longitude);
  }

  @override
  void didUpdateWidget(covariant GroundMapWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      movePin(widget.latitude, widget.longitude);
    }
  }

  void _initController(double lat, double lng) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A1A2E))
      ..addJavaScriptChannel(
        'MapChannel',
        onMessageReceived: (message) {
          try {
            final map = jsonDecode(message.message) as Map<String, dynamic>;
            final lat = (map['lat'] as num?)?.toDouble();
            final lng = (map['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return;
            widget.onPinMoved(GeoCoords(latitude: lat, longitude: lng));
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
        ),
      )
      ..loadHtmlString(_mapHtml(lat, lng), baseUrl: 'https://crickflow.app');

    setState(() {
      _controller = controller;
      _ready = false;
    });
  }

  Future<void> movePin(double lat, double lng) async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    await controller.runJavaScript('movePin($lat, $lng);');
  }

  static String _mapHtml(double lat, double lng) {
    final key = MapsConfig.apiKey;
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body, #map { height: 100%; width: 100%; margin: 0; padding: 0; }
  </style>
  <script src="https://maps.googleapis.com/maps/api/js?key=$key"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    let map, marker;
    function postPin(pos) {
      MapChannel.postMessage(JSON.stringify({ lat: pos.lat(), lng: pos.lng() }));
    }
    function initMap() {
      const center = { lat: $lat, lng: $lng };
      map = new google.maps.Map(document.getElementById('map'), {
        center: center,
        zoom: 16,
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: false,
      });
      marker = new google.maps.Marker({
        position: center,
        map: map,
        draggable: true,
      });
      map.addListener('click', (e) => {
        marker.setPosition(e.latLng);
        postPin(e.latLng);
      });
      marker.addListener('dragend', () => postPin(marker.getPosition()));
    }
    function movePin(lat, lng) {
      if (!map || !marker) return;
      const pos = new google.maps.LatLng(lat, lng);
      marker.setPosition(pos);
      map.panTo(pos);
    }
    initMap();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: controller),
        if (!_ready)
          const ColoredBox(
            color: Color(0xFF1A1A2E),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
