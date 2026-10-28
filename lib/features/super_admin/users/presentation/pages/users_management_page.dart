import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/admin_users_repository.dart';
import '../../domain/entities/admin_user_model.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  late final AdminUsersRepository _repository;

  bool _loading = true;
  String? _error;

  List<AdminUserModel> _users = [];

  /// Latest role application keyed by applicant_id.
  final Map<String, Map<String, dynamic>> _roleApplications = {};

  String _search = '';
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();

    _repository = AdminUsersRepository(Supabase.instance.client);

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.getUsers();

      final applicationRows = await Supabase.instance.client
          .from('role_applications')
          .select('id,applicant_id,requested_role,status,notes,created_at')
          .order('created_at', ascending: false);

      final latestApplications = <String, Map<String, dynamic>>{};

      for (final rawRow in applicationRows as List) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        final applicantId = row['applicant_id']?.toString();

        if (applicantId == null ||
            latestApplications.containsKey(applicantId)) {
          continue;
        }

        latestApplications[applicantId] = row;
      }

      if (!mounted) return;

      setState(() {
        _users = result;
        _roleApplications
          ..clear()
          ..addAll(latestApplications);
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

  List<AdminUserModel> get _filteredUsers {
    final query = _search.trim().toLowerCase();

    return _users.where((user) {
      final matchesSearch =
          query.isEmpty ||
          user.fullName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.phone.toLowerCase().contains(query);

      final matchesRole = _roleFilter == 'ALL' || user.role == _roleFilter;

      final matchesStatus =
          _statusFilter == 'ALL' ||
          (_statusFilter == 'ACTIVE' && user.isActive) ||
          (_statusFilter == 'INACTIVE' && !user.isActive);

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  Map<String, dynamic>? _applicationFor(AdminUserModel user) {
    return _roleApplications[user.id];
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFFC857);
      case 'store_owner':
        return const Color(0xFF00FF88);
      case 'driver':
        return const Color(0xFF55AAFF);
      case 'customer':
        return Colors.white70;
      default:
        return Colors.white38;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'store_owner':
        return 'STORE OWNER';
      case 'admin':
        return 'ADMIN';
      case 'driver':
        return 'DRIVER';
      case 'customer':
        return 'CUSTOMER';
      default:
        return role.toUpperCase();
    }
  }

  Color _applicationStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFC857);
      case 'approved':
        return const Color(0xFF00FF88);
      case 'rejected':
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.white38;
    }
  }

  String _applicationStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  String _applicationRoleLabel(String role) {
    switch (role) {
      case 'store_owner':
        return 'STORE OWNER';
      case 'driver':
        return 'DRIVER';
      default:
        return role.toUpperCase();
    }
  }

  Future<void> _approveApplication({
    required String applicationId,
    required String applicantName,
    required String requestedRole,
  }) async {
    debugPrint('USER MANAGEMENT: APPROVE START');
    debugPrint('USER MANAGEMENT: applicationId=$applicationId');
    debugPrint('USER MANAGEMENT: applicant=$applicantName');
    debugPrint('USER MANAGEMENT: requestedRole=$requestedRole');

    try {
      debugPrint('USER MANAGEMENT: calling admin_review_role_application...');

      await Supabase.instance.client.rpc(
        'admin_review_role_application',
        params: {
          'p_application_id': applicationId,
          'p_approve': true,
          'p_notes': null,
        },
      );

      debugPrint('USER MANAGEMENT: RPC SUCCESS');

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$applicantName approved as ${_applicationRoleLabel(requestedRole)}.',
          ),
        ),
      );

      debugPrint('USER MANAGEMENT: reloading users...');
      await _load();
      debugPrint('USER MANAGEMENT: APPROVE COMPLETE');
    } catch (error, stackTrace) {
      debugPrint('USER MANAGEMENT: APPROVE ERROR: $error');
      debugPrint('USER MANAGEMENT: APPROVE STACK: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approval failed: $error')));
    }
  }

  Future<void> _showUserDetails(AdminUserModel user) async {
    final application = _applicationFor(user);

    final applicationId = application?['id']?.toString();
    final requestedRole = application?['requested_role']?.toString();
    final requestStatus = application?['status']?.toString();

    final canApprove =
        applicationId != null &&
        requestedRole != null &&
        requestStatus == 'pending';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D130D),
          title: Text(
            user.fullName,
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'ID', value: user.id),
                _DetailRow(label: 'EMAIL', value: user.email),
                _DetailRow(label: 'PHONE', value: user.phone),
                _DetailRow(
                  label: 'ROLE',
                  value: _roleLabel(user.role),
                  valueColor: _roleColor(user.role),
                ),
                _DetailRow(
                  label: 'STATUS',
                  value: user.isActive ? 'ACTIVE' : 'INACTIVE',
                  valueColor: user.isActive
                      ? const Color(0xFF00FF88)
                      : Colors.redAccent,
                ),
                if (application != null) ...[
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: 'REQUEST',
                    value: _applicationRoleLabel(requestedRole ?? ''),
                    valueColor: _roleColor(requestedRole ?? ''),
                  ),
                  _DetailRow(
                    label: 'REQUEST STATE',
                    value: _applicationStatusLabel(requestStatus ?? ''),
                    valueColor: _applicationStatusColor(requestStatus ?? ''),
                  ),
                ],
                _DetailRow(
                  label: 'CREATED',
                  value: user.createdAt.toLocal().toString(),
                ),
              ],
            ),
          ),
          actions: [
            if (canApprove)
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  await _approveApplication(
                    applicationId: applicationId,
                    applicantName: user.fullName,
                    requestedRole: requestedRole,
                  );
                },
                icon: const Icon(Icons.check),
                label: Text('APPROVE ${_applicationRoleLabel(requestedRole)}'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFF080C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B110B),
        foregroundColor: Colors.white,
        title: const Text('Users Management'),
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
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'FAILED TO LOAD USERS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('RETRY')),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _search = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search name, email, phone...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFF101610),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _FilterButton(
                        label: 'ALL ROLES',
                        active: _roleFilter == 'ALL',
                        onTap: () => setState(() => _roleFilter = 'ALL'),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'CUSTOMERS',
                        active: _roleFilter == 'customer',
                        onTap: () => setState(() => _roleFilter = 'customer'),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'STORE OWNERS',
                        active: _roleFilter == 'store_owner',
                        onTap: () =>
                            setState(() => _roleFilter = 'store_owner'),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'DRIVERS',
                        active: _roleFilter == 'driver',
                        onTap: () => setState(() => _roleFilter = 'driver'),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'ADMINS',
                        active: _roleFilter == 'admin',
                        onTap: () => setState(() => _roleFilter = 'admin'),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'ACTIVE',
                        active: _statusFilter == 'ACTIVE',
                        onTap: () => setState(() => _statusFilter = 'ACTIVE'),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'INACTIVE',
                        active: _statusFilter == 'INACTIVE',
                        onTap: () => setState(() => _statusFilter = 'INACTIVE'),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'RESET',
                        active: false,
                        onTap: () => setState(() {
                          _roleFilter = 'ALL';
                          _statusFilter = 'ALL';
                          _search = '';
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        '${users.length} USERS',
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: users.isEmpty
                      ? const Center(
                          child: Text(
                            'NO USERS MATCH THE CURRENT FILTER',
                            style: TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final application = _applicationFor(user);

                            final requestedRole = application?['requested_role']
                                ?.toString();
                            final requestStatus = application?['status']
                                ?.toString();

                            return Card(
                              color: const Color(0xFF0F150F),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showUserDetails(user),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(
                                          0xFF142217,
                                        ),
                                        child: Text(
                                          _initials(user.fullName),
                                          style: const TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.fullName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              user.email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (requestedRole != null &&
                                                requestStatus != null) ...[
                                              const SizedBox(height: 7),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 3,
                                                children: [
                                                  const Text(
                                                    'REQUEST: ',
                                                    style: TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    _applicationRoleLabel(
                                                      requestedRole,
                                                    ),
                                                    style: TextStyle(
                                                      color: _roleColor(
                                                        requestedRole,
                                                      ),
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _applicationStatusLabel(
                                                      requestStatus,
                                                    ),
                                                    style: TextStyle(
                                                      color:
                                                          _applicationStatusColor(
                                                            requestStatus,
                                                          ),
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _roleLabel(user.role),
                                            style: TextStyle(
                                              color: _roleColor(user.role),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            user.isActive
                                                ? 'ACTIVE'
                                                : 'INACTIVE',
                                            style: TextStyle(
                                              color: user.isActive
                                                  ? const Color(0xFF00FF88)
                                                  : Colors.redAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.white24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
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

class _FilterButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? const Color(0xFF00FF88) : Colors.white60,
        side: BorderSide(
          color: active ? const Color(0xFF00FF88) : const Color(0xFF1F2A1F),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
