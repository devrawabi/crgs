import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';

/// Map pin images loaded from the network (Leaflet color markers CDN).
abstract final class MapPinAssets {
  static const brand =
      'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png';
  static const active =
      'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png';
  static const defaultStop =
      'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png';
  static const shadow =
      'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-shadow.png';
}

enum MapPinStyle { brand, active, stop }

class MapPinImage extends StatelessWidget {
  const MapPinImage({
    super.key,
    required this.style,
    this.width = 28,
    this.height = 46,
    this.showShadow = true,
  });

  final MapPinStyle style;
  final double width;
  final double height;
  final bool showShadow;

  String get _url => switch (style) {
        MapPinStyle.brand => MapPinAssets.brand,
        MapPinStyle.active => MapPinAssets.active,
        MapPinStyle.stop => MapPinAssets.defaultStop,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          if (showShadow)
            Positioned(
              bottom: 0,
              child: CachedNetworkImage(
                imageUrl: MapPinAssets.shadow,
                width: width * 1.35,
                height: height * 0.28,
                fit: BoxFit.contain,
                memCacheWidth: 64,
                memCacheHeight: 32,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          CachedNetworkImage(
            imageUrl: _url,
            width: width,
            height: height,
            fit: BoxFit.contain,
            memCacheWidth: 56,
            memCacheHeight: 92,
            placeholder: (_, _) => SizedBox(
              width: width,
              height: height,
              child: Icon(
                AppIcons.locationPin,
                size: width * 0.85,
                color: AppColors.brand,
              ),
            ),
            errorWidget: (_, _, _) => Icon(
              AppIcons.locationPin,
              size: width * 0.85,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

Marker buildMapPinMarker({
  required LatLng point,
  MapPinStyle style = MapPinStyle.brand,
  double width = 28,
  double height = 46,
  bool showShadow = true,
}) {
  return Marker(
    point: point,
    width: width,
    height: height,
    alignment: Alignment.bottomCenter,
    child: MapPinImage(
      style: style,
      width: width,
      height: height,
      showShadow: showShadow,
    ),
  );
}
