import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_wallet_mobile/core/theme/app_colors.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:nova_wallet_mobile/features/notifications/presentation/notifier/notification_provider.dart';
import 'package:provider/provider.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return Semantics(
                label: 'Mark all notifications as read',
                button: true,
                child: TextButton.icon(
                  onPressed: provider.unreadCount > 0
                      ? () => provider.markAllAsRead()
                      : null,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Mark Read'),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          final items = provider.filteredNotifications;

          return Column(
            children: [
              // Filter Chips Row
              _buildFilterChips(context, provider),

              // Notification List
              Expanded(
                child: provider.isLoading && provider.notifications.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? _buildEmptyState(context, provider.selectedFilter)
                    : RefreshIndicator(
                        onRefresh: () => provider.loadNotifications(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildNotificationCard(
                              context,
                              item,
                              provider,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    NotificationProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: NotificationFilter.values.map((filter) {
            final isSelected = provider.selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(filter.label),
                selected: isSelected,
                onSelected: (_) => provider.setFilter(filter),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.borderLight,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem item,
    NotificationProvider provider,
  ) {
    final typeConfig = _getTypeConfig(item.type);
    final formattedTime = _formatTimestamp(item.timestamp);

    return Semantics(
      label:
          '${item.title}, Type: ${item.type.displayName}, ${item.message}, $formattedTime${item.isRead ? '' : ', unread'}',
      container: true,
      button: true,
      child: InkWell(
        onTap: () {
          if (!item.isRead) {
            provider.markAsRead(item.id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.isRead
                ? Theme.of(context).cardColor
                : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? AppColors.borderLight
                  : typeConfig.color.withValues(alpha: 0.4),
              width: item.isRead ? 1.0 : 1.5,
            ),
            boxShadow: [
              if (!item.isRead)
                BoxShadow(
                  color: typeConfig.color.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular icon with type color
              CircleAvatar(
                radius: 20,
                backgroundColor: typeConfig.color.withValues(alpha: 0.12),
                child: Icon(typeConfig.icon, color: typeConfig.color, size: 20),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Visual Type Flag / Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: typeConfig.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.type.displayName,
                            style: TextStyle(
                              color: typeConfig.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Unread Dot
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: typeConfig.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Notification Title
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.w600
                            : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Notification Message
                    Text(
                      item.message,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, NotificationFilter filter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              filter == NotificationFilter.all
                  ? 'No notifications yet'
                  : 'No ${filter.label} notifications',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Transfers, queued syncs, and savings vault updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotificationTypeConfig _getTypeConfig(NotificationType type) {
    switch (type) {
      case NotificationType.transferPending:
        return const _NotificationTypeConfig(
          icon: Icons.hourglass_top_rounded,
          color: Color(0xFFD97706), // Amber
        );
      case NotificationType.transferSuccess:
        return const _NotificationTypeConfig(
          icon: Icons.check_circle_rounded,
          color: Color(0xFF059669), // Emerald
        );
      case NotificationType.transferFailed:
        return const _NotificationTypeConfig(
          icon: Icons.error_outline_rounded,
          color: Color(0xFFDC2626), // Red
        );
      case NotificationType.savingsGoalCreated:
        return const _NotificationTypeConfig(
          icon: Icons.savings_rounded,
          color: Color(0xFF0891B2), // Cyan/Teal
        );
      case NotificationType.savingsContributed:
        return const _NotificationTypeConfig(
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFF7C3AED), // Indigo/Purple
        );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && now.day == timestamp.day) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (diff.inDays < 7) {
      return DateFormat('EEE, h:mm a').format(timestamp);
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}

class _NotificationTypeConfig {
  final IconData icon;
  final Color color;

  const _NotificationTypeConfig({required this.icon, required this.color});
}
