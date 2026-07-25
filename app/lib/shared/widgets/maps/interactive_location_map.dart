import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import 'app_map_tile_layer.dart';
import 'map_pin_marker.dart';

class InteractiveLocationMap extends StatefulWidget {
  const InteractiveLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onLocationChanged,
    this.height = 180,
    this.interactive = true,
    this.onMyLocationPressed,
    this.onPickLocationPressed,
    this.isLocating = false,
  });

  final double latitude;
  final double longitude;
  final ValueChanged<LatLng> onLocationChanged;
  final double height;
  final bool interactive;
  final VoidCallback? onMyLocationPressed;
  final VoidCallback? onPickLocationPressed;
  final bool isLocating;

  @override
  State<InteractiveLocationMap> createState() => _InteractiveLocationMapState();
}

class _InteractiveLocationMapState extends State<InteractiveLocationMap> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(InteractiveLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _moveTo(LatLng(widget.latitude, widget.longitude));
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _moveTo(LatLng point) {
    final camera = _mapController.camera;
    _mapController.move(point, camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.latitude, widget.longitude);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              onTap: widget.interactive
                  ? (_, point) => widget.onLocationChanged(point)
                  : null,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              const AppMapTileLayer(),
              MarkerLayer(
                markers: [
                  buildMapPinMarker(
                    point: center,
                    style: MapPinStyle.brand,
                    width: 32,
                    height: 50,
                  ),
                ],
              ),
            ],
          ),
          if (widget.onPickLocationPressed != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: ShadButton(
                onPressed: widget.onPickLocationPressed,
                width: double.infinity,
                leading: const Icon(AppIcons.mapPin, size: 16),
                child: const Text('Pick Location'),
              ),
            ),
          if (widget.onMyLocationPressed != null)
            Positioned(
              right: 10,
              top: 10,
              child: Material(
                color: Colors.white,
                elevation: 4,
                shadowColor: AppColors.brand.withValues(alpha: 0.25),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.isLocating ? null : widget.onMyLocationPressed,
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      AppIcons.gps,
                      color: AppColors.brand,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
