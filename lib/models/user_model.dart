class UserModel {
  final String uid;
  final String name;
  final String role; // 'admin' veya 'worker'
  final double? monthlySalary;
  final int? salaryDay; // Maaş günü (1-31 arası)
  final String? phone;

  UserModel({
    required this.uid,
    required this.name,
    required this.role,
    this.monthlySalary,
    this.salaryDay,
    this.phone,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    // Role alanını büyük/küçük harf duyarsız kontrol et
    String role = 'worker';
    if (map.containsKey('role')) {
      final roleValue = map['role'];
      if (roleValue is String) {
        role = roleValue.toLowerCase(); // Küçük harfe çevir
      }
    }
    // Alternatif alan isimlerini de kontrol et (Role, ROLE vs.)
    if (role == 'worker' && map.containsKey('Role')) {
      final roleValue = map['Role'];
      if (roleValue is String) {
        role = roleValue.toLowerCase();
      }
    }
    
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      role: role, // Artık lowercase olarak kaydedilir
      monthlySalary: map['monthly_salary'] != null 
          ? ((map['monthly_salary'] is num) 
              ? (map['monthly_salary'] as num).toDouble() 
              : 0.0)
          : null,
      salaryDay: map['salary_day'] != null
          ? ((map['salary_day'] is num)
              ? (map['salary_day'] as num).toInt()
              : null)
          : null,
      phone: map['phone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'monthly_salary': monthlySalary,
      'salary_day': salaryDay,
      'phone': phone,
    };
  }
}
