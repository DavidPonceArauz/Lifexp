import 'package:flutter/foundation.dart';

import '../supabase/supabase_client.dart';

class XpService {
  final _db = SupabaseConfig.client;

  Future<void> applyXp({
    required String userId,
    required int amount,
    required String reason,
    required String source,
    required int sourceId,
    required String eventDate,
  }) async {
    try {
      final existing = await _db
          .from('xp_log')
          .select('id')
          .eq('source', source)
          .eq('source_id', sourceId)
          .eq('event_date', eventDate)
          .maybeSingle();
      if (existing != null) return;

      final profile = await _db
          .from('profiles')
          .select('total_xp')
          .eq('id', userId)
          .single();
      final currentXp = profile['total_xp'] as int? ?? 0;
      final newXp = (currentXp + amount).clamp(0, 999999);

      await _db.from('profiles').update({'total_xp': newXp}).eq('id', userId);
      await _db.from('xp_log').insert({
        'user_id': userId,
        'amount': amount,
        'reason': reason,
        'source': source,
        'source_id': sourceId,
        'event_date': eventDate,
      });
    } catch (e) {
      debugPrint('XP error: $e');
    }
  }

  Future<void> resetXp({
    required String userId,
  }) async {
    try {
      await _db.from('xp_log').delete().eq('user_id', userId);
      await _db.from('profiles').update({'total_xp': 0}).eq('id', userId);
    } catch (e) {
      debugPrint('XP reset error: $e');
    }
  }
}
