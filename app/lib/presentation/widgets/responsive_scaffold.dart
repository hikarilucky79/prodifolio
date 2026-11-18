import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/portfolio_providers.dart';
import '../screens/about_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/home_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/stats_screen.dart';

class ResponsiveScaffold extends ConsumerWidget {
  const ResponsiveScaffold({super.key});

  static const _tabs = <_NavTab>[
    _NavTab('01', 'Início', Icons.dashboard_outlined, Icons.dashboard),
    _NavTab('02', 'Projetos', Icons.code_outlined, Icons.code),
    _NavTab('03', 'Estatísticas', Icons.bar_chart_outlined, Icons.bar_chart),
    _NavTab('04', 'Trajetória', Icons.timeline_outlined, Icons.timeline),
    _NavTab('05', 'Contato', Icons.mail_outline, Icons.mail),
  ];

  static const _screens = <Widget>[
    HomeScreen(),
    ProjectsScreen(),
    StatsScreen(),
    AboutScreen(),
    ContactScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final folio = context.folio;

    final feedAsync = ref.watch(projectsFeedProvider);
    final statsAsync = ref.watch(statsProvider);

    final repoCount = feedAsync.valueOrNull?.projects.length;
    final commitCount = statsAsync.valueOrNull?.activity.fold<int>(
      0,
      (sum, point) => sum + point.commits,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final isDesktop = width >= 1024;

        final themeButton = Semantics(
          button: true,
          label: isDark ? 'Ativar tema claro' : 'Ativar tema escuro',
          child: InkWell(
            onTap: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: folio.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 15,
                    color: folio.ink,
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      isDark ? 'PAPEL OSSO' : 'OBSIDIAN',
                      style: context.monoStyle(size: 11, color: folio.ink),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        final statusLabel = feedAsync.when(
          data: (feed) =>
              '${feed.projects.length} ${feed.projects.length == 1 ? 'REPO' : 'REPOS'} · @${feed.owner.username.toUpperCase()}',
          loading: () => 'SINCRONIZANDO GITHUB...',
          error: (_, _) => 'API INDISPONÍVEL',
        );

        final topBar = Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28),
          decoration: BoxDecoration(
            color: folio.canvas,
            border: Border(bottom: BorderSide(color: folio.hairline)),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Ir para o início do prodifolio',
                child: InkWell(
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        color: folio.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'PRODIFOLIO',
                        style: context.monoStyle(
                          size: 12,
                          weight: FontWeight.w500,
                          color: folio.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: isMobile
                    ? const SizedBox.shrink()
                    : Text(
                        statusLabel,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.monoStyle(size: 11),
                      ),
              ),
              themeButton,
            ],
          ),
        );

        final body = IndexedStack(
          index: selectedIndex,
          children: _screens,
        );

        return Scaffold(
          backgroundColor: folio.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                topBar,
                Expanded(
                  child: isMobile
                      ? body
                      : Row(
                          children: [
                            if (isDesktop)
                              _EditorialRail(
                                tabs: _tabs,
                                selectedIndex: selectedIndex,
                                repoCount: repoCount,
                                commitCount: commitCount,
                                onSelect: (i) =>
                                    ref.read(selectedTabProvider.notifier).state = i,
                              )
                            else
                              _CompactRail(
                                tabs: _tabs,
                                selectedIndex: selectedIndex,
                                onSelect: (i) =>
                                    ref.read(selectedTabProvider.notifier).state = i,
                              ),
                            Expanded(child: body),
                          ],
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isMobile
              ? Container(
                  decoration: BoxDecoration(
                    color: folio.canvas,
                    border: Border(top: BorderSide(color: folio.hairline)),
                  ),
                  child: NavigationBar(
                    selectedIndex: selectedIndex,
                    height: 64,
                    onDestinationSelected: (index) {
                      ref.read(selectedTabProvider.notifier).state = index;
                    },
                    destinations: [
                      for (final tab in _tabs)
                        NavigationDestination(
                          icon: Icon(tab.icon, size: 20, color: folio.inkMuted),
                          selectedIcon: Icon(tab.selectedIcon, size: 20, color: folio.accent),
                          label: tab.label,
                        ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _EditorialRail extends StatelessWidget {
  const _EditorialRail({
    required this.tabs,
    required this.selectedIndex,
    required this.repoCount,
    required this.commitCount,
    required this.onSelect,
  });

  final List<_NavTab> tabs;
  final int selectedIndex;
  final int? repoCount;
  final int? commitCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: folio.canvas,
        border: Border(right: BorderSide(color: folio.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _RailIndexTile(
              tab: tabs[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: folio.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repoCount != null
                      ? '$repoCount ${repoCount == 1 ? 'repositório público' : 'repositórios públicos'}'
                      : 'Carregando repositórios',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (commitCount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$commitCount commits (14d)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '@hikarilucky79',
                  style: context.monoStyle(size: 11, color: folio.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailIndexTile extends StatelessWidget {
  const _RailIndexTile({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? folio.accent : folio.hairline,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? folio.ink : folio.inkMuted,
                  ),
                ),
              ),
              Text(
                tab.code,
                style: context.monoStyle(
                  size: 11,
                  color: selected ? folio.accent : folio.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactRail extends StatelessWidget {
  const _CompactRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: folio.canvas,
        border: Border(right: BorderSide(color: folio.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Semantics(
              button: true,
              selected: i == selectedIndex,
              label: tabs[i].label,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        width: 1,
                        color: i == selectedIndex ? folio.accent : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        i == selectedIndex ? tabs[i].selectedIcon : tabs[i].icon,
                        size: 20,
                        color: i == selectedIndex ? folio.ink : folio.inkMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabs[i].code,
                        style: context.monoStyle(
                          size: 10,
                          color: i == selectedIndex ? folio.accent : folio.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavTab {
  const _NavTab(this.code, this.label, this.icon, this.selectedIcon);

  final String code;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
