int compareRollNumbers(String a, String b) {
  final aNum = int.tryParse(a);
  final bNum = int.tryParse(b);
  if (aNum != null && bNum != null) {
    return aNum.compareTo(bNum);
  }
  // Fall back to standard string comparison if alphanumeric
  return a.compareTo(b);
}
