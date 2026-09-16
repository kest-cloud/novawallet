import 'package:equatable/equatable.dart';

class SyncProgress extends Equatable {
  final bool isSyncing;
  final int totalCount;
  final int currentItemIndex;
  final double progress; // 0.0 to 1.0
  final String? currentActionDescription;

  const SyncProgress({
    this.isSyncing = false,
    this.totalCount = 0,
    this.currentItemIndex = 0,
    this.progress = 0.0,
    this.currentActionDescription,
  });

  static const idle = SyncProgress();

  @override
  List<Object?> get props => [
        isSyncing,
        totalCount,
        currentItemIndex,
        progress,
        currentActionDescription,
      ];
}
