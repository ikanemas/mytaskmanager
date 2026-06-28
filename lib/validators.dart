String? validateEmail(String value) {
  if (value.trim().isEmpty) {
    return 'Email is required';
  }

  return null;
}

String? validatePassword(String value) {
  if (value.isEmpty) {
    return 'Password is required';
  }

  return null;
}

String? validateTaskTitle(String value) {
  if (value.trim().isEmpty) {
    return 'Task title is required';
  }

  return null;
}
