import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/widgets/colors.dart';
import '../../../logic/workouts/workouts_cubit.dart';
import '../../../core/models/workout_plan.dart';

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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            icon: Icon(
              _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: Colors.black,
              size: 22,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _grid = !_grid);
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.black,
              size: 22,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.read<WorkoutsCubit>().load();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(148),
          child: Container(
            color: const Color(0xFFF9FAFB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    'Browse Plans',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                _IOSSearchAndFilterBar(
                  controller: _searchCtrl,
                  onQueryChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  level: _levelFilter,
                  onLevelChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _levelFilter = v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFF9FAFB),
        child: BlocBuilder<WorkoutsCubit, WorkoutsState>(
          builder: (context, state) {
            switch (state.status) {
              case WorkoutsStatus.loading:
                return const _CenteredLoader();
              case WorkoutsStatus.error:
                return _ErrorState(
                  message: state.errorMessage ?? 'Failed to load plans',
                  onRetry: () {
                    HapticFeedback.lightImpact();
                    context.read<WorkoutsCubit>().load();
                  },
                );
              case WorkoutsStatus.ready:
                if (state.plans.isEmpty) {
                  return _EmptyPlans(
                    onCreate: () {
                      HapticFeedback.mediumImpact();
                      _showCreatePlanDialog(context);
                    },
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
                      HapticFeedback.lightImpact();
                      setState(() {
                        _query = '';
                        _levelFilter = 'All';
                        _searchCtrl.clear();
                      });
                    },
                  );
                }
                return AnimatedCrossFade(
                  firstChild: _PlansList(
                    key: const ValueKey('list'),
                    plans: filtered,
                  ),
                  secondChild: _PlansGrid(
                    key: const ValueKey('grid'),
                    plans: filtered,
                  ),
                  crossFadeState: _grid
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 280),
                  firstCurve: Curves.easeInOutCubicEmphasized,
                  secondCurve: Curves.easeInOutCubicEmphasized,
                  sizeCurve: Curves.easeInOutCubicEmphasized,
                );
              case WorkoutsStatus.initial:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
      floatingActionButton: _FrostedFab(
        label: 'New Plan',
        icon: Icons.add_rounded,
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showCreatePlanDialog(context);
        },
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
  const _PlansList({super.key, required this.plans});
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
  const _PlansGrid({super.key, required this.plans});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: plans.length,
      itemBuilder: (_, i) => _PlanCard(compact: true, plan: plans[i]),
    );
  }
}

class _PlanCard extends StatefulWidget {
  final WorkoutPlan plan;
  final bool compact;
  const _PlanCard({required this.plan, this.compact = false});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final exerciseCount = widget.plan.exercises.length;
    final equipment = widget.plan.equipment;
    final thumb = widget.plan.exercises.isNotEmpty
        ? widget.plan.exercises.first.imagePath
        : null;
    final semanticsLabel =
        'Plan ${widget.plan.name}, $exerciseCount '
        'exercise${exerciseCount == 1 ? '' : 's'}, level ${widget.plan.level}';
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pushNamed('/plans/${widget.plan.id}');
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          scale: _pressed ? 0.98 : 1,
          child: Container(
            constraints: widget.compact
                ? const BoxConstraints(minHeight: 220)
                : null,
            decoration: BoxDecoration(
              // Subtle inner gloss
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFFAFAFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 6),
                  blurRadius: 12,
                ),
                if (_pressed)
                  BoxShadow(
                    color: AppColors.vibrantRed.withOpacity(0.15),
                    offset: const Offset(0, 0),
                    blurRadius: 6,
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: widget.compact
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: _PlanThumbnail(path: thumb),
                        ),
                        const SizedBox(height: 12),
                        ..._buildContent(
                          context,
                          thumb,
                          exerciseCount,
                          equipment,
                          compact: true,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'thumb_${widget.plan.id}',
                          child: _PlanThumbnail(path: thumb),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildContent(
                              context,
                              thumb,
                              exerciseCount,
                              equipment,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPlanMenu(BuildContext context, WorkoutPlan plan) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
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
                      const SnackBar(
                        content: Text('Exercise CRUD coming soon'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
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
    List<String> equipment, {
    bool compact = false,
  }) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: 'title_${widget.plan.id}',
              flightShuttleBuilder: (context, animation, direction, from, to) {
                return FadeTransition(opacity: animation, child: to.widget);
              },
              child: Text(
                widget.plan.name,
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _LevelChip(label: widget.plan.level),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '$exerciseCount exercises • ${widget.plan.durationDisplay.isEmpty ? '--' : widget.plan.durationDisplay}',
        style: const TextStyle(
          fontFamily: 'SF Pro Text',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF666666),
        ),
      ),
      if (equipment.isNotEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 28,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in equipment) ...[
                  _MetaChip(label: e),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.vibrantRed,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 18,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pushNamed('/plans/${widget.plan.id}');
              },
              child: const Text(
                'Start Plan',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'More',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showPlanMenu(context, widget.plan);
            },
            icon: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: 18,
                  color: Colors.black54,
                ),
              ),
            ),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(4),
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

class _IOSSearchAndFilterBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final String level;
  final ValueChanged<String> onLevelChanged;
  const _IOSSearchAndFilterBar({
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
  State<_IOSSearchAndFilterBar> createState() => _IOSSearchAndFilterBarState();
}

class _IOSSearchAndFilterBarState extends State<_IOSSearchAndFilterBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // Rebuild to show/hide clear button
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoTextField(
            controller: widget.controller,
            onChanged: widget.onQueryChanged,
            placeholder: 'Search plans…',
            placeholderStyle: const TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
            style: const TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                CupertinoIcons.search,
                size: 18,
                color: Color(0xFF8E8E93),
              ),
            ),
            suffix: widget.controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      widget.controller.clear();
                      widget.onQueryChanged('');
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 18,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            clearButtonMode: OverlayVisibilityMode.never,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final l = _IOSSearchAndFilterBar._levels[i];
              final sel = l == widget.level;
              return _FilterChip(
                label: l,
                selected: sel,
                onTap: () => widget.onLevelChanged(l),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _IOSSearchAndFilterBar._levels.length,
          ),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.black.withOpacity(0.05)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: selected ? 1.05 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors
                      .vibrantRed // vibrant red
                : const Color(0xFFE5E5EA), // default gray
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
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
          const Icon(
            Icons.search_off_rounded,
            size: 54,
            color: Color(0xFF8E8E93),
          ),
          const SizedBox(height: 16),
          const Text(
            'No matching plans',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting search or filters.',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontFamily: 'SF Pro Text',
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onClear,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.vibrantRed,
              elevation: 0,
              side: const BorderSide(color: AppColors.vibrantRed, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Clear Filters',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Neutral metadata chip similar to _planMetaChip in app.dart
class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'SF Pro Text',
          fontWeight: FontWeight.w500,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

// Slightly accented level chip
class _LevelChip extends StatelessWidget {
  final String label;
  const _LevelChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.vibrantRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'SF Pro Text',
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
      const Center(child: CupertinoActivityIndicator(radius: 14));
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
            style: const TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.vibrantRed,
              elevation: 0,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
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
            const Icon(
              Icons.calendar_view_week_rounded,
              size: 60,
              color: Color(0xFF8E8E93),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Plans Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a custom workout plan to get started.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E93),
                fontFamily: 'SF Pro Text',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Create Plan',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.vibrantRed,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrostedFab extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _FrostedFab({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_FrostedFab> createState() => _FrostedFabState();
}

class _FrostedFabState extends State<_FrostedFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.95 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _pressed ? 0.9 : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.vibrantRed,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// (Removed unused date format helper to satisfy linter.)
