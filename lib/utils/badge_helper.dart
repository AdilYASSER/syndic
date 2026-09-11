// lib/utils/badge_helper.dart

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:app_badge_plus/app_badge_plus.dart';

// ✅ Import conditionnel avec UN SEUL préfixe 'as html' à la fin
import 'dart:html' if (dart.library.io) 'badge_helper_stub.dart' as html;

class BadgeHelper {
  /// Met à jour le badge (Web = titre onglet / Mobile = icône)
  static Future<void> updateBadge(int count) async {
    // ============================================================
    // 🌐 WEB → titre de l'onglet
    // ============================================================
    if (kIsWeb) {
      try {
        html.document.title = count > 0 ? '($count) 🆘 Syndic' : 'Syndic';
      } catch (e) {
        debugPrint('⚠️ Impossible de mettre à jour le titre: $e');
      }
      return;
    }

    // ============================================================
    // 📱 MOBILE → badge icône
    // ============================================================
    try {
      final isSupported = await AppBadgePlus.isSupported();
      if (isSupported) {
        if (count > 0) {
          await AppBadgePlus.updateBadge(count);
        } else {
          await AppBadgePlus.updateBadge(0);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Badge non supporté: $e');
    }
  }

  /// Supprime le badge
  static Future<void> clearBadge() async {
    if (kIsWeb) {
      try {
        html.document.title = 'Syndic';
      } catch (_) {}
      return;
    }
    try {
      await AppBadgePlus.updateBadge(0);
    } catch (_) {}
  }
}