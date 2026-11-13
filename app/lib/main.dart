import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/portfolio_providers.dart';
import 'presentation/widgets/responsive_scaffold.dart';

void main() {
  runApp(const ProviderScope(child: ProdifolioApp()));
}

class ProdifolioApp extends ConsumerWidget {
  const ProdifolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'prodifolio · hikarilucky79',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const ResponsiveScaffold(),
    );
  }
}
