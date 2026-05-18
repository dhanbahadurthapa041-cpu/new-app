class Student {
  final String id;
  final String name;
  final String rollNumber;
  bool isPresent;
  bool isLate;

  Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    this.isPresent = true,
    this.isLate = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rollNumber': rollNumber,
    'isPresent': isPresent,
    'isLate': isLate,
  };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] as String,
    name: json['name'] as String,
    rollNumber: json['rollNumber'] as String,
    isPresent: json['isPresent'] as bool,
    isLate: json['isLate'] as bool? ?? false,
  );
}
