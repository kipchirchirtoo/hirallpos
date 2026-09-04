import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

class AdminAuditLogsView extends StatefulWidget {
  final String organizationName;
  final String branchName;

  const AdminAuditLogsView({
    super.key,
    required this.organizationName,
    required this.branchName,
  });

  @override
  State<AdminAuditLogsView> createState() => _AdminAuditLogsViewState();
}

class _AdminAuditLogsViewState extends State<AdminAuditLogsView> {
  String _searchQuery = '';
  String _severityFilter = 'all';

  final List<Map<String, dynamic>> _auditLogs = [];

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'SECURITY_ALERT':
        return AppColors.danger;
      case 'WARNING':
        return const Color(0xFFF59E0B);
      case 'INFO':
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _auditLogs.where((l) {
      final matchesQuery = l['action'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l['staff'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l['details'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l['authorizedBy'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSeverity = _severityFilter == 'all' || l['severity'] == _severityFilter;
      return matchesQuery && matchesSeverity;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: const InputDecoration(
                  hintText: 'Search audit trail by event action, staff, reason, or supervisor...',
                  prefixIcon: Icon(LucideIcons.shieldAlert, size: 16),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _severityFilter,
                dropdownColor: AppColors.surface(context),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Severity Levels')),
                  DropdownMenuItem(value: 'SECURITY_ALERT', child: Text('🚨 Security Alerts & Kicks')),
                  DropdownMenuItem(value: 'WARNING', child: Text('⚠️ Warnings & Voids')),
                  DropdownMenuItem(value: 'INFO', child: Text('ℹ️ General Operations & Logins')),
                ],
                onChanged: (val) => setState(() => _severityFilter = val!),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Audit Trail exported to compliance log!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
              label: const Text('Export Audit Log'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Audit Trail Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shieldCheck, size: 48, color: AppColors.textMuted(context)),
                          const SizedBox(height: 12),
                          Text(
                            'No Security Audit Logs Recorded Yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Security events, supervisor overrides, cashier voids, and auth alerts will be logged here.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                      itemBuilder: (context, index) {
                  final log = filtered[index];
                  final color = _getSeverityColor(log['severity'] as String);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp & ID
                        SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['timestamp'] as String,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                              ),
                              Text(
                                log['id'] as String,
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),

                        // Severity Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            log['severity'] as String,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Event & Details
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    log['action'] as String,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.card(context),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      log['category'] as String,
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary(context)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                log['details'] as String,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Auth Sign-Off: ${log['authorizedBy']}',
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),

                        // Staff & Terminal
                        SizedBox(
                          width: 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                log['staff'] as String,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                log['terminal'] as String,
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
