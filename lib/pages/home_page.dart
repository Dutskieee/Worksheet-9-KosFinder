import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/kos_service.dart';
import '../services/profile_service.dart';
import '../utils/security_test.dart';
import '../widgets/role_guard.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _kosService = KosService();
  late Future<UserProfile?> _profileFuture;
  late Future<List<Map<String, dynamic>>> _kosFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileService().getMyProfile();
    _kosFuture = _kosService.fetchAll();
  }

  void _refreshKos() {
    setState(() {
      _kosFuture = _kosService.fetchAll();
    });
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showAddKosDialog() async {
    final nameC = TextEditingController();
    final addressC = TextEditingController();
    final priceC = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Nama Kos'),
            ),
            TextField(
              controller: addressC,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await _kosService.add(
          name: nameC.text.trim(),
          address: addressC.text.trim(),
          price: int.tryParse(priceC.text.trim()) ?? 0,
        );
        _refreshKos();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah kos: $e')),
        );
      }
    }
  }

  Future<void> _showEditKosDialog(Map<String, dynamic> kos) async {
    final nameC = TextEditingController(text: (kos['name'] ?? '').toString());
    final priceC = TextEditingController(text: (kos['price'] ?? 0).toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Kos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Nama Kos'),
            ),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final ok = await _kosService.update(
        kos['id'].toString(),
        {
          'name': nameC.text.trim(),
          'price': int.tryParse(priceC.text.trim()) ?? 0,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Kos berhasil diubah' : 'Gagal mengubah kos (RLS)'),
        ),
      );
      _refreshKos();
    }
  }

  Future<void> _deleteKos(String id) async {
    final ok = await _kosService.delete(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Kos berhasil dihapus' : 'Gagal menghapus kos (RLS)'),
      ),
    );
    _refreshKos();
  }

  Future<void> _runSecurityTest(String kosId, String ownerId) async {
    final result = await securityTest(kosId, ownerId);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasil Uji RLS'),
        content: SelectableText(result),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    _refreshKos();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;

    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError || snap.data == null) {
          return const Scaffold(
            body: Center(child: Text('Gagal memuat profil')),
          );
        }

        final p = snap.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('KosFinder (${p.role})'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refreshKos,
              ),
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
          ),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(p.name.isEmpty ? p.email : p.name),
                subtitle: Text('${p.email} • ${p.role}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('Daftar Kos'),
                onTap: _refreshKos,
              ),
              if (p.isOwner || p.isAdmin)
                ListTile(
                  leading: const Icon(Icons.home_work),
                  title: const Text('My Kos'),
                  onTap: () {},
                ),
              if (p.isAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Kelola Data (Admin)'),
                  onTap: () {},
                ),
              const Divider(),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _kosFuture,
                builder: (context, kosSnap) {
                  if (kosSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (kosSnap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Gagal memuat kos: ${kosSnap.error}'),
                    );
                  }

                  final kosList = kosSnap.data ?? [];
                  if (kosList.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada data kos.'),
                    );
                  }

                  return Column(
                    children: kosList.map((kos) {
                      final kosId = kos['id'].toString();
                      final ownerId = kos['owner_id'].toString();
                      final isMine = ownerId == currentUser?.id;

                      return ListTile(
                        leading: const Icon(Icons.house),
                        title: Text((kos['name'] ?? '-').toString()),
                        subtitle: Text(
                          '${kos['address'] ?? '-'} • Rp ${kos['price'] ?? 0}',
                        ),
                        trailing: isMine
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditKosDialog(kos),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteKos(kosId),
                                  ),
                                ],
                              )
                            : TextButton(
                                onPressed: () =>
                                    _runSecurityTest(kosId, ownerId),
                                child: const Text('Uji RLS'),
                              ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: RoleGuard(
            role: p.role,
            allowed: const ['owner', 'admin'],
            child: FloatingActionButton.extended(
              onPressed: _showAddKosDialog,
              icon: const Icon(Icons.add_home),
              label: const Text('Tambah Kos'),
            ),
          ),
        );
      },
    );
  }
}
