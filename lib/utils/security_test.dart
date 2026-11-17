import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/kos_service.dart';

Future<String> securityTest(String kosIdMilikUserA, String ownerIdUserA) async {
  final svc = KosService();
  final logs = <String>[];

  void log(String msg) {
    debugPrint(msg);
    logs.add(msg);
  }

  // 1. Coba UPDATE kos milik user A saat login sebagai user B
  final updated = await svc.update(kosIdMilikUserA, {'name': 'DIUBAH USER B'});
  log(
    updated
        ? '[FAIL] UPDATE berhasil (RLS bocor!)'
        : '[PASS] UPDATE ditolak oleh RLS',
  );

  // 2. Coba DELETE kos milik user A
  final deleted = await svc.delete(kosIdMilikUserA);
  log(
    deleted
        ? '[FAIL] DELETE berhasil (RLS bocor!)'
        : '[PASS] DELETE ditolak oleh RLS',
  );

  // 3. Coba INSERT kos dengan owner_id palsu (mengaku sebagai user A)
  try {
    await Supabase.instance.client.from('kos').insert({
      'owner_id': ownerIdUserA,
      'name': 'Kos palsu',
    });
    log('[FAIL] INSERT dengan owner_id palsu berhasil!');
  } on PostgrestException catch (e) {
    log('[PASS] INSERT ditolak: ${e.code} - ${e.message}');
  }

  return logs.join('\n');
}

