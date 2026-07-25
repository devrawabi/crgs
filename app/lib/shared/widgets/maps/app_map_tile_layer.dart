import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Map tiles with English / Latin-script labels worldwide.
///
/// Standard OSM tiles (`tile.openstreetmap.org`) render place names in each
/// region's local language (Arabic in the Gulf, Devanagari in India, etc.).
/// Carto Voyager uses the same OSM data but renders readable Latin labels so
/// sales teams can read street and area names consistently.
abstract final class AppMapTiles {
  static const englishLabelsUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  static const englishLabelsSubdomains = ['a', 'b', 'c', 'd'];

  static const userAgentPackageName = 'com.crgs.app';
}

class AppMapTileLayer extends StatelessWidget {
  const AppMapTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: AppMapTiles.englishLabelsUrlTemplate,
      subdomains: AppMapTiles.englishLabelsSubdomains,
      userAgentPackageName: AppMapTiles.userAgentPackageName,
      retinaMode: RetinaMode.isHighDensity(context),
    );
  }
}
