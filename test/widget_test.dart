import 'package:flutter_test/flutter_test.dart';
import 'package:mytaskmanager/validators.dart';

void main() {
  test('email and password cannot be empty', () {
    expect(validateEmail(''), 'Email is required');
    expect(validatePassword(''), 'Password is required');
  });

  test('task title cannot be empty', () {
    expect(validateTaskTitle('   '), 'Task title is required');
    expect(validateTaskTitle('Finish lab'), isNull);
  });
}
