/// Generador automático de códigos de material
///
/// Formato: XX-NN[-SUBCAT]-####
///   XX     = 2 letras iniciales del nombre (una por palabra)
///   NN     = code_prefix de la categoría (2 dígitos)
///   SUBCAT = slug de subcategoría (opcional)
///   ####   = secuencial de 4 dígitos
///
/// Ejemplo: "Varilla Roscada" + categoría varilla (13) → VR-13-0001
/// Ejemplo: "Eje 4140" + categoría eje (05) + subcat "4140" → EJ-05-4140-0001
class MaterialCodeGenerator {
  /// Extrae las 2 iniciales del nombre del material.
  /// - Si hay 2+ palabras: toma primera letra de las 2 primeras palabras.
  /// - Si hay 1 palabra: toma las 2 primeras letras.
  /// - Se elimina todo carácter no alfanumérico antes de procesar.
  static String nameInitials(String name) {
    final cleaned = name.trim().toUpperCase();
    // Dividir por espacios y filtrar vacíos
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'XX';

    if (words.length >= 2) {
      // Primera letra de las 2 primeras palabras
      final a = _firstAlpha(words[0]);
      final b = _firstAlpha(words[1]);
      return '$a$b';
    }

    // Una sola palabra: primeras 2 letras
    final lettersOnly = words[0].replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (lettersOnly.length >= 2) return lettersOnly.substring(0, 2);
    if (lettersOnly.length == 1) return '${lettersOnly}X';
    return 'XX';
  }

  /// Genera el prefijo del código (sin el secuencial).
  /// Retorna algo como "VR-13" o "EJ-05-4140"
  static String codePrefix({
    required String name,
    required String categoryCodePrefix,
    String? subcategorySlug,
  }) {
    final initials = nameInitials(name);
    final parts = [initials, categoryCodePrefix];
    if (subcategorySlug != null && subcategorySlug.isNotEmpty) {
      parts.add(subcategorySlug.toUpperCase());
    }
    return parts.join('-');
  }

  /// Genera el código completo: prefijo + secuencial.
  /// [nextSequential] es el próximo número disponible (1-based).
  static String generate({
    required String name,
    required String categoryCodePrefix,
    String? subcategorySlug,
    required int nextSequential,
  }) {
    final prefix = codePrefix(
      name: name,
      categoryCodePrefix: categoryCodePrefix,
      subcategorySlug: subcategorySlug,
    );
    final seq = nextSequential.toString().padLeft(4, '0');
    return '$prefix-$seq';
  }

  /// Extrae la primera letra alfabética de una palabra.
  static String _firstAlpha(String word) {
    for (final ch in word.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[A-Z]').hasMatch(c)) return c;
    }
    // Si no hay letras, usar primer carácter
    return word.isNotEmpty ? word[0] : 'X';
  }
}
