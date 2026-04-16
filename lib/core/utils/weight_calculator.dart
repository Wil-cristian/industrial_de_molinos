import 'dart:math' as math;

/// Calculadora de pesos para componentes metálicos
/// Fórmulas basadas en geometría y densidad de materiales
class WeightCalculator {
  /// Densidad del acero al carbono en kg/dm³
  static const double steelDensity = 7.85;
  
  /// Densidad del acero inoxidable en kg/dm³
  static const double stainlessSteelDensity = 8.0;

  /// Calcula el peso de un cilindro hueco (tubo/cuerpo del molino)
  /// 
  /// [outerDiameter] - Diámetro exterior en mm
  /// [thickness] - Espesor de pared en mm
  /// [length] - Largo del cilindro en mm
  /// [density] - Densidad del material en kg/dm³ (default: acero 7.85)
  /// 
  /// Retorna el peso en kg
  static double calculateCylinderWeight({
    required double outerDiameter,
    required double thickness,
    required double length,
    double density = steelDensity,
  }) {
    // Convertir mm a dm (dividir por 100)
    final outerDiameterDm = outerDiameter / 100;
    final innerDiameterDm = (outerDiameter - 2 * thickness) / 100;
    final lengthDm = length / 100;

    // Volumen = π × ((D_ext² - D_int²) / 4) × L
    final volume = math.pi * 
        ((outerDiameterDm * outerDiameterDm) - (innerDiameterDm * innerDiameterDm)) / 4 * 
        lengthDm;

    // Peso = Volumen × Densidad
    return volume * density;
  }

  /// Calcula el peso de una placa/tapa circular
  /// 
  /// [diameter] - Diámetro de la placa en mm
  /// [thickness] - Espesor de la placa en mm
  /// [density] - Densidad del material en kg/dm³
  /// 
  /// Retorna el peso en kg
  static double calculateCircularPlateWeight({
    required double diameter,
    required double thickness,
    double density = steelDensity,
  }) {
    // Convertir mm a dm
    final diameterDm = diameter / 100;
    final thicknessDm = thickness / 100;

    // Volumen = π × r² × espesor = π × (D/2)² × e
    final volume = math.pi * math.pow(diameterDm / 2, 2) * thicknessDm;

    return volume * density;
  }

  /// Calcula el peso de una placa rectangular
  /// 
  /// [width] - Ancho en mm
  /// [height] - Alto en mm
  /// [thickness] - Espesor en mm
  /// [density] - Densidad del material en kg/dm³
  /// 
  /// Retorna el peso en kg
  static double calculateRectangularPlateWeight({
    required double width,
    required double height,
    required double thickness,
    double density = steelDensity,
  }) {
    // Convertir mm a dm
    final widthDm = width / 100;
    final heightDm = height / 100;
    final thicknessDm = thickness / 100;

    // Volumen = ancho × alto × espesor
    final volume = widthDm * heightDm * thicknessDm;

    return volume * density;
  }

  /// Calcula el peso de un eje/barra cilíndrica sólida
  /// 
  /// [diameter] - Diámetro del eje en mm
  /// [length] - Longitud del eje en mm
  /// [density] - Densidad del material en kg/dm³
  /// 
  /// Retorna el peso en kg
  static double calculateShaftWeight({
    required double diameter,
    required double length,
    double density = steelDensity,
  }) {
    // Convertir mm a dm
    final diameterDm = diameter / 100;
    final lengthDm = length / 100;

    // Volumen = π × r² × L = π × (D/2)² × L
    final volume = math.pi * math.pow(diameterDm / 2, 2) * lengthDm;

    return volume * density;
  }

  /// Calcula el peso de un anillo/brida
  /// 
  /// [outerDiameter] - Diámetro exterior en mm
  /// [innerDiameter] - Diámetro interior (agujero) en mm
  /// [thickness] - Espesor en mm
  /// [density] - Densidad del material en kg/dm³
  /// 
  /// Retorna el peso en kg
  static double calculateRingWeight({
    required double outerDiameter,
    required double innerDiameter,
    required double thickness,
    double density = steelDensity,
  }) {
    // Convertir mm a dm
    final outerDm = outerDiameter / 100;
    final innerDm = innerDiameter / 100;
    final thicknessDm = thickness / 100;

    // Volumen = π × (R_ext² - R_int²) × espesor
    final volume = math.pi * 
        (math.pow(outerDm / 2, 2) - math.pow(innerDm / 2, 2)) * 
        thicknessDm;

    return volume * density;
  }

  /// Calcula el peso de un perfil angular (L)
  /// 
  /// [legWidth] - Ancho del ala en mm
  /// [thickness] - Espesor en mm
  /// [length] - Longitud en mm
  /// [density] - Densidad del material en kg/dm³
  /// 
  /// Retorna el peso en kg
  static double calculateAngleWeight({
    required double legWidth,
    required double thickness,
    required double length,
    double density = steelDensity,
  }) {
    // Convertir mm a dm
    final legWidthDm = legWidth / 100;
    final thicknessDm = thickness / 100;
    final lengthDm = length / 100;

    // Área de sección = 2 × ancho × espesor - espesor²
    final sectionArea = 2 * legWidthDm * thicknessDm - thicknessDm * thicknessDm;
    final volume = sectionArea * lengthDm;

    return volume * density;
  }

  /// Obtiene la descripción de dimensiones formateada para mostrar
  static String formatDimensions(String type, Map<String, dynamic> dimensions) {
    switch (type) {
      case 'cylinder':
        return 'Ø${dimensions['outer_diameter']}mm × ${dimensions['thickness']}mm × ${dimensions['length']}mm';
      case 'circular_plate':
        return 'Ø${dimensions['diameter']}mm × ${dimensions['thickness']}mm';
      case 'rectangular_plate':
        return '${dimensions['width']}mm × ${dimensions['height']}mm × ${dimensions['thickness']}mm';
      case 'shaft':
        return 'Ø${dimensions['diameter']}mm × ${dimensions['length']}mm';
      case 'ring':
        return 'Ø${dimensions['outer_diameter']}/${dimensions['inner_diameter']}mm × ${dimensions['thickness']}mm';
      default:
        return '';
    }
  }

  /// Calcula el peso según el tipo de componente
  static double calculateWeight({
    required String type,
    required Map<String, dynamic> dimensions,
    double density = steelDensity,
  }) {
    switch (type) {
      case 'cylinder':
        return calculateCylinderWeight(
          outerDiameter: (dimensions['outer_diameter'] ?? 0).toDouble(),
          thickness: (dimensions['thickness'] ?? 0).toDouble(),
          length: (dimensions['length'] ?? 0).toDouble(),
          density: density,
        );
      case 'circular_plate':
        return calculateCircularPlateWeight(
          diameter: (dimensions['diameter'] ?? 0).toDouble(),
          thickness: (dimensions['thickness'] ?? 0).toDouble(),
          density: density,
        );
      case 'rectangular_plate':
        return calculateRectangularPlateWeight(
          width: (dimensions['width'] ?? 0).toDouble(),
          height: (dimensions['height'] ?? 0).toDouble(),
          thickness: (dimensions['thickness'] ?? 0).toDouble(),
          density: density,
        );
      case 'shaft':
        return calculateShaftWeight(
          diameter: (dimensions['diameter'] ?? 0).toDouble(),
          length: (dimensions['length'] ?? 0).toDouble(),
          density: density,
        );
      case 'ring':
        return calculateRingWeight(
          outerDiameter: (dimensions['outer_diameter'] ?? 0).toDouble(),
          innerDiameter: (dimensions['inner_diameter'] ?? 0).toDouble(),
          thickness: (dimensions['thickness'] ?? 0).toDouble(),
          density: density,
        );
      default:
        return 0;
    }
  }
}

/// Tipos de componentes disponibles para cotización
enum ComponentType {
  cylinder('cylinder', 'Cilindro/Tubo', 'Cuerpo principal del molino'),
  circularPlate('circular_plate', 'Tapa Circular', 'Tapas de los extremos'),
  rectangularPlate('rectangular_plate', 'Lámina Rectangular', 'Láminas y placas'),
  shaft('shaft', 'Eje', 'Ejes de transmisión'),
  ring('ring', 'Anillo/Brida', 'Bridas y anillos'),
  custom('custom', 'Personalizado', 'Componente con peso manual');

  final String code;
  final String displayName;
  final String description;

  const ComponentType(this.code, this.displayName, this.description);

  static ComponentType fromCode(String code) {
    return ComponentType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ComponentType.custom,
    );
  }
}
