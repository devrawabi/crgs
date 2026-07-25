import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import 'app_map_tile_layer.dart';
import 'map_pin_marker.dart';

class LocationMapPreview extends StatelessWidget {
  const LocationMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 160,
  });

  final double latitude;
  final double longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(latitude, longitude);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          const AppMapTileLayer(),
          MarkerLayer(
            markers: [
              buildMapPinMarker(
                point: center,
                style: MapPinStyle.brand,
                width: 30,
                height: 48,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
