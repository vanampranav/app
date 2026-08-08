import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/features/challenge/challenge_dev_flags.dart';
import 'package:elefit_app/services/fitdays_service.dart';
import 'package:elefit_app/services/member_service.dart';
import 'package:elefit_app/models/member_model.dart';
import 'package:elefit_app/models/device_model.dart';

/// DEV-ONLY: reads the latest measurement from the connected EleFit body-fat
/// scale and hands it back via [onReading], pinned to the ACCOUNT OWNER's
/// profile (the primary member = the challenge participant) so body fat is
/// computed for the right person — never a switched-in family member.
///
/// Renders nothing when [kChallengeScaleSyncEnabled] is false, so the whole
/// feature toggles off with that single flag.
class ChallengeScaleSyncButton extends StatefulWidget {
  final void Function(WeightMeasurement reading) onReading;

  const ChallengeScaleSyncButton({Key? key, required this.onReading})
      : super(key: key);

  @override
  State<ChallengeScaleSyncButton> createState() =>
      _ChallengeScaleSyncButtonState();
}

class _ChallengeScaleSyncButtonState extends State<ChallengeScaleSyncButton> {
  final FitDaysService _fitDays = FitDaysService();
  StreamSubscription<WeightMeasurement>? _sub;
  Timer? _timeout;
  bool _waiting = false;

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _waiting = true);

    // Pin the BIA calculation to the account owner (the primary member), so the
    // body-fat % is for the challenge participant, not a switched-in family member.
    try {
      final members = await MemberService().getMembers();
      final owner =
          members.isNotEmpty ? members.first : await MemberService().ensureMemberExists();
      await _fitDays.initializeSDK(
        age: owner.age,
        height: owner.heightCm,
        sex: owner.gender.sdkSexType,
      );
    } catch (_) {
      // BIA falls back to a default profile if this fails; still usable.
    }

    // If the scale is already streaming, take the latest reading immediately.
    final last = _fitDays.lastWeight;
    if (_fitDays.isScaleStreaming && last != null) {
      _finish(last);
      return;
    }

    // Otherwise wait for the next reading (user steps on the scale).
    _sub = _fitDays.weightDataStream.listen(_finish);
    _timeout = Timer(const Duration(seconds: 25), () {
      _sub?.cancel();
      if (!mounted) return;
      setState(() => _waiting = false);
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'No scale reading. Make sure your EleFit scale is connected, then step on it.'),
        backgroundColor: AppTheme.error,
      ));
    });
  }

  void _finish(WeightMeasurement m) {
    _sub?.cancel();
    _timeout?.cancel();
    if (!mounted) return;
    setState(() => _waiting = false);
    widget.onReading(m);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Synced from your EleFit scale.'),
      backgroundColor: AppTheme.lime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!kChallengeScaleSyncEnabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: OutlinedButton.icon(
        onPressed: _waiting ? null : _sync,
        icon: _waiting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.lime))
            : const Icon(Icons.monitor_weight_outlined, size: 18),
        label: Text(_waiting ? 'Waiting for scale…' : 'Sync from EleFit Scale (DEV)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.lime,
          side: BorderSide(color: AppTheme.lime.withValues(alpha: 0.5)),
          minimumSize: const Size.fromHeight(46),
        ),
      ),
    );
  }
}
