import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotificationCenterPage extends ConsumerStatefulWidget {
  const AdminNotificationCenterPage({super.key});

  @override
  ConsumerState<AdminNotificationCenterPage> createState() =>
      _AdminNotificationCenterPageState();
}

class _AdminNotificationCenterPageState
    extends ConsumerState<AdminNotificationCenterPage>
    with SingleTickerProviderStateMixin {
  static const _background = Color(0xFFF7FAF8);
  static const _darkGreen = Color(0xFF123F2F);
  static const _green = Color(0xFF159B68);
  static const _blue = Color(0xFF2F80ED);
  static const _orange = Color(0xFFF39A3D);
  static const _border = Color(0xFFDCE8E1);

  late final TabController _tabController;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  final _client = Supabase.instance.client;
  final _picker = ImagePicker();

  String _audienceRole = 'customer';

  String _targetType = 'none';
  String? _targetId;
  String? _targetName;
  String? _targetImageUrl;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool _sending = false;
  bool _loadingHistory = true;

  List<Map<String, dynamic>> _campaigns = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _loadCampaigns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _loadingHistory = true);

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() {
          _campaigns = [];
          _loadingHistory = false;
        });
        return;
      }

      final rows = await _client
          .from('admin_notification_campaigns')
          .select(
            'id,audience_role,title,body,image_url,target_type,target_id,'
            'target_name,recipient_count,created_at',
          )
          .eq('created_by', user.id)
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;

      setState(() {
        _campaigns = List<Map<String, dynamic>>.from(
          (rows as List).map((item) => Map<String, dynamic>.from(item as Map)),
        );
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loadingHistory = false);

      _showMessage('تعذر تحميل سجل الإشعارات: $error', error: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('تعذر اختيار الصورة: $error', error: true);
    }
  }

  Future<String?> _uploadImage() async {
    final image = _selectedImage;
    final bytes = _selectedImageBytes;

    if (image == null || bytes == null) {
      return null;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Admin session is not available.');
    }

    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';

    final safeExtension = switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };

    final contentType = switch (safeExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

    await _client.storage
        .from('notification-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    return _client.storage.from('notification-images').getPublicUrl(path);
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _showMessage('اكتب عنوان الإشعار.', error: true);
      return;
    }

    if (body.isEmpty) {
      _showMessage('اكتب نص الإشعار.', error: true);
      return;
    }

    setState(() => _sending = true);

    try {
      final imageUrl = await _uploadImage();

      final result = await _client.rpc(
        'admin_send_notification',
        params: {
          'p_target_role': _audienceRole == 'all' ? null : _audienceRole,
          'p_audience_scope': _audienceRole == 'all' ? 'all' : 'role',
          'p_title': title,
          'p_body': body,
          'p_image_url': imageUrl,
          'p_target_type': _targetType,
          'p_target_id': _targetId,
          'p_target_name': _targetName,
        },
      );

      final recipientCount = (result as num).toInt();

      if (_audienceRole == 'all') {
        final pushResponse = await _client.functions.invoke(
          'send_admin_notification_fcm',
          body: {
            'title': title,
            'body': body,
            'image_url': imageUrl,
            'target_type': _targetType,
            'target_id': _targetId,
            'target_name': _targetName,
            'audience_scope': 'all',
          },
        );

        final pushData = pushResponse.data;

        if (pushData is! Map || pushData['success'] != true) {
          throw StateError(
            'تم حفظ الإشعار لكن فشل إرسال FCM.',
          );
        }
      }

      if (!mounted) return;

      _titleController.clear();
      _bodyController.clear();

      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
        _targetType = 'none';
        _targetId = null;
        _targetName = null;
        _targetImageUrl = null;
        _sending = false;
      });

      await _loadCampaigns();
      _tabController.animateTo(0);

      if (!mounted) return;

      _showMessage('تم إرسال الإشعار إلى $recipientCount مستخدم.');
    } catch (error) {
      if (!mounted) return;

      setState(() => _sending = false);

      _showMessage('فشل إرسال الإشعار: $error', error: true);
    }
  }

  Future<void> _chooseStore() async {
    try {
      final rows = await _client
          .from('stores')
          .select('id,name,logo_url')
          .eq('is_active', true)
          .order('name');

      final items = List<Map<String, dynamic>>.from(
        (rows as List).map((item) => Map<String, dynamic>.from(item as Map)),
      );

      if (!mounted) return;

      final selected = await _showEntityPicker(
        title: 'اختيار محل',
        emptyText: 'لا توجد محلات متاحة.',
        items: items,
        imageKey: 'logo_url',
      );

      if (selected == null || !mounted) return;

      setState(() {
        _targetType = 'store';
        _targetId = selected['id']?.toString();
        _targetName = selected['name']?.toString();
        _targetImageUrl = selected['logo_url']?.toString();
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('تعذر تحميل المحلات: $error', error: true);
    }
  }

  Future<void> _chooseProduct() async {
    try {
      final rows = await _client
          .from('products')
          .select('id,name,image_url,store_id')
          .eq('is_active', true)
          .order('name')
          .limit(300);

      final items = List<Map<String, dynamic>>.from(
        (rows as List).map((item) => Map<String, dynamic>.from(item as Map)),
      );

      if (!mounted) return;

      final selected = await _showEntityPicker(
        title: 'اختيار منتج',
        emptyText: 'لا توجد منتجات متاحة.',
        items: items,
        imageKey: 'image_url',
      );

      if (selected == null || !mounted) return;

      setState(() {
        _targetType = 'product';
        _targetId = selected['id']?.toString();
        _targetName = selected['name']?.toString();
        _targetImageUrl = selected['image_url']?.toString();
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('تعذر تحميل المنتجات: $error', error: true);
    }
  }

  Future<Map<String, dynamic>?> _showEntityPicker({
    required String title,
    required String emptyText,
    required List<Map<String, dynamic>> items,
    required String imageKey,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.78,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _darkGreen,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              emptyText,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final name = item['name']?.toString() ?? '';

                              final imageUrl = item[imageKey]?.toString();

                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                tileColor: const Color(0xFFF6FAF8),
                                leading: _EntityImage(imageUrl: imageUrl),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_left_rounded,
                                ),
                                onTap: () => Navigator.pop(sheetContext, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _clearTarget() {
    setState(() {
      _targetType = 'none';
      _targetId = null;
      _targetName = null;
      _targetImageUrl = null;
    });
  }

  void _addEmoji(String emoji) {
    final current = _bodyController.text;
    final value = current.isEmpty ? emoji : '$current $emoji';

    _bodyController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);

    setState(() {});
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : _darkGreen,
      ),
    );
  }

  String _audienceLabel(String role) {
    switch (role) {
      case 'all':
        return 'الكل';
      case 'store_owner':
        return 'أصحاب المحلات';
      case 'driver':
        return 'المندوبين';
      default:
        return 'العملاء';
    }
  }

  String _targetLabel(String type) {
    switch (type) {
      case 'store':
        return 'محل مرتبط';
      case 'product':
        return 'منتج مرتبط';
      default:
        return 'بدون رابط';
    }
  }

  String _formatDate(String raw) {
    final value = DateTime.tryParse(raw);
    if (value == null) return raw;

    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'مركز الإشعارات',
            style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w900),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: _blue,
            unselectedLabelColor: Colors.black45,
            indicatorColor: _blue,
            tabs: const [
              Tab(text: 'سجل الإشعارات'),
              Tab(text: 'إرسال إشعار'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildHistory(), _buildComposer()],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _SectionIntro(
            title: 'الإشعارات التي أرسلتها',
            subtitle:
                'سجل الحملات الإشعارية الموجهة للعملاء وأصحاب المحلات والمندوبين.',
            icon: Icons.history_rounded,
            color: _blue,
          ),
          const SizedBox(height: 12),
          if (_campaigns.isEmpty)
            const _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'لا توجد إشعارات مرسلة',
              subtitle: 'ابدأ بإرسال أول إشعار من التبويب الآخر.',
            )
          else
            ..._campaigns.map(_campaignCard),
        ],
      ),
    );
  }

  Widget _campaignCard(Map<String, dynamic> campaign) {
    final title = campaign['title']?.toString() ?? '';
    final body = campaign['body']?.toString() ?? '';
    final audience = campaign['audience_role']?.toString() ?? 'customer';
    final targetType = campaign['target_type']?.toString() ?? 'none';
    final targetName = campaign['target_name']?.toString();
    final imageUrl = campaign['image_url']?.toString();
    final count = (campaign['recipient_count'] as num?)?.toInt() ?? 0;
    final createdAt = campaign['created_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 7),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CampaignIcon(role: audience),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, height: 1.35),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.people_alt_outlined,
                      text: _audienceLabel(audience),
                      color: _green,
                    ),
                    _InfoChip(
                      icon: Icons.send_rounded,
                      text: '$count مستلم',
                      color: _blue,
                    ),
                    _InfoChip(
                      icon: targetType == 'none'
                          ? Icons.link_off_rounded
                          : Icons.link_rounded,
                      text: targetName ?? _targetLabel(targetType),
                      color: _orange,
                    ),
                    if (createdAt.isNotEmpty)
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        text: _formatDate(createdAt),
                        color: Colors.black45,
                      ),
                  ],
                ),
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 2.3,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SectionIntro(
          title: 'إنشاء إشعار جديد',
          subtitle: 'أنشئ إشعارًا غنيًا ووجّهه إلى الفئة المناسبة.',
          icon: Icons.campaign_rounded,
          color: _green,
        ),
        const SizedBox(height: 14),

        const _StepLabel(number: '1', text: 'اختيار الجمهور'),
        const SizedBox(height: 8),
        _audienceSelector(),

        const SizedBox(height: 18),

        const _StepLabel(number: '2', text: 'محتوى الإشعار'),
        const SizedBox(height: 8),

        TextField(
          controller: _titleController,
          maxLength: 80,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'عنوان الإشعار',
            hintText: 'مثال: عروض جديدة اليوم ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _bodyController,
          minLines: 5,
          maxLines: 8,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'نص الإشعار',
            hintText: 'اكتب الرسالة التي تريد إرسالها...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),

        const SizedBox(height: 8),
        _emojiRow(),

        const SizedBox(height: 18),

        const _StepLabel(number: '3', text: 'إضافات الإشعار'),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ToolButton(
              icon: Icons.image_outlined,
              label: 'إضافة صورة',
              color: _blue,
              onTap: _pickImage,
            ),
            _ToolButton(
              icon: Icons.storefront_outlined,
              label: 'إضافة محل',
              color: _green,
              onTap: _chooseStore,
            ),
            _ToolButton(
              icon: Icons.inventory_2_outlined,
              label: 'إضافة منتج',
              color: _orange,
              onTap: _chooseProduct,
            ),
          ],
        ),

        if (_selectedImageBytes != null) ...[
          const SizedBox(height: 12),
          _selectedImageCard(),
        ],

        if (_targetType != 'none') ...[
          const SizedBox(height: 12),
          _targetCard(),
        ],

        const SizedBox(height: 20),

        const _StepLabel(number: '4', text: 'المعاينة'),
        const SizedBox(height: 8),

        _previewCard(),

        const SizedBox(height: 18),

        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _sending ? null : _sendNotification,
            icon: _sending
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _sending ? 'جارٍ الإرسال...' : 'إرسال الإشعار الآن',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _audienceSelector() {
    final items = <Map<String, dynamic>>[
      {
        'role': 'all',
        'label': 'الكل',
        'icon': Icons.groups_rounded,
        'color': _darkGreen,
      },
      {
        'role': 'customer',
        'label': 'العملاء',
        'icon': Icons.people_alt_outlined,
        'color': _blue,
      },
      {
        'role': 'store_owner',
        'label': 'أصحاب المحلات',
        'icon': Icons.storefront_outlined,
        'color': _green,
      },
      {
        'role': 'driver',
        'label': 'المندوبين',
        'icon': Icons.local_shipping_outlined,
        'color': _orange,
      },
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final role = item['role'] as String;
        final active = _audienceRole == role;
        final color = item['color'] as Color;

        return SizedBox(
          width: 142,
          child: Material(
            color: active ? color.withValues(alpha: .10) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _audienceRole = role;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? color
                        : const Color(0xFFE2E8F0),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: active
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: const Color(0xFF233044),
                        ),
                      ),
                    ),
                    if (active)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: color,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _emojiRow() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ActionChip(
        avatar: const Icon(
          Icons.emoji_emotions_outlined,
          size: 20,
        ),
        label: const Text('إيموجي'),
        onPressed: _openEmojiPicker,
      ),
    );
  }

  Future<void> _openEmojiPicker() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;

        return SafeArea(
          child: Container(
            height: height > 720 ? 520 : height * 0.72,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 10, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'الإيموجي',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) => _addEmoji(emoji.emoji),
                    config: Config(
                      checkPlatformCompatibility: true,
                      emojiViewConfig: const EmojiViewConfig(
                        emojiSizeMax: 28,
                      ),
                      skinToneConfig: const SkinToneConfig(
                        rememberSkinTone: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

Widget _selectedImageCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _selectedImageBytes!,
              width: 82,
              height: 62,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'صورة الإشعار جاهزة للإرسال',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedImage = null;
                _selectedImageBytes = null;
              });
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFB42318),
            ),
          ),
        ],
      ),
    );
  }


  Widget _targetCard() {
    final isStore = _targetType == 'store';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isStore ? const Color(0xFFF1FAF5) : const Color(0xFFFFF7EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStore ? const Color(0xFFCBEBD9) : const Color(0xFFF5D9A8),
        ),
      ),
      child: Row(
        children: [
          _EntityImage(imageUrl: _targetImageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStore ? 'المحل المرتبط' : 'المنتج المرتبط',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _targetName ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearTarget,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final title = _titleController.text.trim().isEmpty
        ? 'عنوان الإشعار'
        : _titleController.text.trim();

    final body = _bodyController.text.trim().isEmpty
        ? 'سيظهر نص الإشعار هنا...'
        : _bodyController.text.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 7),
            color: Color(0x10000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEAF4FF),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: _blue,
                  size: 20,
                ),
              ),
              SizedBox(width: 10),
              Text('هِنا', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(color: Colors.black54, height: 1.45),
          ),
          if (_selectedImageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _selectedImageBytes!,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (_targetType != 'none' && _targetName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _targetType == 'store'
                        ? Icons.storefront_outlined
                        : Icons.inventory_2_outlined,
                    size: 18,
                    color: _green,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _targetName!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, size: 19),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionIntro({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8E1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.10),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF123F2F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String number;
  final String text;

  const _StepLabel({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: const Color(0xFF2F80ED),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF123F2F),
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        side: const BorderSide(color: Color(0xFFDCE8E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignIcon extends StatelessWidget {
  final String role;

  const _CampaignIcon({required this.role});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (role) {
      'store_owner' => (Icons.storefront_outlined, const Color(0xFF159B68)),
      'driver' => (Icons.local_shipping_outlined, const Color(0xFFF39A3D)),
      _ => (Icons.people_alt_outlined, const Color(0xFF2F80ED)),
    };

    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withValues(alpha: 0.10),
      child: Icon(icon, color: color),
    );
  }
}

class _EntityImage extends StatelessWidget {
  final String? imageUrl;

  const _EntityImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F3),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.black38,
              ),
            )
          : const Icon(Icons.image_outlined, color: Colors.black38),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8E1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: const Color(0xFF159B68)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF123F2F),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
