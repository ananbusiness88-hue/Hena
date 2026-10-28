import 'package:flutter/material.dart';

import '../../data/repositories/admin_drivers_repository.dart';

class DriverApplicationsPanel extends StatefulWidget {
  const DriverApplicationsPanel({
    super.key,
    required this.repository,
  });

  final AdminDriversRepository repository;

  @override
  State<DriverApplicationsPanel> createState() =>
      _DriverApplicationsPanelState();
}

class _DriverApplicationsPanelState
    extends State<DriverApplicationsPanel> {
  bool _loading = true;
  final Set<String> _processing = <String>{};

  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _loading = true;
    });

    try {
      final applications =
          await widget.repository.getPendingDriverApplications();

      if (!mounted) return;

      setState(() {
        _applications = applications;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Failed to load driver applications: $error');
    }
  }

  Future<void> _reviewApplication({
    required Map<String, dynamic> application,
    required bool approve,
  }) async {
    final applicationId = application['id']?.toString();

    if (applicationId == null) {
      _showMessage('Invalid application id.');
      return;
    }

    if (_processing.contains(applicationId)) {
      return;
    }

    String? notes;

    if (!approve) {
      notes = await _showRejectDialog();

      if (notes == null) {
        return;
      }
    }

    setState(() {
      _processing.add(applicationId);
    });

    try {
      await widget.repository.reviewDriverApplication(
        applicationId: applicationId,
        approve: approve,
        notes: notes,
      );

      if (!mounted) return;

      _showMessage(
        approve
            ? 'Driver approved successfully.'
            : 'Driver application rejected.',
      );

      await _loadApplications();
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to review application: $error');
    } finally {
      if (mounted) {
        setState(() {
          _processing.remove(applicationId);
        });
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('REJECT DRIVER APPLICATION'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason / Notes',
              hintText: 'Optional rejection notes',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                controller.text.trim(),
              ),
              child: const Text('REJECT'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Unknown date';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_applications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadApplications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Color(0xFF00FF88),
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'NO PENDING DRIVER APPLICATIONS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'All driver applications have been reviewed.',
                style: TextStyle(
                  color: Colors.white38,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _applications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final application = _applications[index];
          final applicant =
              application['applicant'] as Map<String, dynamic>?;

          final applicationId =
              application['id']?.toString() ?? '';

          final name =
              applicant?['full_name']?.toString() ??
                  'Unknown Applicant';

          final phone =
              applicant?['phone']?.toString() ??
                  'No phone';

          final email =
              applicant?['email']?.toString() ??
                  'No email';

          final createdAt =
              _formatDate(application['created_at']);

          final processing =
              _processing.contains(applicationId);

          return Card(
            color: const Color(0xFF101610),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor:
                            Color(0xFF112516),
                        child: Icon(
                          Icons.local_shipping_outlined,
                          color: Color(0xFF00FF88),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$phone\n$email',
                              style: const TextStyle(
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PendingBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'APPLICATION DATE: $createdAt',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: processing
                              ? null
                              : () => _reviewApplication(
                                    application: application,
                                    approve: true,
                                  ),
                          icon: const Icon(
                            Icons.check_circle_outline,
                          ),
                          label: const Text('APPROVE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: processing
                              ? null
                              : () => _reviewApplication(
                                    application: application,
                                    approve: false,
                                  ),
                          icon: const Icon(
                            Icons.cancel_outlined,
                          ),
                          label: const Text('REJECT'),
                        ),
                      ),
                    ],
                  ),
                  if (processing) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.35),
        ),
      ),
      child: const Text(
        'PENDING',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
