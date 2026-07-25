import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

enum ExternalMapApp {
  googleMaps('Google Maps'),
  waze('Waze'),
  appleMaps('Apple Maps'),
  openStreetMap('OpenStreetMap');

  const ExternalMapApp(this.label);

  final String label;
}

abstract final class MapLauncher {
  static bool hasValidCoordinates(double lat, double lng) => lat != 0 && lng != 0;

  static Uri uriFor(
    ExternalMapApp app,
    double lat,
    double lng, {
    String? label,
  }) {
    final encodedLabel = label != null && label.isNotEmpty
        ? Uri.encodeComponent(label)
        : '$lat,$lng';

    return switch (app) {
      ExternalMapApp.googleMaps => Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        ),
      ExternalMapApp.waze => Uri.parse(
          'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
        ),
      ExternalMapApp.appleMaps => Uri.parse(
          'https://maps.apple.com/?ll=$lat,$lng&q=$encodedLabel',
        ),
      ExternalMapApp.openStreetMap => Uri.parse(
          'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng',
        ),
    };
  }

  static Future<void> open({
    required ExternalMapApp app,
    required double lat,
    required double lng,
    String? label,
  }) async {
    final uri = uriFor(app, lat, lng, label: label);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static List<ExternalMapApp> availableApps() {
    if (!kIsWeb && Platform.isIOS) {
      return ExternalMapApp.values;
    }
    return ExternalMapApp.values
        .where((app) => app != ExternalMapApp.appleMaps)
        .toList();
  }

  static Future<void> showMapPicker(
    BuildContext context, {
    required double lat,
    required double lng,
    String? label,
  }) {
    final theme = ShadTheme.of(context);
    final apps = availableApps();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Open in Maps',
                  style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              for (final app in apps)
                ListTile(
                  title: Text(app.label),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    open(app: app, lat: lat, lng: lng, label: label);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
