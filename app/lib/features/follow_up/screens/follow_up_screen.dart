import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/badges/priority_badge.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../tasks/providers/task_provider.dart';

class FollowUpScreen extends ConsumerStatefulWidget {
  const FollowUpScreen({super.key});

  @override
  ConsumerState<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends ConsumerState<FollowUpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TaskPriority _priority = TaskPriority.medium;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final followUps = ref.watch(followUpsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-ups'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarView(followUps),
          _buildTimelineView(followUps),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(AppIcons.add),
      ),
    );
  }

  Widget _buildCalendarView(List<FollowUpModel> followUps) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
            onDateChanged: (d) => setState(() => _selectedDate = d),
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'Follow-ups on ${DateFormat('dd MMM').format(_selectedDate)}'),
        ...followUps.map((f) => _FollowUpCard(followUp: f)),
      ],
    );
  }

  Widget _buildTimelineView(List<FollowUpModel> followUps) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: followUps.length,
      itemBuilder: (_, i) {
        final f = followUps[i];
        return TimelineItem(
          title: f.customerName,
          subtitle: f.notes,
          time: '${DateFormat('dd MMM').format(f.date)} • ${f.time.format(context)}',
          isFirst: i == 0,
          isLast: i == followUps.length - 1,
          color: _statusColor(f.status),
        );
      },
    );
  }

  Color _statusColor(FollowUpStatus status) {
    return switch (status) {
      FollowUpStatus.pending => AppColors.followUpBlue,
      FollowUpStatus.completed => AppColors.successGreen,
      FollowUpStatus.missed => AppColors.missingRed,
    };
  }

  void _showCreateDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create Follow-up', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            AppTextField(controller: _notesController, label: 'Notes', maxLines: 3),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: TaskPriority.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? TaskPriority.medium),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Follow-up created')),
                );
              },
              child: const Text('Save Follow-up'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.followUp});

  final FollowUpModel followUp;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (followUp.status) {
      FollowUpStatus.pending => AppColors.followUpBlue,
      FollowUpStatus.completed => AppColors.successGreen,
      FollowUpStatus.missed => AppColors.missingRed,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(followUp.customerName),
        subtitle: Text(followUp.notes),
        trailing: StatusBadge(
          label: followUp.status.name,
          color: statusColor,
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Text(
            followUp.time.format(context).split(' ').first,
            style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
