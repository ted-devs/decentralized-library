import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import '../../bookshelf/presentation/bookshelf_screen.dart';
import '../../communities/presentation/communities_hub_screen.dart';
import '../../library/presentation/requests_hub_screen.dart';
import '../../notifications/application/badge_service.dart';

/// A Notifier to manage the navigation state.
/// This matches the recommended pattern for Riverpod 3.0+.
final navigationIndexProvider = NotifierProvider<NavigationIndex, int>(() {
  return NavigationIndex();
});

class NavigationIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) {
    state = index;
  }
}

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    final screens = [
      const HomeScreen(),
      const BookshelfScreen(),
      const CommunitiesHubScreen(),
      const RequestsHubScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(navigationIndexProvider.notifier).set(index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Bookshelf',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: ref.watch(hasPendingMembershipsProvider).value ?? false,
              child: const Icon(Icons.people_outline),
            ),
            selectedIcon: const Icon(Icons.people),
            label: 'Hub',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: ref.watch(hasIncomingRequestsProvider).value ?? false,
              child: const Icon(Icons.request_page_outlined),
            ),
            selectedIcon: const Icon(Icons.request_page),
            label: 'Requests',
          ),
        ],
      ),
    );
  }
}
