import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../Core/settings_provider.dart';
import 'goal_model.dart';
import 'goal_provider.dart';
import 'add_goal_screen.dart';
import '../../shared/widgets/app_fab.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = Provider.of<SettingsProvider>(context).currency;
    final goalProvider = Provider.of<GoalProvider>(context);
    final format = NumberFormat('#,##0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: goalProvider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (goalProvider.goals.isNotEmpty) ...[
                  _buildSummaryChart(theme, format, currency, goalProvider),
                  const SizedBox(height: 32),
                ],
                if (goalProvider.goals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.track_changes_rounded, size: 80, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          const Text('No goals set yet. Start saving today!', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ...goalProvider.goals.map((goal) => _buildGoalCard(goal, theme, format, currency)),
                const SizedBox(height: 100),
              ],
            ),
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AppFab(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddGoalScreen())),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        height: 60,
        color: theme.colorScheme.surface,
        child: Container(),
      ),
    );
  }

  Widget _buildSummaryChart(ThemeData theme, NumberFormat format, String currency, GoalProvider provider) {
    double totalTarget = provider.getTotalTarget();
    double totalSaved = provider.getTotalSaved();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120, height: 120,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: totalSaved, 
                    color: theme.colorScheme.primary, 
                    radius: 20, 
                    showTitle: false
                  ),
                  PieChartSectionData(
                    value: (totalTarget - totalSaved).clamp(0, double.infinity), 
                    color: theme.colorScheme.outline.withOpacity(0.3), 
                    radius: 15, 
                    showTitle: false
                  ),
                ],
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL SAVED', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                Text('$currency ${format.format(totalSaved)}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Target: $currency ${format.format(totalTarget)}', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal, ThemeData theme, NumberFormat format, String currency) {
    double percent = goal.targetAmount > 0 ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddGoalScreen(goal: goal))),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${(percent * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: percent,
                backgroundColor: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$currency ${format.format(goal.savedAmount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('of $currency ${format.format(goal.targetAmount)}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
