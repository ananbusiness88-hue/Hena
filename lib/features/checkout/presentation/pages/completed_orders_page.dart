import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/checkout_providers.dart';

class CompletedOrdersPage extends ConsumerWidget {
  const CompletedOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(completedOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('\u{0637}\u{0644}\u{0628}\u{0627}\u{062a}\u{064a}'),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '\u{062a}\u{0639}\u{0630}\u{0631} \u{062a}\u{062d}\u{0645}\u{064a}\u{0644} \u{0627}\u{0644}\u{0637}\u{0644}\u{0628}\u{0627}\u{062a}:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                '\u{0644}\u{0627} \u{062a}\u{0648}\u{062c}\u{062f} \u{0637}\u{0644}\u{0628}\u{0627}\u{062a} \u{0633}\u{0627}\u{0628}\u{0642}\u{0629}.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_rounded),
                  ),
                  title: Text(
                    '\u{0637}\u{0644}\u{0628} \u{0631}\u{0642}\u{0645} ${order.id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '\u{0627}\u{0644}\u{0625}\u{062c}\u{0645}\u{0627}\u{0644}: ${order.totalAmount.toStringAsFixed(2)} \u{062c}\u{0646}\u{064a}\u{0647}',
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
