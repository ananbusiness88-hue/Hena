import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/role_applications_repository.dart';
import '../../domain/entities/role_application_model.dart';

class RoleApplicationsPage extends StatefulWidget {
  const RoleApplicationsPage({super.key});

  @override
  State<RoleApplicationsPage> createState() => _RoleApplicationsPageState();
}

class _RoleApplicationsPageState extends State<RoleApplicationsPage> {
  late final RoleApplicationsRepository _repository;

  bool _loading = true;
  String? _error;
  List<RoleApplicationModel> _applications = [];

  @override
  void initState() {
    super.initState();

    _repository = RoleApplicationsRepository(Supabase.instance.client);

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getApplications();

      if (!mounted) return;

      setState(() {
        _applications = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _review(RoleApplicationModel application, bool approve) async {
    final notes = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(approve ? 'Approve Application' : 'Reject Application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(application.applicantName),
              const SizedBox(height: 6),
              Text('Requested role: ${application.requestedRole}'),
              const SizedBox(height: 16),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(approve ? 'APPROVE' : 'REJECT'),
            ),
          ],
        );
      },
    );

    final notesValue = notes.text.trim();
    notes.dispose();

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.reviewApplication(
        applicationId: application.id,
        approve: approve,
        notes: notesValue.isEmpty ? null : notesValue,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Application approved successfully.'
                : 'Application rejected successfully.',
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Review failed: $error')));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF00FF88);
      case 'rejected':
        return const Color(0xFFFF5C5C);
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B110B),
        foregroundColor: Colors.white,
        title: const Text('Role Applications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'FAILED TO LOAD APPLICATIONS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('RETRY')),
                  ],
                ),
              ),
            )
          : _applications.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 42,
                    color: Colors.white38,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'NO ROLE APPLICATIONS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'There are no applications yet.',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _applications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final application = _applications[index];
                final pending = application.status == 'pending';

                return Card(
                  color: const Color(0xFF0F150F),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF142217),
                              child: Text(
                                _initials(application.applicantName),
                                style: const TextStyle(
                                  color: Color(0xFF00FF88),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    application.applicantName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    application.applicantEmail ?? 'No email',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _statusColor(application.status),
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                application.status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(application.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'REQUESTED ROLE',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          application.requestedRole.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (application.applicantPhone != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            application.applicantPhone!,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                        if (application.notes != null &&
                            application.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            application.notes!,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                        if (pending) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _review(application, false),
                                  icon: const Icon(Icons.close),
                                  label: const Text('REJECT'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _review(application, true),
                                  icon: const Icon(Icons.check),
                                  label: const Text('APPROVE'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}
