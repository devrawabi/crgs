import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/widgets/maps/interactive_location_map.dart';

Future<VisitLocation?> showVisitLocationPickerSheet(
  BuildContext context, {
  required double initialLatitude,
  required double initialLongitude,
  required String initialAddress,
}) {
  return showModalBottomSheet<VisitLocation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ShadTheme.of(context).colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _VisitLocationPickerSheet(
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      initialAddress: initialAddress,
    ),
  );
}

class _VisitLocationPickerSheet extends StatefulWidget {
  const _VisitLocationPickerSheet({
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialAddress,
  });

  final double initialLatitude;
  final double initialLongitude;
  final String initialAddress;

  @override
  State<_VisitLocationPickerSheet> createState() =>
      _VisitLocationPickerSheetState();
}

class _VisitLocationPickerSheetState extends State<_VisitLocationPickerSheet> {
  late double _latitude;
  late double _longitude;
  late String _address;
  bool _isLocating = false;
  bool _isResolvingAddress = false;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _address = widget.initialAddress;
  }

  Future<void> _resolveAddress(double latitude, double longitude) async {
    setState(() => _isResolvingAddress = true);
    final address = await LocationService.reverseGeocode(latitude, longitude);
    if (!mounted) return;
    setState(() {
      _address = address;
      _isResolvingAddress = false;
    });
  }

  Future<void> _onMapLocationChanged(LatLng point) async {
    setState(() {
      _latitude = point.latitude;
      _longitude = point.longitude;
    });
    await _resolveAddress(point.latitude, point.longitude);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final location = await LocationService.getCurrentVisitLocation();
    if (!mounted) return;

    if (location == null) {
      setState(() => _isLocating = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Unable to access current location')),
      );
      return;
    }

    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _address = location.address;
      _isLocating = false;
    });
  }

  void _confirm() {
    Navigator.pop(
      context,
      VisitLocation(
        latitude: _latitude,
        longitude: _longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.9;
    // Modal sheets skip bottom safe-area; pad for nav bar / gesture /
    // tablet taskbar (viewPadding) plus keyboard (viewInsets).
    final bottomPad =
        20 + media.viewInsets.bottom + media.viewPadding.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick Visit Location',
              style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the map to move the pin or use your current GPS location.',
              style: theme.textTheme.muted,
            ),
            const SizedBox(height: 16),
            InteractiveLocationMap(
              latitude: _latitude,
              longitude: _longitude,
              height: 260,
              isLocating: _isLocating,
              onLocationChanged: _onMapLocationChanged,
              onMyLocationPressed: _useCurrentLocation,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.locationPin,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isResolvingAddress
                        ? Text(
                            'Resolving address...',
                            style: theme.textTheme.muted,
                          )
                        : Text(
                            _address,
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ShadButton(
              onPressed: _confirm,
              width: double.infinity,
              leading: const Icon(AppIcons.check, size: 18),
              child: const Text('Confirm Location'),
            ),
          ],
        ),
      ),
    );
  }
}
