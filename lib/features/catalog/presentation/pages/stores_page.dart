import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/store.dart';
import '../providers/catalog_providers.dart';
import 'store_page.dart';

class StoresPage extends ConsumerWidget {
  final String categoryId;
  final String categoryName;

  const StoresPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(
      activeStoresByCategoryProvider(categoryId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7FAF9),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          categoryName,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF19352D),
          ),
        ),
        leading: IconButton(
          tooltip: '\u0627\u0644\u0631\u062c\u0648\u0639',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF19352D),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: storesAsync.when(
        loading: () => const _LoadingStoresView(),
        error: (error, stackTrace) => _ErrorView(
          error: error,
          onRetry: () {
            ref.invalidate(
              activeStoresByCategoryProvider(categoryId),
            );
          },
        ),
        data: (stores) {
          if (stores.isEmpty) {
            return const _EmptyStoresView();
          }

          return RefreshIndicator(
            color: const Color(0xFF4E9F8A),
            backgroundColor: Colors.white,
            onRefresh: () async {
              ref.invalidate(
                activeStoresByCategoryProvider(categoryId),
              );
              await ref.read(
                activeStoresByCategoryProvider(categoryId).future,
              );
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _CategoryHero(
                    categoryName: categoryName,
                    storeCount: stores.length,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                  sliver: SliverList.separated(
                    itemCount: stores.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final store = stores[index];

                      return _StoreCard(
                        store: store,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StorePage(
                                storeId: store.id,
                                storeName: store.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryHero extends StatelessWidget {
  final String categoryName;
  final int storeCount;

  const _CategoryHero({
    required this.categoryName,
    required this.storeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFE8F6F1),
              Color(0xFFF2F8FC),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFDCECE7),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A23443B),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 30,
                color: Color(0xFF4E9F8A),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u0627\u0644\u0645\u062a\u0627\u062c\u0631 \u0627\u0644\u0645\u062a\u0627\u062d\u0629',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF658078),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF19352D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$storeCount \u0645\u062a\u062c\u0631 \u0645\u062a\u0627\u062d \u0644\u0644\u0637\u0644\u0628',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF71857F),
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

class _StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        store.description != null &&
        store.description!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: const Color(0x124E9F8A),
        highlightColor: const Color(0x084E9F8A),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE3ECE9),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0B203D35),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              _StoreLogo(store: store),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF19352D),
                      ),
                    ),
                    if (hasDescription) ...[
                      const SizedBox(height: 6),
                      Text(
                        store.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          height: 1.35,
                          fontSize: 13,
                          color: Color(0xFF71857F),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 14,
                                color: Color(0xFF4E9F8A),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '\u0645\u062a\u0627\u062d \u0644\u0644\u0637\u0644\u0628',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF397D6C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F7F5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0xFF4E9F8A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreLogo extends StatelessWidget {
  final Store store;

  const _StoreLogo({
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    const size = 76.0;

    final hasLogo =
        store.logoUrl != null &&
        store.logoUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6F4),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE0ECE8),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: hasLogo
            ? Image.network(
                store.logoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _StoreLogoFallback(),
              )
            : const _StoreLogoFallback(),
      ),
    );
  }
}

class _StoreLogoFallback extends StatelessWidget {
  const _StoreLogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.storefront_rounded,
        size: 34,
        color: Color(0xFF78A99B),
      ),
    );
  }
}

class _LoadingStoresView extends StatelessWidget {
  const _LoadingStoresView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF4E9F8A),
      ),
    );
  }
}

class _EmptyStoresView extends StatelessWidget {
  const _EmptyStoresView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFE1EBE8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF6F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.store_mall_directory_outlined,
                  size: 42,
                  color: Color(0xFF4E9F8A),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u062a\u0627\u062c\u0631 \u0645\u062a\u0627\u062d\u0629 \u062d\u0627\u0644\u064a\u064b\u0627',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF19352D),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '\u0633\u0646\u0642\u0648\u0645 \u0628\u0625\u0638\u0647\u0627\u0631 \u0627\u0644\u0645\u062a\u0627\u062c\u0631 \u0647\u0646\u0627 \u0645\u062c\u0631\u062f \u062a\u0648\u0641\u0631\u0647\u0627.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.45,
                  fontSize: 13,
                  color: Color(0xFF71857F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE4EBE9),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 50,
                color: Color(0xFF8A9B95),
              ),
              const SizedBox(height: 14),
              const Text(
                '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u062a\u0627\u062c\u0631',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF19352D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF71857F),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4E9F8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  '\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}