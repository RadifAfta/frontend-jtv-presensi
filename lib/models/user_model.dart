class User {
  final int? id;
  final String? nama;
  final String? email;
  final String? divisi;
  final int? nip;
  final int? telp;
  final String? address;
  final String? role;
  final String? createdAt;
  final String? updateAt;

  User({
    this.id,
    this.nama,
    this.email,
    this.divisi,
    this.nip,
    this.telp,
    this.address,
    this.role,
    this.createdAt,
    this.updateAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nama: json['nama'],
      email: json['email'],
      divisi: json['divisi'],
      nip: json['nip'],
      telp: json['telp'],
      address: json['address'],
      role: json['role'],
      createdAt: json['created_at'],
      updateAt: json['update_at'],
    );
  }
}