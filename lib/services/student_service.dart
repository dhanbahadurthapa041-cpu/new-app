import '../models/student_model.dart';

class StudentService {
  static List<Student> getDummyStudents() {
    return [
      Student(id: '1', name: 'Aarav Sharma', rollNumber: '101'),
      Student(id: '2', name: 'Bipasha Thapa', rollNumber: '102'),
      Student(id: '3', name: 'Chirag Shrestha', rollNumber: '103'),
      Student(id: '4', name: 'Diya Maharjan', rollNumber: '104'),
      Student(id: '5', name: 'Elisha Gurung', rollNumber: '105'),
    ];
  }
}
