import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../data/services/store_printer_settings_service.dart';
import '../../data/services/thermal_printer_service.dart';
import '../../domain/entities/store_order_part.dart';

class StoreOrderPrintQueueConsumer extends ConsumerStatefulWidget {
  const StoreOrderPrintQueueConsumer({super.key});

  @override
  ConsumerState<StoreOrderPrintQueueConsumer> createState() =>
      _StoreOrderPrintQueueConsumerState();
}

class _StoreOrderPrintQueueConsumerState
    extends ConsumerState<StoreOrderPrintQueueConsumer>
    with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  final StorePrinterSettingsService _settingsService =
      StorePrinterSettingsService();

  Timer? _timer;
  bool _processing = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _active =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    debugPrint(
      'Hena print queue initialized: lifecycle=${WidgetsBinding.instance.lifecycleState}, active=$_active',
    );

    _schedulePolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;

    if (_active) {
      _poll();
    }
  }

  void _schedulePolling() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _poll(),
    );

    if (_active) {
      _poll();
    }
  }

  Future<void> _poll() async {
    if (!mounted) return;

    if (!_active) {
      debugPrint('Hena print queue poll skipped: app inactive');
      return;
    }

    if (_processing) {
      debugPrint('Hena print queue poll skipped: previous poll still running');
      return;
    }

    debugPrint('Hena print queue poll started');

    _processing = true;

    try {
      final stores = await ref.read(myStoresProvider.future);

      debugPrint('Hena print queue: stores loaded=${stores.length}');

      if (!mounted || !_active || stores.isEmpty) return;

      final configuredStores = <String, StorePrinterSettings>{};

      for (final store in stores) {
        final settings = await _settingsService.load(store.id);

        if (settings.hasPrinter) {
          configuredStores[store.id] = settings;
        }
      }

      // Never claim jobs for stores without a configured printer.
      debugPrint(
        'Hena print queue: stores with configured printers=${configuredStores.length}',
      );

      if (configuredStores.isEmpty || !mounted || !_active) return;

      final response = await _client.rpc(
        'claim_store_print_jobs',
        params: {
          'p_limit': 3,
          'p_store_ids': configuredStores.keys.toList(),
        },
      );

      final jobs = List<Map<String, dynamic>>.from(response as List);

      debugPrint('Hena print queue: claimed jobs=${jobs.length}');

      for (final job in jobs) {
        if (!mounted || !_active) break;

        await _processJob(
          job: job,
          settingsByStore: configuredStores,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Hena print queue polling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _processing = false;
    }
  }

  Future<void> _processJob({
    required Map<String, dynamic> job,
    required Map<String, StorePrinterSettings> settingsByStore,
  }) async {
    final jobId = (job['job_id'] ?? job['id'])?.toString();
    final claimToken = job['claim_token']?.toString();
    final partId = job['order_store_part_id']?.toString();
    final orderId = job['order_id']?.toString();
    final storeId = job['store_id']?.toString();

    if (jobId == null || claimToken == null) {
      debugPrint('Hena print job cannot be acknowledged; claim identifiers are missing: $job');
      return;
    }

    if (partId == null || orderId == null || storeId == null) {
      debugPrint('Hena print job has incomplete identifiers: $job');
      await _failJob(
        jobId,
        claimToken,
        'Print job is missing order, store, or order-part identifiers.',
      );
      return;
    }

    final settings = settingsByStore[storeId];

    if (settings == null || !settings.hasPrinter) {
      await _failJob(
        jobId,
        claimToken,
        'No configured printer for this store.',
      );
      return;
    }

    ThermalPrinterService? printer;

    try {
      final partResponse = await _client
          .from('order_store_parts')
          .select(
            'id,order_id,store_id,status,subtotal,item_count,ready_at,'
            'picked_up_at,created_at,'
            'orders!inner('
            'id,unified_order_number,status,delivery_recipient_name,'
            'delivery_phone,delivery_governorate,delivery_city,'
            'delivery_area,delivery_building_number,'
            'delivery_apartment_number,delivery_address_details,'
            'customer_notes,created_at'
            '),'
            'stores!inner(id,name)',
          )
          .eq('id', partId)
          .eq('store_id', storeId)
          .maybeSingle();

      if (partResponse == null) {
        throw StateError('Order store part was not found.');
      }

      final part = _mapPart(
        Map<String, dynamic>.from(partResponse),
      );

      final itemsResponse = await _client
          .from('order_items')
          .select(
            'product_name,quantity,unit_price,item_total,additional_fee',
          )
          .eq('order_id', orderId)
          .eq('store_id', storeId)
          .order('created_at', ascending: true);

      final items = List<Map<String, dynamic>>.from(itemsResponse);

      if (items.isEmpty) {
        throw StateError('No order items found for this store.');
      }

      printer = ThermalPrinterService();

      final printed = await printer.printStoreOrder(
        address: settings.printerAddress!,
        part: part,
        items: items,
        paperSize: settings.paperSize,
      );

      if (!printed) {
        throw StateError('Bluetooth printer did not confirm printing.');
      }

      final completionResult = await _client.rpc(
        'complete_store_print_job',
        params: {
          'p_job_id': jobId,
          'p_claim_token': claimToken,
        },
      );

      if (completionResult != true) {
        throw StateError(
          'Database did not confirm print job completion.',
        );
      }

      debugPrint('Hena print job completed: $jobId');
    } catch (error, stackTrace) {
      debugPrint('Hena print job failed ($jobId): $error');
      debugPrintStack(stackTrace: stackTrace);

      await _failJob(
        jobId,
        claimToken,
        error.toString(),
      );
    } finally {
      if (printer != null) {
        try {
          await printer.disconnect();
        } catch (error) {
          debugPrint('Printer disconnect failed: $error');
        }

        printer.dispose();
      }
    }
  }

  StoreOrderPart _mapPart(Map<String, dynamic> row) {
    final order = Map<String, dynamic>.from(row['orders'] as Map);
    final store = Map<String, dynamic>.from(row['stores'] as Map);

    final address = [
      order['delivery_governorate'],
      order['delivery_city'],
      order['delivery_area'],
      order['delivery_building_number'],
      order['delivery_apartment_number'],
      order['delivery_address_details'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');

    return StoreOrderPart(
      id: row['id'].toString(),
      orderId: row['order_id'].toString(),
      unifiedOrderNumber:
          order['unified_order_number']?.toString() ?? row['order_id'].toString(),
      storeId: row['store_id'].toString(),
      storeName: store['name']?.toString() ?? '',
      status: _statusFromDb(row['status']?.toString() ?? ''),
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
      readyAt: _date(row['ready_at']),
      pickedUpAt: _date(row['picked_up_at']),
      createdAt: _date(row['created_at']),
      customerName: order['delivery_recipient_name']?.toString() ?? '',
      customerPhone: order['delivery_phone']?.toString() ?? '',
      deliveryAddress: address,
      customerNote: order['customer_notes']?.toString(),
      orderCreatedAt: _date(order['created_at']),
    );
  }

  StoreOrderPartStatus _statusFromDb(String value) {
    switch (value) {
      case 'ready':
        return StoreOrderPartStatus.ready;
      case 'picked_up':
        return StoreOrderPartStatus.pickedUp;
      case 'preparing':
      default:
        return StoreOrderPartStatus.preparing;
    }
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _failJob(
    String jobId,
    String claimToken,
    String error,
  ) async {
    try {
      await _client.rpc(
        'fail_store_print_job',
        params: {
          'p_job_id': jobId,
          'p_claim_token': claimToken,
          'p_error': error.length > 1000 ? error.substring(0, 1000) : error,
        },
      );
    } catch (failure) {
      debugPrint('Could not report print job failure ($jobId): $failure');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}


