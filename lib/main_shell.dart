import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/autumn_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/goals/presentation/goals_screen.dart';
import 'features/habits/presentation/habits_screen.dart';
import 'features/habits/presentation/providers/habits_provider.dart';
import 'features/todos/presentation/todo_screen.dart';
import 'features/todos/presentation/providers/todos_provider.dart';
import 'features/goals/presentation/providers/goals_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final String userId;
  final int initialTab;
  const MainShell({super.key, required this.userId, this.initialTab = 0});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final PageController _pageController;
  int _currentIndex = 0;

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_rounded,          'HOME',   AutumnColors.accentOrange),
    _NavItem(Icons.flag_rounded,          'GOALS',  AutumnColors.accentOrange),
    _NavItem(Icons.local_fire_department, 'HABITS', AutumnColors.mossGreen),
    _NavItem(Icons.check_circle_outline,  'TODO',   AutumnColors.accentOrange),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _pageController = PageController(initialPage: widget.initialTab);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userIdProvider.notifier).state = widget.userId;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic, // ← más suave que easeInOut
    );
  }

  void _onPageChanged(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        // BouncingScrollPhysics da transición nativa fluida en Android e iOS
        // ClampingScrollPhysics (default en Android) corta el gesto a veces
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          HomeScreen(userId: widget.userId, onNavigate: _onTabTapped),
          GoalsScreen(userId: widget.userId),
          HabitsScreen(userId: widget.userId),
          TodoScreen(userId: widget.userId),
        ],
      ),
      bottomNavigationBar: _AutumnBottomNav(
        currentIndex: _currentIndex,
        items: _items,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color activeColor;
  const _NavItem(this.icon, this.label, this.activeColor);
}

class _AutumnBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  const _AutumnBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Container(
      decoration: BoxDecoration(
        color: c.bgCard,
        border: const Border(top: BorderSide(color: AutumnColors.accentOrange, width: 2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: List.generate(items.length, (i) {
            final item   = items[i];
            final active = i == currentIndex;
            return Expanded(child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3, width: active ? 28 : 0,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: active ? item.activeColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Icon(item.icon, size: 22,
                      color: active ? item.activeColor : c.textDisabled),
                  const SizedBox(height: 3),
                  Text(item.label, style: GoogleFonts.pressStart2p(
                    fontSize: 6,
                    color: active ? item.activeColor : c.textDisabled,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  )),
                ]),
              ),
            ));
          })),
        ),
      ),
    );
  }
}