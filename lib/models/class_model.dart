class ClassModel {
  final String id;
  final String name;

  const ClassModel({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ClassModel.fromJson(Map<String, dynamic> json) =>
      ClassModel(id: json['id'] as String, name: json['name'] as String);
}
