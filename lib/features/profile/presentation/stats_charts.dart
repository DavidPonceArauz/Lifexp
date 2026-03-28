import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/autumn_theme.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class StatsData {
  final List<DailyCompletion> weeklyCompletions;
  final List<XpPoint>         xpEvolution;
  final Map<String, int>      categoryBreakdown;
  final List<StreakPoint>     streakHistory;
  final ModuleComparison      moduleComparison;

  const StatsData({
    required this.weeklyCompletions,
    required this.xpEvolution,
    required this.categoryBreakdown,
    required this.streakHistory,
    required this.moduleComparison,
  });
}

class DailyCompletion { final DateTime date; final int count; const DailyCompletion(this.date, this.count); }
class XpPoint         { final DateTime date; final int xp;   const XpPoint(this.date, this.xp); }
class StreakPoint      { final DateTime date; final int streak; const StreakPoint(this.date, this.streak); }
class ModuleComparison {
  final int habits; final int goals; final int todos;
  const ModuleComparison(this.habits, this.goals, this.todos);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final statsProvider = FutureProvider.family<StatsData, ({String userId, int days})>((ref, args) async {
  return StatsChartLoader.load(args.userId, args.days);
});

class StatsChartLoader {
  static Future<StatsData> load(String userId, int days) async {
    final db    = SupabaseConfig.client;
    final since = DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T')[0];

    final results = await Future.wait([
      // 0: habit_logs for completion + streak
      db.from('habit_logs')
          .select('date, completed')
          .eq('user_id', userId)
          .gte('date', since)
          .order('date'),
      // 1: profiles xp snapshots — fallback: just current xp from profiles
      db.from('profiles')
          .select('total_xp')
          .eq('id', userId),
      // 2: habits by category
      db.from('habits')
          .select('category')
          .eq('user_id', userId),
      // 3: goals completed count
      db.from('goals')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'completed'),
      // 4: todos completed count
      db.from('todos')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'done'),
      // 5: all habit_logs for streak history
      db.from('habit_logs')
          .select('date, completed')
          .eq('user_id', userId)
          .eq('completed', true)
          .order('date'),
    ]);

    final habitLogs   = results[0] as List;
    final profile     = (results[1] as List).isNotEmpty ? results[1][0] as Map : <String, dynamic>{};
    final habits      = results[2] as List;
    final goals       = results[3] as List;
    final todos       = results[4] as List;
    final allLogs     = results[5] as List;

    // ── Weekly completions ─────────────────────────────────────────────────
    final Map<String, int> completionMap = {};
    for (final log in habitLogs) {
      if (log['completed'] == true) {
        final d = log['date'] as String;
        completionMap[d] = (completionMap[d] ?? 0) + 1;
      }
    }
    final now = DateTime.now();
    final List<DailyCompletion> daily = List.generate(days, (i) {
      final d = now.subtract(Duration(days: days - 1 - i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return DailyCompletion(d, completionMap[key] ?? 0);
    });

    // ── XP evolution — simulate from total_xp since we may not have history ─
    final totalXp = profile['total_xp'] as int? ?? 0;
    final List<XpPoint> xpPoints = _simulateXpCurve(totalXp, days);

    // ── Category breakdown ─────────────────────────────────────────────────
    final Map<String, int> catMap = {};
    for (final h in habits) {
      final cat = (h['category'] as String?)?.trim().toUpperCase() ?? 'OTRO';
      catMap[cat] = (catMap[cat] ?? 0) + 1;
    }
    if (catMap.isEmpty) catMap['SIN DATOS'] = 1;

    // ── Streak history ─────────────────────────────────────────────────────
    final List<StreakPoint> streakPts = _buildStreakHistory(allLogs, days);

    // ── Module comparison ──────────────────────────────────────────────────
    final module = ModuleComparison(
      habitLogs.where((l) => l['completed'] == true).length,
      goals.length,
      todos.length,
    );

    return StatsData(
      weeklyCompletions: daily,
      xpEvolution: xpPoints,
      categoryBreakdown: catMap,
      streakHistory: streakPts,
      moduleComparison: module,
    );
  }

  static List<XpPoint> _simulateXpCurve(int totalXp, int days) {
    // Approximate a logarithmic growth curve ending at totalXp
    final List<XpPoint> pts = [];
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final t = (i + 1) / days;
      final xp = (totalXp * (t * t)).round();
      pts.add(XpPoint(now.subtract(Duration(days: days - 1 - i)), xp));
    }
    return pts;
  }

  static List<StreakPoint> _buildStreakHistory(List allLogs, int days) {
    final now = DateTime.now();
    final dates = allLogs
        .map((l) => DateTime.tryParse(l['date'] as String? ?? ''))
        .whereType<DateTime>().toSet().toList()..sort();

    // Rebuild daily streak values
    final Map<String, int> streakAtDate = {};
    int current = 0;
    DateTime? prev;
    for (final d in dates) {
      if (prev == null || d.difference(prev).inDays == 1) { current++; }
      else if (d.difference(prev).inDays > 1) { current = 1; }
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      streakAtDate[key] = current;
      prev = d;
    }

    return List.generate(days, (i) {
      final d   = now.subtract(Duration(days: days - 1 - i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return StreakPoint(d, streakAtDate[key] ?? 0);
    });
  }
}

// ── Main widget ───────────────────────────────────────────────────────────────

class StatsChartsSection extends ConsumerStatefulWidget {
  final String userId;
  const StatsChartsSection({super.key, required this.userId});

  @override
  ConsumerState<StatsChartsSection> createState() => _StatsChartsSectionState();
}

class _StatsChartsSectionState extends ConsumerState<StatsChartsSection> {
  int _days = 7;
  int _pieTouchedIndex = -1;

  static const _ranges = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    final c     = context.ac;
    final async = ref.watch(statsProvider((userId: widget.userId, days: _days)));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Range selector
      _buildRangeSelector(c),
      const SizedBox(height: 16),

      async.when(
        loading: () => _buildSkeletons(c),
        error:   (e, stack) { debugPrint('STATS ERROR: $e\n$stack'); return _buildError(c, e); },
        data:    (data) => _buildCharts(c, data),
      ),
    ]);
  }

  // ── Range selector ────────────────────────────────────────────────────────

  Widget _buildRangeSelector(dynamic c) {
    return Row(children: _ranges.map((d) {
      final selected = d == _days;
      return GestureDetector(
        onTap: () => setState(() => _days = d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AutumnColors.accentOrange : c.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AutumnColors.accentOrange : c.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            '${d}d',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: selected ? Colors.white : c.textDisabled,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }).toList());
  }

  // ── Charts ────────────────────────────────────────────────────────────────

  Widget _buildCharts(dynamic c, StatsData data) {
    return Column(children: [
      _buildCard(c, '📊 COMPLETACIÓN DIARIA', _buildBarChart(c, data)),
      const SizedBox(height: 16),
      _buildCard(c, '⚡ EVOLUCIÓN DE XP',     _buildXpLineChart(c, data)),
      const SizedBox(height: 16),
      _buildCard(c, '🔄 RACHA HISTÓRICA',     _buildStreakLineChart(c, data)),
      const SizedBox(height: 16),
      _buildCard(c, '🍩 HÁBITOS POR CATEGORÍA', _buildPieChart(c, data)),
      const SizedBox(height: 16),
      _buildCard(c, '🕸️ MÓDULOS',             _buildRadarChart(c, data)),
    ]);
  }

  Widget _buildCard(dynamic c, String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.pressStart2p(fontSize: 8, color: c.textDisabled)),
        const SizedBox(height: 18),
        chart,
      ]),
    );
  }

  // ── 1. Bar chart — daily completions ─────────────────────────────────────

  Widget _buildBarChart(dynamic c, StatsData data) {
    final spots = data.weeklyCompletions;
    final maxY  = (spots.map((s) => s.count).reduce((a, b) => a > b ? a : b) + 2).toDouble();

    // Show fewer labels depending on range
    final labelStep = _days <= 7 ? 1 : _days <= 30 ? 5 : 15;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 6 ? (maxY / 4).ceilToDouble() : 2,
            getDrawingHorizontalLine: (_) => FlLine(color: c.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 28,
              interval: maxY > 6 ? (maxY / 4).ceilToDouble() : 2,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled),
              ),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= spots.length) return const SizedBox();
                if (i % labelStep != 0 && i != spots.length - 1) return const SizedBox();
                final d = spots[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: GoogleFonts.pressStart2p(fontSize: 5, color: c.textDisabled),
                  ),
                );
              },
            )),
            rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: spots.asMap().entries.map((e) {
            final hasData = e.value.count > 0;
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: e.value.count.toDouble(),
                width: _days <= 7 ? 18 : _days <= 30 ? 8 : 4,
                borderRadius: BorderRadius.circular(4),
                gradient: hasData
                    ? const LinearGradient(
                    colors: [AutumnColors.accentOrange, AutumnColors.accentGold],
                    begin: Alignment.bottomCenter, end: Alignment.topCenter)
                    : null,
                color: hasData ? null : c.divider,
              ),
            ]);
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.bgCard,
              getTooltipItem: (group, _, rod, __) {
                final d = spots[group.x].date;
                return BarTooltipItem(
                  '${d.day}/${d.month}\n',
                  GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled),
                  children: [TextSpan(
                    text: '${rod.toY.toInt()} ✓',
                    style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.accentOrange),
                  )],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── 2. Line chart — XP evolution ─────────────────────────────────────────

  Widget _buildXpLineChart(dynamic c, StatsData data) {
    final pts      = data.xpEvolution;
    final maxXp    = pts.map((p) => p.xp).reduce((a, b) => a > b ? a : b).toDouble();
    final labelStep = _days <= 7 ? 1 : _days <= 30 ? 7 : 20;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0, maxY: maxXp * 1.15,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: maxXp > 0 ? (maxXp / 4).ceilToDouble() : 100,
            getDrawingHorizontalLine: (_) => FlLine(color: c.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 40,
              interval: maxXp > 0 ? (maxXp / 4).ceilToDouble() : 100,
              getTitlesWidget: (v, _) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                style: GoogleFonts.pressStart2p(fontSize: 5, color: c.textDisabled),
              ),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= pts.length) return const SizedBox();
                if (i % labelStep != 0 && i != pts.length - 1) return const SizedBox();
                final d = pts[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.day}/${d.month}',
                      style: GoogleFonts.pressStart2p(fontSize: 5, color: c.textDisabled)),
                );
              },
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: pts.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.xp.toDouble())).toList(),
              isCurved: true, curveSmoothness: 0.35,
              color: AutumnColors.accentGold,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AutumnColors.accentGold.withValues(alpha:0.3), AutumnColors.accentGold.withValues(alpha:0.0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.bgCard,
              getTooltipItems: (spots) => spots.map((s) {
                final d = pts[s.x.toInt()].date;
                return LineTooltipItem(
                  '${d.day}/${d.month}\n',
                  GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled),
                  children: [TextSpan(
                    text: '${s.y.toInt()} XP',
                    style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.accentGold),
                  )],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── 3. Line chart — streak history ───────────────────────────────────────

  Widget _buildStreakLineChart(dynamic c, StatsData data) {
    final pts      = data.streakHistory;
    final maxS     = pts.map((p) => p.streak).reduce((a, b) => a > b ? a : b).toDouble();
    final labelStep = _days <= 7 ? 1 : _days <= 30 ? 7 : 20;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0, maxY: (maxS + 2),
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: maxS > 0 ? (maxS / 4).ceilToDouble() : 2,
            getDrawingHorizontalLine: (_) => FlLine(color: c.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 28,
              interval: maxS > 0 ? (maxS / 4).ceilToDouble() : 2,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled),
              ),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= pts.length) return const SizedBox();
                if (i % labelStep != 0 && i != pts.length - 1) return const SizedBox();
                final d = pts[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.day}/${d.month}',
                      style: GoogleFonts.pressStart2p(fontSize: 5, color: c.textDisabled)),
                );
              },
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: pts.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.streak.toDouble())).toList(),
              isCurved: true, curveSmoothness: 0.2,
              color: AutumnColors.freeze,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) => spot.y > 0,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3, color: AutumnColors.freeze,
                  strokeWidth: 1.5, strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AutumnColors.freeze.withValues(alpha:0.25), AutumnColors.freeze.withValues(alpha:0.0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.bgCard,
              getTooltipItems: (spots) => spots.map((s) {
                final d = pts[s.x.toInt()].date;
                return LineTooltipItem(
                  '${d.day}/${d.month}\n',
                  GoogleFonts.pressStart2p(fontSize: 6, color: c.textDisabled),
                  children: [TextSpan(
                    text: '🔥 ${s.y.toInt()} días',
                    style: GoogleFonts.pressStart2p(fontSize: 8, color: AutumnColors.freeze),
                  )],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. Pie chart — category breakdown ────────────────────────────────────

  static const _catColors = [
    AutumnColors.accentOrange,
    AutumnColors.accentGold,
    AutumnColors.mossGreen,
    AutumnColors.freeze,
    Color(0xFFE07BB5),
    Color(0xFF9B7DE8),
    Color(0xFF5BC4C0),
  ];

  Widget _buildPieChart(dynamic c, StatsData data) {
    final cats   = data.categoryBreakdown.entries.toList();
    final total  = cats.fold<int>(0, (s, e) => s + e.value);

    return Column(children: [
      SizedBox(
        height: 180,
        child: PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 48,
            pieTouchData: PieTouchData(
              touchCallback: (_, response) {
                setState(() {
                  if (response == null || response.touchedSection == null) {
                    _pieTouchedIndex = -1;
                  } else {
                    _pieTouchedIndex = response.touchedSection!.touchedSectionIndex;
                  }
                });
              },
            ),
            sections: cats.asMap().entries.map((e) {
              final touched = e.key == _pieTouchedIndex;
              final color   = _catColors[e.key % _catColors.length];
              final pct     = total > 0 ? (e.value.value / total * 100).round() : 0;
              return PieChartSectionData(
                value: e.value.value.toDouble(),
                color: color,
                radius: touched ? 68 : 55,
                title: touched ? '$pct%' : '',
                titleStyle: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                badgeWidget: touched ? null : null,
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Legend
      Wrap(spacing: 12, runSpacing: 8, children: cats.asMap().entries.map((e) {
        final color = _catColors[e.key % _catColors.length];
        final pct   = total > 0 ? (e.value.value / total * 100).round() : 0;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text('${e.value.key} ($pct%)',
              style: GoogleFonts.pressStart2p(fontSize: 6, color: c.textSecondary)),
        ]);
      }).toList()),
    ]);
  }

  // ── 5. Radar chart — module comparison ───────────────────────────────────

  Widget _buildRadarChart(dynamic c, StatsData data) {
    final m       = data.moduleComparison;
    final maxVal  = [m.habits, m.goals * 10, m.todos].reduce((a, b) => a > b ? a : b).toDouble();
    final scale   = maxVal > 0 ? maxVal : 1.0;

    // Normalize to 0–5 scale for display
    final hNorm  = (m.habits   / scale * 5).clamp(0.0, 5.0);
    final gNorm  = (m.goals * 10 / scale * 5).clamp(0.0, 5.0);
    final tNorm  = (m.todos    / scale * 5).clamp(0.0, 5.0);

    return SizedBox(
      height: 220,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: GoogleFonts.pressStart2p(fontSize: 0, color: Colors.transparent),
          tickBorderData: BorderSide(color: c.divider, width: 1),
          gridBorderData: BorderSide(color: c.divider.withValues(alpha:0.5), width: 1),
          radarBorderData: BorderSide(color: c.divider, width: 1.5),
          titleTextStyle: GoogleFonts.pressStart2p(fontSize: 7, color: c.textSecondary),
          titlePositionPercentageOffset: 0.15,
          getTitle: (index, _) {
            switch (index) {
              case 0: return RadarChartTitle(text: 'HÁBITOS\n${m.habits}');
              case 1: return RadarChartTitle(text: 'METAS\n${m.goals}');
              case 2: return RadarChartTitle(text: 'TAREAS\n${m.todos}');
              default: return const RadarChartTitle(text: '');
            }
          },
          dataSets: [
            RadarDataSet(
              fillColor: AutumnColors.accentOrange.withValues(alpha:0.2),
              borderColor: AutumnColors.accentOrange,
              borderWidth: 2,
              entryRadius: 4,
              dataEntries: [
                RadarEntry(value: hNorm),
                RadarEntry(value: gNorm),
                RadarEntry(value: tNorm),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Skeleton loader ───────────────────────────────────────────────────────

  Widget _buildSkeletons(dynamic c) {
    return Column(children: List.generate(5, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.divider),
        ),
        child: Center(child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AutumnColors.accentOrange.withValues(alpha:0.5)),
        )),
      ),
    )));
  }

  Widget _buildError(dynamic c, Object e) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: c.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.divider)),
      child: Column(children: [
        const Text('📊', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 12),
        Text('Error cargando estadísticas',
            style: GoogleFonts.pressStart2p(fontSize: 7, color: c.textDisabled), textAlign: TextAlign.center),
      ]),
    );
  }
}