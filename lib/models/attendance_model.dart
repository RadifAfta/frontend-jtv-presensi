class Attendance {
  final int? id;
  final String nama;
  final String divisi;
  final String tanggal;
  final String? masuk;
  final String? pulang;
  final String status;

  Attendance({
    this.id,
    required this.nama,
    required this.divisi,
    required this.tanggal,
    this.masuk,
    this.pulang,
    required this.status,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      nama: json['nama'] ?? json['user_nama'] ?? '',
      divisi: json['divisi'] ?? json['user_divisi'] ?? '',
      tanggal: json['tanggal'] ?? json['created_at'] ?? '',
      masuk: json['masuk'] ?? json['jam_masuk'],
      pulang: json['pulang'] ?? json['jam_pulang'],
      status: json['status'] ?? 'Tidak Hadir',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'divisi': divisi,
      'tanggal': tanggal,
      'masuk': masuk ?? '-',
      'pulang': pulang ?? '-',
      'status': status,
    };
  }
}