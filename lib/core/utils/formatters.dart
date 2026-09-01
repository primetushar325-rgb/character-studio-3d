/// Formatting helpers (file sizes, relative time, durations).
library;

class Formatters {
  Formatters._();

  /// 1.2 KB / 3.4 MB / 210 B
  static String fileSize(int bytes) {
    if (bytes < 0) bytes = 0;
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// "2 minutes ago", "1 hour ago", "Yesterday", "3 days ago", "12 Aug 2026"
  static String relativeTime(DateTime? time, {DateTime? now}) {
    if (time == null) return '—';
    final n = now ?? DateTime.now();
    final diff = n.difference(time);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 1) return '1 minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 2) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';

    final yesterday = n.subtract(const Duration(days: 1));
    if (time.year == yesterday.year &&
        time.month == yesterday.month &&
        time.day == yesterday.day) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final sameYear = time.year == n.year;
    return sameYear
        ? '${time.day} ${months[time.month - 1]}'
        : '${time.day} ${months[time.month - 1]} ${time.year}';
  }

  /// 0:07 / 1:12
  static String clock(double seconds) {
    if (seconds.isNaN || seconds < 0) seconds = 0;
    final s = seconds.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  /// "0.71s"
  static String clipDuration(double? seconds) {
    if (seconds == null) return '—';
    return '${seconds.toStringAsFixed(2)}s';
  }

  /// "tiger.png" -> "tiger"
  static String prettyFileBase(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  /// "tiger.png" -> "png"
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// Title-case a raw token: "walk_cycle" -> "Walk Cycle"
  static String titleCase(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
