import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Geçmiş ekranı – renge göre süzme destekli
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// null => Tümü; aksi halde 'mavi' / 'beyaz' / 'kırmızı' / 'pembe' / 'turuncu' / 'sarı'
  String? _selectedColor;

  /// Uygulamada kullandığımız kod renkleri (HomePage ile uyumlu)
  static const List<_ColorFilter> _filters = [
    _ColorFilter(null, 'Tümü'), // null => filtre yok
    _ColorFilter('mavi', 'Mavi'),
    _ColorFilter('beyaz', 'Beyaz'),
    _ColorFilter('kırmızı', 'Kırmızı'),
    _ColorFilter('pembe', 'Pembe'),
    _ColorFilter('turuncu', 'Turuncu'),
    _ColorFilter('sarı', 'Sarı'),
  ];

  Query<Map<String, dynamic>> _buildBaseQuery() {
    var q = FirebaseFirestore.instance
        .collection('codes')
        .orderBy('createdAt', descending: true);

    if (_selectedColor != null) {
      // Seçili renk varsa filtre uygula
      q = q.where('color', isEqualTo: _selectedColor);
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    final q = _buildBaseQuery();

    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş')),
      body: Column(
        children: [
          // --- Renge göre süzme çipleri ---
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                final f = _filters[i];
                final bool selected = _selectedColor == f.value;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedColor = f.value; // null -> Tümü
                    });
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
            ),
          ),
          const Divider(height: 0),
          // --- Liste ---
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Hata: ${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Kayıt bulunamadı.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final color = (d['color'] ?? '').toString();
                    final message = (d['message'] ?? '').toString();
                    final ts = d['createdAt'];
                    DateTime? dt;
                    if (ts is Timestamp) dt = ts.toDate(); 
                    final sender = (d['email'] ?? d['by'] ?? '').toString();

return ListTile(
  title: Text(
    (message.isEmpty ? '(mesaj yok)' : message),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  ),
  subtitle: Text(
    [
      color.isEmpty ? '(renk yok)' : color,
      if (dt != null) _formatDate(dt),
      if (sender.isNotEmpty) 'gönderen: $sender',
      'id: ${docs[i].id}',
    ].join(' • '),
  ),
  leading: _colorDot(color),
  dense: false,
);

                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
   
  /// Basit bir tarih formatı (yerel saat)
  String _formatDate(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final y = dt.year;
    final mo = two(dt.month);
    final d = two(dt.day);
    final h = two(dt.hour);
    final mi = two(dt.minute);
    return '$y-$mo-$d $h:$mi';
  }

  /// Listedeki renk yuvarlağı
  Widget _colorDot(String color) {
    final map = <String, Color>{
      'mavi': const Color(0xFF1565C0),
      'beyaz': const Color(0xFF546E7A),
      'kırmızı': const Color(0xFFD32F2F),
      'pembe': const Color(0xFFE91E63),
      'turuncu': const Color(0xFFF57C00),
      'sarı': const Color(0xFFFBC02D),
    };
    final c = map[color] ?? Colors.grey;
    return CircleAvatar(backgroundColor: c, radius: 14);
  }
}

class _ColorFilter {
  final String? value; // null => Tümü
  final String label;
  const _ColorFilter(this.value, this.label);
}
