// run_cleanup.dart
import 'package:syndic/tools/cleanup_duplicate_recus.dart';

void main() async {
  final cleanup = CleanupDuplicateRecus();
  await cleanup.execute();
}