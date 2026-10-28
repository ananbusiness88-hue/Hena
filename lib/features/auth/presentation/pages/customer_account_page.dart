import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_providers.dart';
import '../../../role_request/presentation/pages/role_request_page.dart';

class CustomerAccountPage extends ConsumerStatefulWidget {
  const CustomerAccountPage({super.key});

  @override
  ConsumerState<CustomerAccountPage> createState() =>
      _CustomerAccountPageState();
}

class _CustomerAccountPageState extends ConsumerState<CustomerAccountPage> {
  static const _page = Color(0xFFF7FAF8);
  static const _green = Color(0xFF087A4B);
  static const _blue = Color(0xFF2A76B8);

  late Future<List<Map<String, dynamic>>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _addressesFuture = userId == null
        ? Future.value(<Map<String, dynamic>>[])
        : _loadAddresses(userId);
  }

  Future<List<Map<String, dynamic>>> _loadAddresses(String userId) async {
    final response = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  void _refreshAddresses() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _addressesFuture = _loadAddresses(userId);
    });
  }

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب حذف الحساب'),
        content: const Text(
          'سيتم فتح صفحة طلب حذف الحساب. لن يحذف الحساب بمجرد فتح الصفحة يجب إرسال الطلب من خلالها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uri = Uri.parse(
      'https://ananbusiness88-hue.github.io/Hena/delete-account.html',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح صفحة طلب حذف الحساب'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: _page,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _AccountState(
            icon: Icons.error_outline_rounded,
            title:
                '\u{062a}\u{0639}\u{0630}\u{0631} \u{062a}\u{062d}\u{0645}\u{064a}\u{0644} \u{0628}\u{064a}\u{0627}\u{0646}\u{0627}\u{062a} \u{0627}\u{0644}\u{062d}\u{0633}\u{0627}\u{0628}',
            subtitle: '$error',
            color: const Color(0xFFB42318),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (profile) {
            if (profile == null || user == null) {
              return _AccountState(
                icon: Icons.person_off_outlined,
                title:
                    '\u{0628}\u{064a}\u{0627}\u{0646}\u{0627}\u{062a} \u{0627}\u{0644}\u{062d}\u{0633}\u{0627}\u{0628} \u{063a}\u{064a}\u{0631} \u{0645}\u{062a}\u{0627}\u{062d}\u{0629}',
                subtitle:
                    '\u{0623}\u{0639}\u{062f} \u{062a}\u{0633}\u{062c}\u{064a}\u{0644} \u{0627}\u{0644}\u{062f}\u{062e}\u{0648}\u{0644} \u{062b}\u{0645} \u{062d}\u{0627}\u{0648}\u{0644} \u{0645}\u{0631}\u{0629} \u{0623}\u{062e}\u{0631}\u{0649}.',
                color: _blue,
                onRetry: () => ref.invalidate(currentProfileProvider),
              );
            }

            final fullName =
                (profile['full_name'] as String?)?.trim().isNotEmpty == true
                ? profile['full_name'] as String
                : '\u{062d}\u{0633}\u{0627}\u{0628} \u{0627}\u{0644}\u{0639}\u{0645}\u{064a}\u{0644}';
            final phone = (profile['phone'] as String?) ?? '';
            final email = (profile['email'] as String?) ?? user.email ?? '';

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentProfileProvider);
                _refreshAddresses();
                await ref.read(currentProfileProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                children: [
                  _SectionTitle(
                    title: '\u{062d}\u{0633}\u{0627}\u{0628}\u{0643}',
                    subtitle:
                        '\u{0628}\u{064a}\u{0627}\u{0646}\u{0627}\u{062a}\u{0643} \u{0645}\u{062d}\u{0641}\u{0648}\u{0638}\u{0629} \u{0648}\u{0622}\u{0645}\u{0646}\u{0629}',
                  ),
                  const SizedBox(height: 14),
                  _ProfileHero(
                    fullName: fullName,
                    phone: phone,
                    onEdit: () => _editName(
                      userId: user.id,
                      currentName:
                          fullName ==
                              '\u{062d}\u{0633}\u{0627}\u{0628} \u{0627}\u{0644}\u{0639}\u{0645}\u{064a}\u{0644}'
                          ? ''
                          : fullName,
                      phone: phone,
                      email: email,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title:
                        '\u{0645}\u{0639}\u{0644}\u{0648}\u{0645}\u{0627}\u{062a} \u{0627}\u{0644}\u{062d}\u{0633}\u{0627}\u{0628}',
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: '\u{0627}\u{0644}\u{0627}\u{0633}\u{0645}',
                        value: fullName,
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label:
                            '\u{0631}\u{0642}\u{0645} \u{0627}\u{0644}\u{0647}\u{0627}\u{062a}\u{0641}',
                        value: phone.isEmpty
                            ? '—'
                            : phone,
                      ),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label:
                            '\u{0627}\u{0644}\u{0628}\u{0631}\u{064a}\u{062f} \u{0627}\u{0644}\u{0625}\u{0644}\u{0643}\u{062a}\u{0631}\u{0648}\u{0646}\u{064a}',
                        value: email.isEmpty
                            ? '—'
                            : email,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SectionTitle(
                          title:
                              '\u{0627}\u{0644}\u{0639}\u{0646}\u{0627}\u{0648}\u{064a}\u{0646} \u{0627}\u{0644}\u{0645}\u{062d}\u{0641}\u{0648}\u{0638}\u{0629}',
                          subtitle:
                              '\u{0623}\u{0636}\u{0641} \u{0623}\u{0648} \u{0639}\u{062f}\u{0651}\u{0644} \u{0639}\u{0646}\u{0648}\u{0627}\u{0646} \u{0627}\u{0644}\u{062a}\u{0648}\u{0635}\u{064a}\u{0644}',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _editAddress(
                          userId: user.id,
                          profileName: fullName,
                          profilePhone: phone,
                        ),
                        icon: const Icon(
                          Icons.add_location_alt_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          '\u{0625}\u{0636}\u{0627}\u{0641}\u{0629} \u{0639}\u{0646}\u{0648}\u{0627}\u{0646}',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _addressesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return _InlineError(
                          text:
                              '\u{062a}\u{0639}\u{0630}\u{0631} \u{062a}\u{062d}\u{0645}\u{064a}\u{0644} \u{0627}\u{0644}\u{0639}\u{0646}\u{0627}\u{0648}\u{064a}\u{0646}',
                          onRetry: _refreshAddresses,
                        );
                      }

                      final addresses = snapshot.data ?? const [];
                      if (addresses.isEmpty) {
                        return _EmptyAddresses(
                          onAdd: () => _editAddress(
                            userId: user.id,
                            profileName: fullName,
                            profilePhone: phone,
                          ),
                        );
                      }

                      return Column(
                        children: addresses.map((address) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AddressCard(
                              address: address,
                              onEdit: () => _editAddress(
                                userId: user.id,
                                profileName: fullName,
                                profilePhone: phone,
                                existing: address,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '\u{0627}\u{0646}\u{0636}\u{0645} \u{0625}\u{0644}\u{0649} \u{0647}\u{0650}\u{0646}\u{0627}',
                    style: TextStyle(
                      color: Color(0xFF16342A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '\u{0627}\u{062e}\u{062a}\u{0631} \u{0627}\u{0644}\u{0637}\u{0631}\u{064a}\u{0642}\u{0629} \u{0627}\u{0644}\u{062a}\u{064a} \u{062a}\u{0631}\u{064a}\u{062f} \u{0623}\u{0646} \u{062a}\u{0634}\u{0627}\u{0631}\u{0643} \u{0628}\u{0647}\u{0627} \u{0645}\u{0639}\u{0646}\u{0627}',
                    style: TextStyle(
                      color: Color(0xFF71857C),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RoleRequestCard(
                    onDriverTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const RoleRequestPage(initialRole: 'driver'),
                        ),
                      );
                    },
                    onStoreOwnerTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const RoleRequestPage(initialRole: 'store_owner'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: _requestAccountDeletion,
                    icon: const Icon(Icons.person_remove_alt_1_outlined),
                    label: const Text('طلب حذف الحساب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      side: const BorderSide(color: Color(0xFFF0C5C5)),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _editName({
    required String userId,
    required String currentName,
    required String phone,
    required String email,
  }) async {
    final controller = TextEditingController(text: currentName);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _EditNameSheet(
          controller: controller,
          onSave: () async {
            final value = controller.text.trim();
            if (value.isEmpty) return false;

            try {
              await ref
                  .read(authRemoteDataSourceProvider)
                  .updateProfile(
                    userId: userId,
                    phone: phone,
                    fullName: value,
                    email: email,
                  );
              if (!context.mounted) return false;
              ref.invalidate(currentProfileProvider);
              Navigator.of(sheetContext).pop(true);
              return true;
            } catch (error) {
              if (!mounted) return false;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '\u{062d}\u{062f}\u{062b} \u{062e}\u{0637}\u{0623} \u{0623}\u{062b}\u{0646}\u{0627}\u{0621} \u{0627}\u{0644}\u{062d}\u{0641}\u{0638}: $error',
                  ),
                ),
              );
              return false;
            }
          },
        );
      },
    );

    controller.dispose();

    if (result == true && mounted) {
      ref.invalidate(currentProfileProvider);
    }
  }

  Future<void> _editAddress({
    required String userId,
    required String profileName,
    required String profilePhone,
    Map<String, dynamic>? existing,
  }) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressSheet(
        existing: existing,
        profileName: profileName,
        profilePhone: profilePhone,
      ),
    );

    if (result == null) return;

    try {
      final client = Supabase.instance.client;
      final isDefault = result['is_default'] == true;

      if (isDefault) {
        await client
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      final payload = <String, dynamic>{
        'label': result['label'],
        'recipient_name': result['recipient_name'],
        'phone': result['phone'],
        'area': result['area'],
        'building_number': result['building_number'],
        'apartment_number': result['apartment_number'],
        'address_details': result['address_details'],
        'is_default': isDefault,
      };

      final id = existing?['id'] as String?;

      if (id == null) {
        payload['user_id'] = userId;
        await client.from('addresses').insert(payload);
      } else {
        await client
            .from('addresses')
            .update(payload)
            .eq('id', id)
            .eq('user_id', userId);
      }

      _refreshAddresses();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u{062a}\u{0645} \u{062d}\u{0641}\u{0638} \u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646} \u{0628}\u{0646}\u{062c}\u{0627}\u{062d}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u{062d}\u{062f}\u{062b} \u{062e}\u{0637}\u{0623} \u{0623}\u{062b}\u{0646}\u{0627}\u{0621} \u{0627}\u{0644}\u{062d}\u{0641}\u{0638}: $error',
          ),
        ),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF16342A),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF71857C),
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.fullName,
    required this.phone,
    required this.onEdit,
  });

  final String fullName;
  final String phone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0E6E4B), Color(0xFF123F2F)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220B4E39),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .28),
                width: 1.4,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  phone.isEmpty
                      ? '—'
                      : phone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: '\u{062a}\u{0639}\u{062f}\u{064a}\u{0644}',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .12),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDEBE4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF16342A),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEAF1ED))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF087A4B), size: 21),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF71857C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF17382D),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onEdit});

  final Map<String, dynamic> address;
  final VoidCallback onEdit;

  String _text(String key) => (address[key] as String?)?.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final label = _text('label');
    final area = _text('area');
    final building = _text('building_number');
    final apartment = _text('apartment_number');
    final details = _text('address_details');
    final recipient = _text('recipient_name');
    final phone = _text('phone');
    final isDefault = address['is_default'] == true;

    final parts = <String>[
      if (area.isNotEmpty) area,
      if (building.isNotEmpty)
        '\u{0639}\u{0645}\u{0627}\u{0631}\u{0629} $building',
      if (apartment.isNotEmpty) '\u{0634}\u{0642}\u{0629} $apartment',
      if (details.isNotEmpty) details,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDefault ? const Color(0xFFB9DFCA) : const Color(0xFFE0EBE6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF087A4B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.isEmpty ? '\u{0645}\u{0646}\u{0632}\u{0644}' : label,
                  style: const TextStyle(
                    color: Color(0xFF16342A),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646} \u{0627}\u{0644}\u{0627}\u{0641}\u{062a}\u{0631}\u{0627}\u{0636}\u{064a}',
                    style: const TextStyle(
                      color: Color(0xFF087A4B),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onEdit,
                tooltip: '\u{062a}\u{0639}\u{062f}\u{064a}\u{0644}',
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (recipient.isNotEmpty || phone.isNotEmpty)
            Wrap(
              spacing: 9,
              runSpacing: 7,
              children: [
                if (recipient.isNotEmpty)
                  _AddressPill(
                    icon: Icons.person_outline_rounded,
                    text: recipient,
                  ),
                if (phone.isNotEmpty)
                  _AddressPill(icon: Icons.phone_outlined, text: phone),
              ],
            ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              parts.join('  \u{2022}  '),
              style: const TextStyle(
                color: Color(0xFF516960),
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressPill extends StatelessWidget {
  const _AddressPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF527066)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF52665D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  const _EmptyAddresses({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDEBE4)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 52,
            color: Color(0xFF7C9187),
          ),
          const SizedBox(height: 10),
          Text(
            '\u{0644}\u{0627} \u{062a}\u{0648}\u{062c}\u{062f} \u{0639}\u{0646}\u{0627}\u{0648}\u{064a}\u{0646} \u{0645}\u{062d}\u{0641}\u{0648}\u{0638}\u{0629}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF16342A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\u{0623}\u{0636}\u{0641} \u{0639}\u{0646}\u{0648}\u{0627}\u{0646} \u{0627}\u{0644}\u{062a}\u{0648}\u{0635}\u{064a}\u{0644} \u{0644}\u{062a}\u{0633}\u{0647}\u{064a}\u{0644} \u{0625}\u{062a}\u{0645}\u{0627}\u{0645} \u{0627}\u{0644}\u{0637}\u{0644}\u{0628}\u{0627}\u{062a}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF71857C)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text(
              '\u{0625}\u{0636}\u{0627}\u{0641}\u{0629} \u{0639}\u{0646}\u{0648}\u{0627}\u{0646}',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3D4CF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF7A3028),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _AccountState extends StatelessWidget {
  const _AccountState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF16342A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF71857C)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                '\u{0625}\u{0639}\u{0627}\u{062f}\u{0629} \u{0627}\u{0644}\u{0645}\u{062d}\u{0627}\u{0648}\u{0644}\u{0629}',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditNameSheet extends StatelessWidget {
  const _EditNameSheet({required this.controller, required this.onSave});

  final TextEditingController controller;
  final Future<bool> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3E0DA),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '\u{062a}\u{0639}\u{062f}\u{064a}\u{0644} \u{0627}\u{0644}\u{0627}\u{0633}\u{0645}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16342A),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: '\u{0627}\u{0633}\u{0645}\u{0643}',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF7FAF8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '\u{064a}\u{0645}\u{0643}\u{0646}\u{0643} \u{062a}\u{0639}\u{062f}\u{064a}\u{0644} \u{0627}\u{0644}\u{0627}\u{0633}\u{0645} \u{0648}\u{0627}\u{0644}\u{0639}\u{0646}\u{0627}\u{0648}\u{064a}\u{0646} \u{0627}\u{0644}\u{0645}\u{062d}\u{0641}\u{0648}\u{0638}\u{0629}. \u{0631}\u{0642}\u{0645} \u{0627}\u{0644}\u{0647}\u{0627}\u{062a}\u{0641} \u{0648}\u{0627}\u{0644}\u{0628}\u{0631}\u{064a}\u{062f} \u{0627}\u{0644}\u{0625}\u{0644}\u{0643}\u{062a}\u{0631}\u{0648}\u{0646}\u{064a} \u{0645}\u{0631}\u{062a}\u{0628}\u{0637}\u{0627}\u{0646} \u{0628}\u{0628}\u{064a}\u{0627}\u{0646}\u{0627}\u{062a} \u{0627}\u{0644}\u{062f}\u{062e}\u{0648}\u{0644}.',
                  style: TextStyle(color: Color(0xFF71857C), height: 1.45),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          '\u{0625}\u{0644}\u{063a}\u{0627}\u{0621}',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await onSave();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF087A4B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '\u{062d}\u{0641}\u{0638} \u{0627}\u{0644}\u{062a}\u{0639}\u{062f}\u{064a}\u{0644}\u{0627}\u{062a}',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({
    required this.existing,
    required this.profileName,
    required this.profilePhone,
  });

  final Map<String, dynamic>? existing;
  final String profileName;
  final String profilePhone;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final TextEditingController _label;
  late final TextEditingController _recipient;
  late final TextEditingController _phone;
  late final TextEditingController _area;
  late final TextEditingController _building;
  late final TextEditingController _apartment;
  late final TextEditingController _details;
  late bool _isDefault;

  String _v(String key) => (widget.existing?[key] as String?)?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(
      text: _v('label').isEmpty
          ? '\u{0627}\u{0644}\u{0645}\u{0646}\u{0632}\u{0644}'
          : _v('label'),
    );
    _recipient = TextEditingController(
      text: _v('recipient_name').isEmpty
          ? widget.profileName
          : _v('recipient_name'),
    );
    _phone = TextEditingController(
      text: _v('phone').isEmpty ? widget.profilePhone : _v('phone'),
    );
    _area = TextEditingController(text: _v('area'));
    _building = TextEditingController(text: _v('building_number'));
    _apartment = TextEditingController(text: _v('apartment_number'));
    _details = TextEditingController(text: _v('address_details'));
    _isDefault = widget.existing?['is_default'] == true;
  }

  @override
  void dispose() {
    _label.dispose();
    _recipient.dispose();
    _phone.dispose();
    _area.dispose();
    _building.dispose();
    _apartment.dispose();
    _details.dispose();
    super.dispose();
  }

  void _save() {
    if (_label.text.trim().isEmpty ||
        _recipient.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _area.text.trim().isEmpty ||
        _building.text.trim().isEmpty ||
        _apartment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u{0645}\u{0646} \u{0641}\u{0636}\u{0644}\u{0643} \u{0623}\u{0643}\u{0645}\u{0644} \u{0628}\u{064a}\u{0627}\u{0646}\u{0627}\u{062a} \u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646} \u{0627}\u{0644}\u{0645}\u{0637}\u{0644}\u{0648}\u{0628}\u{0629}.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(<String, dynamic>{
      'label': _label.text.trim(),
      'recipient_name': _recipient.text.trim(),
      'phone': _phone.text.trim(),
      'area': _area.text.trim(),
      'building_number': _building.text.trim(),
      'apartment_number': _apartment.text.trim(),
      'address_details': _details.text.trim(),
      'is_default': _isDefault,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 760),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              shrinkWrap: true,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3E0DA),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEditing
                      ? '\u{062a}\u{0639}\u{062f}\u{064a}\u{0644} \u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646}'
                      : '\u{0639}\u{0646}\u{0648}\u{0627}\u{0646} \u{062c}\u{062f}\u{064a}\u{062f}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16342A),
                  ),
                ),
                const SizedBox(height: 14),
                _AddressField(
                  controller: _label,
                  label:
                      '\u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646}',
                  icon: Icons.label_outline_rounded,
                ),
                _AddressField(
                  controller: _recipient,
                  label:
                      '\u{0627}\u{0644}\u{0645}\u{0633}\u{062a}\u{0644}\u{0645}',
                  icon: Icons.person_outline_rounded,
                ),
                _AddressField(
                  controller: _phone,
                  label: '\u{0627}\u{0644}\u{0647}\u{0627}\u{062a}\u{0641}',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                ),
                _AddressField(
                  controller: _area,
                  label:
                      '\u{0627}\u{0644}\u{0645}\u{0646}\u{0637}\u{0642}\u{0629}',
                  icon: Icons.location_on_outlined,
                ),
                _AddressField(
                  controller: _building,
                  label:
                      '\u{0631}\u{0642}\u{0645} \u{0627}\u{0644}\u{0639}\u{0645}\u{0627}\u{0631}\u{0629}',
                  icon: Icons.business_outlined,
                  keyboard: TextInputType.number,
                ),
                _AddressField(
                  controller: _apartment,
                  label:
                      '\u{0631}\u{0642}\u{0645} \u{0627}\u{0644}\u{0634}\u{0642}\u{0629}',
                  icon: Icons.home_outlined,
                  keyboard: TextInputType.number,
                ),
                _AddressField(
                  controller: _details,
                  label:
                      '\u{062a}\u{0641}\u{0627}\u{0635}\u{064a}\u{0644} \u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646}',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                ),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value),
                  title: const Text(
                    '\u{0627}\u{062c}\u{0639}\u{0644} \u{0647}\u{0630}\u{0627} \u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646} \u{0627}\u{0641}\u{062a}\u{0631}\u{0627}\u{0636}\u{064a}\u{064b}\u{0627}',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  activeThumbColor: const Color(0xFF087A4B),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    isEditing
                        ? '\u{062d}\u{0641}\u{0638} \u{0627}\u{0644}\u{062a}\u{0639}\u{062f}\u{064a}\u{0644}\u{0627}\u{062a}'
                        : '\u{062d}\u{0641}\u{0638} \u{0627}\u{0644}\u{0639}\u{0646}\u{0648}\u{0627}\u{0646}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF087A4B),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _RoleRequestCard extends StatelessWidget {
  const _RoleRequestCard({
    required this.onDriverTap,
    required this.onStoreOwnerTap,
  });

  final VoidCallback onDriverTap;
  final VoidCallback onStoreOwnerTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoleChoiceCard(
          icon: Icons.local_shipping_rounded,
          title:
              '\u{0623}\u{0635}\u{0628}\u{062D} \u{0633}\u{0627}\u{0626}\u{0642}\u{064B}\u{0627}',
          subtitle:
              '\u{0648}\u{0635}\u{0651}\u{0644} \u{0627}\u{0644}\u{0637}\u{0644}\u{0628}\u{0627}\u{062A} \u{0648}\u{0643}\u{0646} \u{062C}\u{0632}\u{0621}\u{064B}\u{0627} \u{0645}\u{0646} \u{0641}\u{0631}\u{064A}\u{0642} \u{0627}\u{0644}\u{062A}\u{0648}\u{0635}\u{064A}\u{0644}',
          badge:
              '\u{0641}\u{0631}\u{0635}\u{0629} \u{0644}\u{0644}\u{0633}\u{0627}\u{0626}\u{0642}\u{064A}\u{0646}',
          gradient: const [
            Color(0xFF1677E8),
            Color(0xFF00A6C7),
            Color(0xFF35C9B2),
          ],
          onTap: onDriverTap,
        ),
        const SizedBox(height: 12),
        _RoleChoiceCard(
          icon: Icons.storefront_rounded,
          title:
              '\u{0623}\u{0635}\u{0628}\u{062D} \u{0635}\u{0627}\u{062D}\u{0628} \u{0645}\u{062D}\u{0644}',
          subtitle:
              '\u{0627}\u{0639}\u{0631}\u{0636} \u{0645}\u{062A}\u{062C}\u{0631}\u{0643} \u{0648}\u{0645}\u{0646}\u{062A}\u{062C}\u{0627}\u{062A}\u{0643} \u{0644}\u{0639}\u{0645}\u{0644}\u{0627}\u{0621} \u{0647}\u{0650}\u{0646}\u{0627}',
          badge:
              '\u{0644}\u{0623}\u{0635}\u{062D}\u{0627}\u{0628} \u{0627}\u{0644}\u{0645}\u{062A}\u{0627}\u{062C}\u{0631}',
          gradient: const [
            Color(0xFF087A4B),
            Color(0xFF0C9B72),
            Color(0xFFF0A83A),
          ],
          onTap: onStoreOwnerTap,
        ),
      ],
    );
  }
}

class _RoleChoiceCard extends StatelessWidget {
  const _RoleChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 148,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: .22),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -28,
                left: -18,
                child: Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -42,
                right: -18,
                child: Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .09),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .28),
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .17),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .20),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .88),
                              height: 1.25,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .17),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .22),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
