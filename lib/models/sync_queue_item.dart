// lib/models/sync_queue_item.dart
import 'package:hive/hive.dart';

part 'sync_queue_item.g.dart';

@HiveType(typeId: 1)
class SyncQueueItem { 
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type;

  @HiveField(2)
  String payload;

  @HiveField(3)
  final String createdAt;

  @HiveField(4)
  String status;

  @HiveField(5)
  int retryCount;

  SyncQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.status = 'pending',
    this.retryCount = 0,
  });
}