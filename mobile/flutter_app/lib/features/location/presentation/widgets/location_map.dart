import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/current_location.dart';

class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    required this.location,
    this.height = 154,
    this.onLocate,
    this.showLocateButton = false,
  });

  final CurrentLocation? location;
  final double height;
  final VoidCallback? onLocate;
  final bool showLocateButton;

  static const _casablanca = LatLng(33.5899, -7.6039);

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final _controller = MapController();

  LatLng get _center {
    final location = widget.location;
    if (location == null) return LocationMap._casablanca;
    return LatLng(location.latitude, location.longitude);
  }

  @override
  void didUpdateWidget(covariant LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != null && widget.location != oldWidget.location) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(_center, 15);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: location == null ? 12 : 15,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.aman',
                ),
                if (location != null) ...[
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center,
                        radius: location.accuracyMeters.clamp(10, 500),
                        useRadiusInMeter: true,
                        color: AppColors.orange.withValues(alpha: 0.12),
                        borderColor: AppColors.orange.withValues(alpha: 0.45),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        width: 42,
                        height: 48,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.orange,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                ],
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomRight,
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                      textStyle: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 9,
              bottom: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  child: Text(
                    location?.address ?? 'Map preview · waiting for location',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showLocateButton)
              Positioned(
                right: 9,
                bottom: 9,
                child: IconButton.filled(
                  tooltip: 'Use my current location',
                  onPressed: widget.onLocate,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.orange,
                  ),
                  icon: const Icon(Icons.my_location),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
