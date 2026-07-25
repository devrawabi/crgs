import 'package:flutter_riverpod/flutter_riverpod.dart';

final sidebarOpenProvider = StateProvider<bool>((ref) => false);

void toggleSidebar(WidgetRef ref) {
  ref.read(sidebarOpenProvider.notifier).update((open) => !open);
}

void closeSidebar(WidgetRef ref) {
  ref.read(sidebarOpenProvider.notifier).state = false;
}
