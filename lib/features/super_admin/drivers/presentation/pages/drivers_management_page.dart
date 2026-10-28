import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/admin_drivers_repository.dart';
import '../widgets/driver_applications_panel.dart';

class DriversManagementPage extends StatefulWidget {
  const DriversManagementPage({super.key});

  @override
  State<DriversManagementPage> createState() => _DriversManagementPageState();
}

class _DriversManagementPageState extends State<DriversManagementPage> {
  late final AdminDriversRepository _repository;

  bool _loading = true;
  List<Map<String, dynamic>> _drivers = [];
  String _search = '';
  @override
  void initState() {
    super.initState();
    _repository = AdminDriversRepository(Supabase.instance.client);
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _loading = true);

    try {
      final drivers = await _repository.getDrivers();

      if (!mounted) return;

      setState(() {
        _drivers = drivers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Failed to load drivers: $error');
    }
  }

  List<Map<String, dynamic>> get _filteredDrivers {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _drivers;
    }

    return _drivers.where((driver) {
      final name = '${driver['full_name'] ?? ''}'.toLowerCase();
      final phone = '${driver['phone'] ?? ''}'.toLowerCase();
      final email = '${driver['email'] ?? ''}'.toLowerCase();

      return name.contains(query) ||
          phone.contains(query) ||
          email.contains(query);
    }).toList();
  }

  Future<void> _toggleDriverStatus(Map<String, dynamic> driver) async {
    final driverId = driver['id']?.toString();

    if (driverId == null) {
      _showMessage('Invalid driver id.');
      return;
    }

    final currentStatus = driver['is_active'] == true;
    final newStatus = !currentStatus;

    try {
      await _repository.updateDriverStatus(
        driverId: driverId,
        isActive: newStatus,
      );

      if (!mounted) return;

      await _loadDrivers();

      if (!mounted) return;

      _showMessage(
        newStatus
            ? 'Driver activated successfully.'
            : 'Driver suspended successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to update driver status: $error');
    }
  }

  Future<void> _openDriverReport(Map<String, dynamic> driver) async {
    final driverId = driver['id']?.toString();

    if (driverId == null) {
      _showMessage('Invalid driver id.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverReportPage(
          repository: _repository,
          driverId: driverId,
          driver: driver,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final drivers = _filteredDrivers;

    return Scaffold(
      backgroundColor: const Color(0xFF080C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D130D),
        foregroundColor: Colors.white,
        title: const Text('DRIVERS'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() => _search = value);
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search driver name, phone or email',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white54,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF101610),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: const Color(0xFF080C08),
                                appBar: AppBar(
                                  backgroundColor: const Color(0xFF0D130D),
                                  foregroundColor: Colors.white,
                                  title: const Text('DRIVER APPLICATIONS'),
                                ),
                                body: DriverApplicationsPanel(
                                  repository: _repository,
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('DRIVER APPLICATIONS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: drivers.isEmpty
                        ? const Center(
                            child: Text(
                              'No drivers found.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: drivers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final driver = drivers[index];
                              final name =
                                  '${driver['full_name'] ?? 'Unnamed Driver'}';
                              final phone = '${driver['phone'] ?? 'No phone'}';
                              final email = '${driver['email'] ?? 'No email'}';
                              final active = driver['is_active'] == true;

                              return Card(
                                color: const Color(0xFF101610),
                                child: ListTile(
                                  onTap: () => _openDriverReport(driver),
                                  contentPadding: const EdgeInsets.all(14),
                                  leading: _DriverAvatar(avatarUrl: ''),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$phone\n$email',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Driver actions',
                                    onSelected: (value) {
                                      if (value == 'report') {
                                        _openDriverReport(driver);
                                      } else if (value == 'status') {
                                        _toggleDriverStatus(driver);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem<String>(
                                        value: 'report',
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.analytics_outlined,
                                          ),
                                          title: Text('View Report'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'status',
                                        child: ListTile(
                                          leading: Icon(
                                            active
                                                ? Icons.pause_circle_outline
                                                : Icons.play_circle_outline,
                                          ),
                                          title: Text(
                                            active
                                                ? 'Suspend Driver'
                                                : 'Activate Driver',
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF112516),
      backgroundImage: hasImage ? NetworkImage(avatarUrl.trim()) : null,
      child: hasImage
          ? null
          : const Icon(Icons.person_outline, color: Colors.white38, size: 22),
    );
  }
}

class DriverReportPage extends StatefulWidget {
  const DriverReportPage({
    super.key,
    required this.repository,
    required this.driverId,
    required this.driver,
  });

  final AdminDriversRepository repository;
  final String driverId;
  final Map<String, dynamic> driver;

  @override
  State<DriverReportPage> createState() => _DriverReportPageState();
}

class _DriverReportPageState extends State<DriverReportPage> {
  bool _loading = true;

  String _range = 'today';

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _rejections = [];
  double? _averageRating;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  DateTime? get _rangeStart {
    final now = DateTime.now();

    switch (_range) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case '7days':
        return now.subtract(const Duration(days: 7));
      case '30days':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);

    try {
      final start = _rangeStart;

      final results = await Future.wait([
        widget.repository.getDriverOrders(
          driverId: widget.driverId,
          from: start,
        ),
        widget.repository.getDriverRejections(
          driverId: widget.driverId,
          from: start,
        ),
        widget.repository.getDriverAverageRating(widget.driverId),
      ]);

      if (!mounted) return;

      setState(() {
        _orders = results[0] as List<Map<String, dynamic>>;
        _rejections = results[1] as List<Map<String, dynamic>>;
        _averageRating = results[2] as double?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Failed to load driver report: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _countStatus(String status) {
    return _orders.where((order) => '${order['status']}' == status).length;
  }

  String _destination(Map<String, dynamic> order) {
    final parts = <String>[];

    void add(dynamic value) {
      final text = '$value'.trim();

      if (text.isNotEmpty && text != 'null') {
        parts.add(text);
      }
    }

    add(order['delivery_address_line']);
    add(order['delivery_building']);
    add(order['delivery_apartment']);

    if (order['delivery_floor'] != null) {
      add('Floor ${order['delivery_floor']}');
    }

    add(order['delivery_landmark']);

    return parts.isEmpty ? 'Destination unavailable' : parts.join('  ');
  }

  String _orderNumber(dynamic value) {
    final id = '$value';

    if (id.length <= 8) {
      return '#$id';
    }

    return '#${id.substring(0, 8).toUpperCase()}';
  }

  String _formatDate(dynamic value) {
    final raw = '$value';

    try {
      final date = DateTime.parse(raw).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');

      return '$day/$month/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (error) {
      debugPrint('DRIVERS: could not format date "$raw" -> $error');
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.driver['full_name'] ?? 'Unnamed Driver'}';
    final active = widget.driver['is_active'] == true;

    final total = _orders.length;
    final delivered = _countStatus('delivered');
    final cancelled = _countStatus('cancelled');
    final rejected = _rejections.length;

    final successRate = total == 0 ? 0 : (delivered / total) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFF080C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D130D),
        foregroundColor: Colors.white,
        title: Text('$name  REPORT'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF112516)
                              : const Color(0xFF211313),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          active ? 'ACTIVE' : 'SUSPENDED',
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF00FF88)
                                : Colors.redAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _range,
                          dropdownColor: const Color(0xFF101610),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'REPORT RANGE',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'today',
                              child: Text('Today'),
                            ),
                            DropdownMenuItem(
                              value: '7days',
                              child: Text('Last 7 Days'),
                            ),
                            DropdownMenuItem(
                              value: '30days',
                              child: Text('Last 30 Days'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Time'),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;

                            setState(() => _range = value);
                            await _loadReport();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _StatTile(
                        label: 'ORDERS',
                        value: '$total',
                        icon: Icons.receipt_long_outlined,
                      ),
                      _StatTile(
                        label: 'DELIVERED',
                        value: '$delivered',
                        icon: Icons.check_circle_outline,
                      ),
                      _StatTile(
                        label: 'REJECTED',
                        value: '$rejected',
                        icon: Icons.block_outlined,
                      ),
                      _StatTile(
                        label: 'CANCELLED',
                        value: '$cancelled',
                        icon: Icons.cancel_outlined,
                      ),
                      _StatTile(
                        label: 'SUCCESS RATE',
                        value: '${successRate.toStringAsFixed(1)}%',
                        icon: Icons.insights_outlined,
                      ),
                      _StatTile(
                        label: 'AVG RATING',
                        value: _averageRating == null
                            ? ''
                            : _averageRating!.toStringAsFixed(1),
                        icon: Icons.star_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ORDER HISTORY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No orders found for this period.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    )
                  else
                    ..._orders.map((order) {
                      final status = '${order['status']}';
                      final store = order['stores'];
                      final storeName = store is Map
                          ? '${store['name'] ?? 'Store'}'
                          : 'Store';

                      return Card(
                        color: const Color(0xFF101610),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _orderNumber(order['id']),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF00FF88),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                storeName,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _destination(order),
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(order['created_at']),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101610),
        border: Border.all(color: const Color(0xFF1B251B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00FF88)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
