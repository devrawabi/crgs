import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/product_review_provider.dart';
import '../providers/visit_provider.dart';

/// Product feedback block for the Visit in Progress form.
class VisitProductFeedbackSection extends ConsumerStatefulWidget {
  const VisitProductFeedbackSection({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  ConsumerState<VisitProductFeedbackSection> createState() =>
      _VisitProductFeedbackSectionState();
}

class _VisitProductFeedbackSectionState
    extends ConsumerState<VisitProductFeedbackSection> {
  final _productController = TextEditingController();
  final _reasonController = TextEditingController();
  final _imagePicker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _productController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showImageSourceSheet() async {
    if (_isSubmitting) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: ShadTheme.of(context).colorScheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.camera, color: AppColors.brand),
                  title: const Text('Take photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(AppIcons.image, color: AppColors.brand),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearImage() {
    if (_isSubmitting) return;
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final productText = _productController.text.trim();
    if (productText.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Enter a product name or code')),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Enter product feedback details')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    final employeeCode = user?.employeeCode.trim() ?? '';
    if (employeeCode.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Employee code missing. Please log in again.'),
        ),
      );
      return;
    }

    final customer = ref.read(customerByIdProvider(widget.customerId));
    final visit = ref.read(visitProvider);
    final route = () {
      final visitRoute = visit?.route.trim() ?? '';
      if (visitRoute.isNotEmpty) return visitRoute;
      final routeId = customer?.routeId.trim() ?? '';
      if (routeId.isNotEmpty) return routeId;
      return customer?.routeName.trim() ?? '';
    }();

    if (route.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Customer route is missing')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(productReviewsRepositoryProvider).submitReview(
            employeeCode: employeeCode,
            route: route,
            customerCode: widget.customerId,
            customerName: widget.customerName,
            itemCode: productText,
            itemName: productText,
            reason: reason,
            imageBytes: _imageBytes,
            imageFileName: _imageName,
          );

      if (!mounted) return;
      setState(() {
        _productController.clear();
        _reasonController.clear();
        _imageBytes = null;
        _imageName = null;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Product feedback submitted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to submit feedback: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasImage = _imageBytes != null && _imageBytes!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                AppIcons.report,
                size: 16,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Product Feedback',
                    style: theme.textTheme.large.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Capture product review or item issues',
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppTextField(
          controller: _productController,
          label: 'Product',
          hint: 'Enter product name or code',
          prefixIcon: AppIcons.inventory,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _reasonController,
          label: 'Feedback',
          hint: 'Customer feedback about this product...',
          maxLines: 3,
          prefixIcon: AppIcons.note,
        ),
        const SizedBox(height: 12),
        Text(
          'Photo (optional)',
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (hasImage)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                child: Image.memory(
                  _imageBytes!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isSubmitting ? null : _clearImage,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        AppIcons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              if ((_imageName ?? '').trim().isNotEmpty)
                Positioned(
                  left: 8,
                  bottom: 8,
                  right: 48,
                  child: Text(
                    _imageName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          ShadButton.outline(
            onPressed: _isSubmitting ? null : _showImageSourceSheet,
            width: double.infinity,
            leading: const Icon(AppIcons.camera, size: 16),
            child: const Text('Add Photo'),
          ),
        if (hasImage) ...[
          const SizedBox(height: 8),
          ShadButton.outline(
            onPressed: _isSubmitting ? null : _showImageSourceSheet,
            width: double.infinity,
            leading: const Icon(AppIcons.image, size: 16),
            child: const Text('Replace Photo'),
          ),
        ],
        const SizedBox(height: 12),
        ShadButton(
          onPressed: _isSubmitting ? null : _submit,
          width: double.infinity,
          leading: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.upload, size: 16),
          child: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
        ),
      ],
    );
  }
}
