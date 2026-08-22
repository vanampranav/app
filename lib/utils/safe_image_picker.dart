import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:elefit_app/theme/app_theme.dart';

/// Picks an image and NEVER throws.
///
/// `image_picker` throws `PlatformException(camera_access_denied)` /
/// `photo_access_denied` when the user declines the permission — an uncaught
/// version of that is a hard crash (it fires right off a user tap). This wraps
/// the call: on a denied permission or any picker error it shows a helpful
/// SnackBar and returns `null` instead of crashing.
Future<XFile?> safePickImage(
  BuildContext context,
  ImagePicker picker, {
  required ImageSource source,
  int? imageQuality,
  double? maxWidth,
}) async {
  try {
    return await picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
  } catch (e) {
    if (!context.mounted) return null;
    final bool isCamera = source == ImageSource.camera;
    final bool denied = e is PlatformException &&
        (e.code == 'camera_access_denied' || e.code == 'photo_access_denied');
    final String what = isCamera ? 'camera' : 'photos';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(denied
          ? "EleFit doesn't have permission to use your $what. Enable it in Settings to add a photo."
          : 'Could not open the ${isCamera ? 'camera' : 'photo library'}. Please try again.'),
      backgroundColor: AppTheme.error,
    ));
    return null;
  }
}
