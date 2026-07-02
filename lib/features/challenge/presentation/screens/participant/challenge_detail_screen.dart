import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/participant_enrollment_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_challenge_dashboard_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/challenge_package_selection_screen.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_challenge_detail_provider.dart';
import 'package:elefit_app/services/analytics_service.dart';

class ChallengeDetailScreen extends StatelessWidget {
  final String challengeId;

  const ChallengeDetailScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.id ?? '';

    return ChangeNotifierProvider(
      create: (ctx) => ParticipantChallengeDetailProvider(
        challengeId: challengeId,
        userId: userId,
        challengeRepository: ctx.read<ChallengeRepository>(),
        participantRepository: ctx.read<ChallengeParticipantRepository>(),
        enrollmentService: ctx.read<ParticipantEnrollmentService>(),
      ),
      child: const _ChallengeDetailContent(),
    );
  }
}

class _ChallengeDetailContent extends StatefulWidget {
  const _ChallengeDetailContent({Key? key}) : super(key: key);

  @override
  State<_ChallengeDetailContent> createState() => _ChallengeDetailContentState();
}

class _ChallengeDetailContentState extends State<_ChallengeDetailContent> {
  bool _agreedToRules = false;
  final _nicknameController = TextEditingController();
  bool _viewLogged = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Consumer<ParticipantChallengeDetailProvider>(
      builder: (context, provider, _) {
        final challenge = provider.challenge;

        if (challenge != null && !_viewLogged) {
          _viewLogged = true;
          AnalyticsService.logChallengeViewed(challenge.id, challenge.title);
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: Text(challenge?.title ?? 'Challenge Details', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: provider.isLoading
              ? const EFLoadingStateView(message: 'Loading challenge details...')
              : provider.errorMessage != null
                  ? _buildErrorState(context, provider)
                  : challenge == null
                      ? const EFEmptyStateView(
                          title: 'Not Found',
                          message: 'Challenge not found.',
                          icon: Icons.search_off_rounded,
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMainCard(challenge, dateFormat),
                              const SizedBox(height: 32),
                              _buildSection('Description', challenge.description),
                              const SizedBox(height: 24),
                              _buildSection('Rules & Guidelines', challenge.rulesSummary),
                              const SizedBox(height: 24),
                              _buildSection('Prizes', challenge.prizeDescription, isAccent: true),
                              const SizedBox(height: 32),
                              _buildRequirements(challenge),
                              const SizedBox(height: 40),
                              if (provider.hasJoined)
                                _buildParticipationStatus(context, provider)
                              else
                                _buildJoinSection(context, provider, challenge),
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
        );
      },
    );
  }

  Widget _buildMainCard(Challenge challenge, DateFormat df) {
    return EFCard(
      child: Column(
        children: [
          _buildInfoRow(Icons.calendar_month_rounded, 'Challenge Period', 
              '${df.format(challenge.startDate)} - ${df.format(challenge.endDate)}'),
          const Divider(height: 32, color: Colors.white10),
          _buildInfoRow(Icons.timer_outlined, 'Registration Closes', df.format(challenge.registrationDeadline)),
          const Divider(height: 32, color: Colors.white10),
          Row(
            children: [
              Expanded(child: _buildInfoRow(Icons.payments_outlined, 'Fee', '\$${challenge.registrationFee.toStringAsFixed(0)}')),
              Expanded(child: _buildInfoRow(Icons.people_outline_rounded, 'Capacity', '${challenge.maxParticipants} max')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: AppTheme.lime),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
            const SizedBox(height: 2),
            Text(value, style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content, {bool isAccent = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAccent ? AppTheme.lime.withValues(alpha: 0.05) : AppTheme.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isAccent ? AppTheme.lime.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
          ),
          child: Text(
            content,
            style: AppTheme.bodyMD.copyWith(
              color: isAccent ? AppTheme.lime : AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirements(Challenge challenge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REQUIREMENTS', style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
        const SizedBox(height: 12),
        _buildRequirementItem('Baseline measurements & photos', challenge.baselineRequired),
        _buildRequirementItem('Final weight & photo for prizes', challenge.finalPhotoRequired),
      ],
    );
  }

  Widget _buildRequirementItem(String label, bool isRequired) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            isRequired ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isRequired ? AppTheme.lime : AppTheme.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label, style: AppTheme.bodyMD),
        ],
      ),
    );
  }

  Widget _buildParticipationStatus(BuildContext context, ParticipantChallengeDetailProvider provider) {
    final p = provider.participant!;
    String statusMsg = 'You are in this challenge!';
    Color statusColor = AppTheme.lime;

    if (p.status == ParticipantStatus.withdrawn) {
      statusMsg = 'You have withdrawn from this challenge.';
      statusColor = AppTheme.textTertiary;
    } else if (p.status == ParticipantStatus.disqualified) {
      statusMsg = 'Status: Disqualified';
      statusColor = AppTheme.error;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(Icons.verified_user_rounded, color: statusColor, size: 32),
              const SizedBox(height: 12),
              Text(statusMsg, style: AppTheme.headingSM.copyWith(color: statusColor)),
              const SizedBox(height: 4),
              Text('Status: ${p.status.toUpperCase()}', style: AppTheme.labelSM),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EFButton(
          label: 'Open Dashboard',
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => ParticipantChallengeDashboardScreen(challengeId: provider.challengeId))
          ),
        ),
      ],
    );
  }

  Widget _buildJoinSection(BuildContext context, ParticipantChallengeDetailProvider provider, Challenge challenge) {
    final isRegistrationOpen = challenge.status == ChallengeStatus.registrationOpen;
    final isDeadlinePassed = DateTime.now().isAfter(challenge.registrationDeadline);
    final canJoin = isRegistrationOpen && !isDeadlinePassed;

    if (!canJoin) {
      String msg = 'Registration is closed.';
      if (challenge.status == ChallengeStatus.draft) msg = 'Registration not started yet.';
      if (isDeadlinePassed) msg = 'Registration deadline has passed.';
      
      return Center(
        child: Text(msg, style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REGISTRATION', style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
        const SizedBox(height: 12),
        EFCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEADERBOARD NICKNAME', style: AppTheme.labelSM.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              const Text('This is how others will see you on the challenge leaderboard.', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicknameController,
                style: const TextStyle(color: Colors.white),
                maxLength: 20,
                decoration: InputDecoration(
                  hintText: 'Enter a fun nickname',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppTheme.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  counterStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _agreedToRules = !_agreedToRules),
          child: Row(
            children: [
              Checkbox(
                value: _agreedToRules,
                onChanged: (v) => setState(() => _agreedToRules = v ?? false),
                activeColor: AppTheme.lime,
                checkColor: Colors.black,
              ),
              const Expanded(
                child: Text(
                  'I agree to the challenge rules and submission guidelines.',
                  style: AppTheme.bodySM,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EFButton(
          label: provider.isJoining ? 'Joining...' : 'Join Challenge',
          onTap: (_agreedToRules && !provider.isJoining) ? () => _handleJoin(context, provider) : null,
          loading: provider.isJoining,
        ),
      ],
    );
  }

  Future<void> _handleJoin(BuildContext context, ParticipantChallengeDetailProvider provider) async {
    final nickname = _nicknameController.text.trim();
    
    // Validation
    if (nickname.isEmpty) {
      _showErrorSnackBar('Nickname is required.');
      return;
    }
    if (nickname.length < 2 || nickname.length > 20) {
      _showErrorSnackBar('Nickname must be between 2 and 20 characters.');
      return;
    }
    
    // Letters, numbers, spaces only
    if (!RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(nickname)) {
      _showErrorSnackBar('Only letters, numbers, and spaces are allowed in nicknames.');
      return;
    }

    // No emails (simple check for @)
    if (nickname.contains('@')) {
      _showErrorSnackBar('Email addresses are not allowed as nicknames.');
      return;
    }

    // No phone numbers (simple check for too many digits)
    if (RegExp(r'\d{7,}').hasMatch(nickname.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      _showErrorSnackBar('Phone numbers are not allowed as nicknames.');
      return;
    }

    AnalyticsService.logChallengeJoinStarted(provider.challengeId);
    
    // Navigate to Package Selection
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengePackageSelectionScreen(
          challengeId: provider.challengeId,
          onPackageSelected: (package) async {
            // After package is selected, complete enrollment
            await provider.joinChallenge(
              nickname: nickname,
              package: package,
            );
            
            if (context.mounted) {
              if (provider.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.error));
              } else {
                AnalyticsService.logChallengeJoinCompleted(provider.challengeId, package.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined challenge successfully! 🎉'), backgroundColor: AppTheme.lime));
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => ParticipantChallengeDashboardScreen(challengeId: provider.challengeId)),
                  (route) => route.isFirst,
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.error));
  }

  Widget _buildErrorState(BuildContext context, ParticipantChallengeDetailProvider provider) {
    return EFErrorView.map(
      provider.errorMessage!,
      screenName: 'ChallengeDetailScreen',
      featureName: 'ChallengeDiscovery',
      userId: provider.userId,
      onBack: () => Navigator.pop(context),
    );
  }
}
