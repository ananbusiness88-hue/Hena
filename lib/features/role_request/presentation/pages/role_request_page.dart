import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/role_request_repository.dart';

class RoleRequestPage extends StatefulWidget {
  const RoleRequestPage({super.key, this.initialRole});

  final String? initialRole;

  @override
  State<RoleRequestPage> createState() => _RoleRequestPageState();
}

class _RoleRequestPageState extends State<RoleRequestPage> {
  late final RoleRequestRepository _repository;

  bool _loading = true;
  bool _submitting = false;

  late String _selectedRole;

  String? _storeOwnerStatus;
  String? _driverStatus;
  String? _error;

  @override
  void initState() {
    super.initState();

    _selectedRole = widget.initialRole ?? 'store_owner';
    _repository = RoleRequestRepository(Supabase.instance.client);

    _loadStatuses();
  }

  String? get _selectedStatus {
    if (_selectedRole == 'driver') {
      return _driverStatus;
    }

    return _storeOwnerStatus;
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getCurrentStoreOwnerApplicationStatus(),
        _repository.getCurrentDriverApplicationStatus(),
      ]);

      if (!mounted) return;

      setState(() {
        _storeOwnerStatus = results[0];
        _driverStatus = results[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    final status = _selectedStatus;

    if (status == 'pending' || status == 'approved') {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _repository.requestRole(_selectedRole);

      if (!mounted) return;

      setState(() {
        if (_selectedRole == 'driver') {
          _driverStatus = 'pending';
        } else {
          _storeOwnerStatus = 'pending';
        }

        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedRole == 'driver'
                ? 'DRIVER application submitted successfully.'
                : 'STORE OWNER application submitted successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _submitting = false;
      });
    }
  }

  void _selectRole(String role) {
    if (_submitting) return;

    setState(() {
      _selectedRole = role;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _selectedStatus;

    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    final isDriver = _selectedRole == 'driver';
    final directRole = widget.initialRole != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          directRole
              ? (isDriver
                    ? '\u{0627}\u{0644}\u{0627}\u{0646}\u{0636}\u{0645}\u{0627}\u{0645} \u{0643}\u{0633}\u{0627}\u{0626}\u{0642}'
                    : '\u{0627}\u{0644}\u{0627}\u{0646}\u{0636}\u{0645}\u{0627}\u{0645} \u{0643}\u{0635}\u{0627}\u{062D}\u{0628} \u{0645}\u{062D}\u{0644}')
              : 'Role & Access',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatuses,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (!directRole) ...[
                    const Text(
                      'CHOOSE YOUR ROLE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose how you want to participate in the Hena platform.',
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleOptionCard(
                            selected: _selectedRole == 'store_owner',
                            icon: Icons.storefront_outlined,
                            title: 'STORE OWNER',
                            description: 'Manage a Hena store',
                            onTap: () => _selectRole('store_owner'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleOptionCard(
                            selected: _selectedRole == 'driver',
                            icon: Icons.local_shipping_outlined,
                            title: 'DRIVER',
                            description: 'Deliver Hena orders',
                            onTap: () => _selectRole('driver'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (isApproved)
                    _StatusCard(
                      title: isDriver
                          ? 'DRIVER APPROVED'
                          : 'STORE OWNER APPROVED',
                      message: isDriver
                          ? 'Your account has DRIVER access.'
                          : 'Your account has STORE OWNER access.',
                      color: Colors.green,
                    )
                  else if (isPending)
                    _StatusCard(
                      title: isDriver
                          ? 'DRIVER APPLICATION PENDING'
                          : 'APPLICATION PENDING',
                      message: isDriver
                          ? 'Your driver application is waiting for Super Admin review.'
                          : 'Your application is waiting for Super Admin review.',
                      color: Colors.orange,
                    )
                  else if (isRejected)
                    _StatusCard(
                      title: 'APPLICATION REJECTED',
                      message: isDriver
                          ? 'Your previous driver application was rejected. '
                                'You may submit a new request.'
                          : 'Your previous store owner application was rejected. '
                                'You may submit a new request.',
                      color: Colors.redAccent,
                    )
                  else
                    _StatusCard(
                      title: 'CUSTOMER',
                      message: isDriver
                          ? 'You are currently a Customer. '
                                'Submit a request to become a Driver.'
                          : 'You are currently a Customer. '
                                'Submit a request to become a Store Owner.',
                      color: Colors.blueGrey,
                    ),

                  const SizedBox(height: 24),

                  if (isDriver) ...[
                    _ContactCard(phone: '01002026939'),
                    const SizedBox(height: 24),
                  ],

                  if (!isPending && !isApproved)
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submitRequest,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isDriver
                                    ? Icons.local_shipping_outlined
                                    : Icons.storefront_outlined,
                              ),
                        label: Text(
                          isRejected
                              ? 'REQUEST AGAIN'
                              : isDriver
                              ? 'REQUEST DRIVER'
                              : 'REQUEST STORE OWNER',
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: selected ? const Color(0xFF102016) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? const Color(0xFF00FF88) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 34,
                color: selected ? const Color(0xFF00FF88) : Colors.white70,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.phone_outlined, color: Color(0xFF00FF88)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTACT HENA ADMINISTRATION',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'To complete the driver onboarding process, '
                    'please contact the administration:',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    phone,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String message;
  final Color color;

  const _StatusCard({
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
