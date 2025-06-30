extension StringCasingExtension on String { // Un nombre más descriptivo
  String capitalizeFirst() { // Un nombre más específico para el método si quieres
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}"; // O solo .substring(1)
  }
}