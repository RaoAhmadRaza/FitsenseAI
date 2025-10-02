import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/workouts/workouts_cubit.dart';
import '../../../core/models/workout_plan.dart';
import '../../presentation/widgets/colors.dart';

// Real Plan Browser implementation replacing placeholder.
class PlanBrowserScreen extends StatefulWidget {
  const PlanBrowserScreen({super.key});
  @override
  State<PlanBrowserScreen> createState() => _PlanBrowserScreenState();
}

class _PlanBrowserScreenState extends State<PlanBrowserScreen> {
  String _query = '';
  String _levelFilter = 'All';
  bool _grid = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plans'),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<WorkoutsCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(92),
          child: _SearchAndFilterBar(
            controller: _searchCtrl,
            onQueryChanged: (v) =>
                setState(() => _query = v.trim().toLowerCase()),
            level: _levelFilter,
            onLevelChanged: (v) => setState(() => _levelFilter = v),
          ),
        ),
      ),
      body: BlocBuilder<WorkoutsCubit, WorkoutsState>(
        builder: (context, state) {
          switch (state.status) {
            case WorkoutsStatus.loading:
              return const _CenteredLoader();
            case WorkoutsStatus.error:
              return _ErrorState(
                message: state.errorMessage ?? 'Failed to load plans',
                onRetry: () => context.read<WorkoutsCubit>().load(),
              );
            case WorkoutsStatus.ready:
              if (state.plans.isEmpty) {
                return _EmptyPlans(
                  onCreate: () => _showCreatePlanDialog(context),
                );
              }
              final filtered = state.plans.where((p) {
                final matchesQuery =
                    _query.isEmpty || p.name.toLowerCase().contains(_query);
                final matchesLevel =
                    _levelFilter == 'All' || p.level == _levelFilter;
                return matchesQuery && matchesLevel;
              }).toList();
              if (filtered.isEmpty) {
                return _NoResults(
                  onClear: () {
                    setState(() {
                      _query = '';
                      _levelFilter = 'All';
                      _searchCtrl.clear();
                    });
                  },
                );
              }
              return _grid
                  ? _PlansGrid(plans: filtered)
                  : _PlansList(plans: filtered);
            case WorkoutsStatus.initial:
              return const SizedBox.shrink();
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_plan',
        onPressed: () => _showCreatePlanDialog(context),
        label: const Text('New Plan', style: TextStyle(fontFamily: 'Sora')),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.vibrantRed,
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Plan'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Plan Name'),
          autofocus: true,
          onSubmitted: (_) => _submit(nameCtrl, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _submit(nameCtrl, context),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _submit(TextEditingController ctrl, BuildContext context) async {
    final text = ctrl.text;
    Navigator.pop(context);
    await context.read<WorkoutsCubit>().createPlan(name: text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plan created')));
  }
}

class _PlansList extends StatelessWidget {
  final List<WorkoutPlan> plans;
  const _PlansList({required this.plans});
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    itemCount: plans.length,
    separatorBuilder: (_, __) => const SizedBox(height: 14),
    itemBuilder: (_, i) => _PlanCard(plan: plans[i]),
  );
}

class _PlansGrid extends StatelessWidget {
  final List<WorkoutPlan> plans;
  const _PlansGrid({required this.plans});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: plans.length,
      itemBuilder: (_, i) => _PlanCard(compact: true, plan: plans[i]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  final bool compact;
  const _PlanCard({required this.plan, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final exerciseCount = plan.exercises.length;
    final equipmentStr = plan.equipment.join(', ');
    final thumb = plan.exercises.isNotEmpty
        ? plan.exercises.first.imagePath
        : null;
    final semanticsLabel =
        'Plan ${plan.name}, $exerciseCount '
        'exercise${exerciseCount == 1 ? '' : 's'}, level ${plan.level}';
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed('/plans/${plan.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildContent(
                      context,
                      thumb,
                      exerciseCount,
                      equipmentStr,
                      compact: true,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlanThumbnail(path: thumb),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildContent(
                            context,
                            thumb,
                            exerciseCount,
                            equipmentStr,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _showPlanMenu(BuildContext context, WorkoutPlan plan) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, plan);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Exercise (stub)'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exercise CRUD coming soon')),
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WorkoutPlan plan) {
    final ctrl = TextEditingController(text: plan.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Plan'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (_) => _commitRename(context, plan, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _commitRename(context, plan, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _commitRename(
    BuildContext context,
    WorkoutPlan plan,
    String name,
  ) async {
    Navigator.pop(context);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == plan.name) return;
    final updated = plan.copyWith(name: trimmed);
    // Proper update using cubit's updatePlan
    await context.read<WorkoutsCubit>().updatePlan(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan renamed')));
    }
  }

  List<Widget> _buildContent(
    BuildContext context,
    String? thumb,
    int exerciseCount,
    String equipmentStr, {
    bool compact = false,
  }) {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              plan.name,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _LevelBadge(level: plan.level),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        '$exerciseCount exercises • ${plan.durationDisplay}',
        style: TextStyle(
          fontFamily: 'Sora',
          fontSize: compact ? 11 : 12,
          color: Colors.grey.shade700,
        ),
      ),
      if (equipmentStr.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          equipmentStr,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: compact ? 10 : 11,
            color: Colors.grey.shade600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.fitnessBlue,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 14,
                  vertical: 8,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushNamed('/plans/${plan.id}');
              },
              child: const Text('Start', style: TextStyle(fontFamily: 'Sora')),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'More',
            onPressed: () => _showPlanMenu(context, plan),
            icon: const Icon(Icons.more_horiz, size: 20),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    ];
  }
}

class _PlanThumbnail extends StatelessWidget {
  final String? path;
  const _PlanThumbnail({this.path});
  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: 70,
        height: 70,
        color: Colors.grey.shade200,
        child: path == null
            ? const Icon(Icons.fitness_center, size: 32, color: Colors.grey)
            : Image.asset(
                path!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fitness_center,
                  size: 32,
                  color: Colors.grey,
                ),
              ),
      ),
    );
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final String level;
  final ValueChanged<String> onLevelChanged;
  const _SearchAndFilterBar({
    required this.controller,
    required this.onQueryChanged,
    required this.level,
    required this.onLevelChanged,
  });

  static const _levels = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
    'Custom',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search plans...',
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final l = _levels[i];
                final sel = l == level;
                return GestureDetector(
                  onTap: () => onLevelChanged(l),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.vibrantRed : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l,
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _levels.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final VoidCallback onClear;
  const _NoResults({required this.onClear});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No matching plans',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting search or filters.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontFamily: 'Sora',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onClear,
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.vibrantRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level,
        style: const TextStyle(
          fontFamily: 'Sora',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.vibrantRed,
        ),
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Sora'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyPlans({required this.onCreate});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_view_week, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Plans Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a custom workout plan to get started.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontFamily: 'Sora',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

// (Removed unused date format helper to satisfy linter.)
