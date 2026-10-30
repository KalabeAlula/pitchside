class SubCity {
  final String id;
  final String nameEn;
  final String nameAm;

  const SubCity({required this.id, required this.nameEn, required this.nameAm});

  factory SubCity.fromJson(Map<String, dynamic> json) {
    return SubCity(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      nameAm: json['name_am'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_am': nameAm,
  };
}
