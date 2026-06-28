import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/models/admin_audit_log.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_audit_logs_provider.dart';

class AdminAuditLogsScreen extends StatelessWidget {
  final String challengeId;

  const AdminAuditLogsScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminAuditLogsProvider(
          challengeId: challengeId,
          auditService: ctx.read<AdminAuditService>(),
          userRepository: ctx.read<UserRepository>(),
        ),
        child: const _AdminAuditLogsContent(),
      ),
    );
  }
}

class _AdminAuditLogsContent extends StatelessWidget {
  const _AdminAuditLogsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Audit Logs', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Consumer<AdminAuditLogsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildFilterBar(context, provider),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
                    : provider.errorMessage != null
                        ? _buildErrorState(provider.errorMessage!)
                        : provider.logs.isEmpty
                            ? _buildEmptyState(provider.currentFilter)
                            : _buildLogsList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AdminAuditLogsProvider provider) {
    final filters = ['All', 'Challenge', 'Participant', 'Payment', 'Submission'];
    
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final filter = filters[i];
          final isSelected = provider.currentFilter == filter;
          
          return GestureDetector(
            onTap: () => provider.setFilter(filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.lime : AppTheme.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.lime : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogsList(BuildContext context, AdminAuditLogsProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final viewModel = provider.logs[i];
        return _AuditLogCard(viewModel: viewModel);
      },
    );
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Text(
        'No $filter logs found.',
        style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTheme.bodyMD.copyWith(color: AppTheme.error),
        ),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final AuditLogViewModel viewModel;

  const _AuditLogCard({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final log = viewModel.log;
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm:ss');
    
    return EFCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  log.action.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(color: AppTheme.lime, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                log.createdAt != null ? dateFormat.format(log.createdAt!) : 'N/A',
                style: AppTheme.labelSM.copyWith(fontSize: 10, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Admin: ${viewModel.adminName}',
            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ${log.targetCollection} (${log.targetId})',
            style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (log.reason != null && log.reason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('REASON:', style: AppTheme.labelSM.copyWith(fontSize: 9, color: AppTheme.textTertiary)),
            Text(
              log.reason!, 
              style: AppTheme.bodySM.copyWith(color: AppTheme.error.withValues(alpha: 0.8)),
            ),
          ],
          
          if (log.previousData != null || log.newData != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showDataDiff(context, log),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded, size: 14, color: AppTheme.lime),
                  const SizedBox(width: 4),
                  Text('VIEW DATA CHANGES', style: AppTheme.labelSM.copyWith(fontSize: 10, color: AppTheme.lime)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDataDiff(BuildContext context, AdminAuditLog log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DATA CHANGES', style: AppTheme.headingSM),
              const SizedBox(height: 20),
              if (log.previousData != null) ...[
                Text('BEFORE:', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
                const SizedBox(height: 8),
                _DataView(data: log.previousData!),
                const SizedBox(height: 24),
              ],
              if (log.newData != null) ...[
                Text('AFTER:', style: AppTheme.labelSM.copyWith(color: AppTheme.lime)),
                const SizedBox(height: 8),
                _DataView(data: log.newData!, isHighlighted: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DataView extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isHighlighted;

  const _DataView({required this.data, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.lime.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHighlighted ? AppTheme.lime.withValues(alpha: 0.2) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e.key}: ', style: AppTheme.labelSM.copyWith(fontSize: 10, color: AppTheme.textTertiary)),
              Expanded(child: Text('${e.value}', style: AppTheme.bodySM.copyWith(fontSize: 10))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
