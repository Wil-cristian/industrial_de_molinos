# Calculadora de Peso para Recetas - Industrial de Molinos

## 🎯 Características Principales

Esta pantalla moderna permite crear recetas calculando automáticamente el peso de los materiales según sus dimensiones reales.

### 🧮 Calculadora de Peso Integrada

La calculadora se adapta dinámicamente según el tipo de material seleccionado:

#### 📐 LÁMINAS
- **Dimensiones**: Largo (cm) × Ancho (cm) × Espesor (pulgadas)
- **Fórmula**: Peso = Largo × Ancho × Espesor × Densidad
- **Ejemplo**: Lámina 100×80cm × 1/2" = ~31.4 kg

#### 🔵 TUBOS  
- **Dimensiones**: Diámetro Exterior (pulg) × Espesor de Pared (pulg) × Largo (cm)
- **Fórmula**: Peso = π × (D_ext² - D_int²) / 4 × Largo × Densidad
- **Ejemplo**: Tubo Ø4" × 1/4" × 100cm = ~24.6 kg

#### 📏 EJES
- **Dimensiones**: Diámetro (pulg) × Largo (cm)
- **Fórmula**: Peso = π × (D/2)² × Largo × Densidad
- **Ejemplo**: Eje Ø3" × 50cm = ~27.8 kg

### 💡 Conversiones Automáticas

- **Fracciones de Pulgada**: Soporta 1/2, 3/4, 1/4, 3/8, 5/8, etc.
- **Centímetros ↔ Pulgadas**: Conversión automática (1" = 2.54 cm)
- **Densidad del Acero**: 7.85 g/cm³ (constante)

### 📋 Estructura de la Receta

```
┌─────────────────────────────────────────┐
│  TÍTULO Y DESCRIPCIÓN                   │
├─────────────────────────────────────────┤
│  COMPONENTES:                           │
│  ├─ Calculadora (láminas/tubos/ejes)    │
│  └─ Materiales del inventario           │
├─────────────────────────────────────────┤
│  RESUMEN DE COSTOS:                     │
│  • Materiales: XXX kg - S/ XXX          │
│  • Pérdidas (5%): S/ XXX                │
│  • Mano de Obra: S/ XXX                 │
│  • PRECIO DE VENTA: S/ XXX              │
└─────────────────────────────────────────┘
```

## 🔧 Fórmulas Utilizadas

### Lámina Rectangular
```
Volumen = Largo(cm) × Ancho(cm) × Espesor(cm)
Peso(kg) = Volumen(cm³) × 7.85(g/cm³) / 1000
```

### Tubo (Cilindro Hueco)
```
R_ext = Diámetro_Exterior / 2
R_int = R_ext - Espesor_Pared
Volumen = π × (R_ext² - R_int²) × Largo
Peso(kg) = Volumen(cm³) × 7.85(g/cm³) / 1000
```

### Eje (Cilindro Sólido)
```
Radio = Diámetro / 2
Volumen = π × Radio² × Largo
Peso(kg) = Volumen(cm³) × 7.85(g/cm³) / 1000
```

## 📊 Ejemplo de Uso

### Crear Molino de Martillos 44"

1. **Título**: "Molino de Martillos 44 pulgadas"
2. **Descripción**: "Molino industrial con cilindro de acero A36"

3. **Agregar Componentes**:
   
   **Cilindro Principal (Tubo)**:
   - Diámetro: 20" (50.8 cm)
   - Espesor: 1/2" (12.7 mm)
   - Largo: 100 cm
   - Precio/kg: S/ 5.00
   - **Peso calculado: ~150 kg → S/ 750.00**

   **Tapa Frontal (Lámina)**:
   - Largo: 50 cm
   - Ancho: 50 cm  
   - Espesor: 1/2"
   - Precio/kg: S/ 4.50
   - **Peso calculado: ~37 kg → S/ 166.50**

   **Eje Principal (Eje)**:
   - Diámetro: 4"
   - Largo: 120 cm
   - Precio/kg: S/ 8.00
   - **Peso calculado: ~74 kg → S/ 592.00**

4. **Costos Adicionales**:
   - Pérdidas materiales: 5% → S/ 75.43
   - Mano de obra: S/ 500.00

5. **PRECIO DE VENTA**: **S/ 2,084.43**

## 🎨 Diseño de UI

### Panel Izquierdo (Calculadora)
- Selector visual de tipo (Lámina/Tubo/Eje)
- Campos de dimensiones con hints claros
- Resultado en tiempo real
- Botón "Agregar Componente"

### Panel Derecho (Receta)
- Formulario de título/descripción
- Lista de componentes con iconos por categoría
- Resumen financiero editable
- Botón guardar

## 🚀 Navegación

- **Desde Dashboard**: Productos → "Nueva Receta"
- **URL Directa**: `/recipe-builder`
- **Desde Productos**: Botón "Nueva Receta"

## 📝 Pendiente

- [ ] Guardar receta en Supabase (tabla `products` con `is_recipe=true`)
- [ ] Guardar componentes en `product_components`
- [ ] Validación de datos
- [ ] Editar recetas existentes
- [ ] Preview/Vista previa antes de guardar
- [ ] Exportar receta a PDF
- [ ] Duplicar receta
- [ ] Historial de cambios

## 🔗 Archivos Relacionados

- `lib/presentation/pages/recipe_builder_page.dart` - Pantalla principal
- `lib/router.dart` - Configuración de ruta
- `lib/core/utils/weight_calculator.dart` - Fórmulas de peso
- `supabase_migrations/008_materials_y_recetas.sql` - Estructura BD

## 💾 Estructura de Datos

```sql
-- Producto/Receta
products {
  id: UUID
  code: VARCHAR
  name: VARCHAR
  is_recipe: BOOLEAN
  recipe_description: TEXT
  unit_price: DECIMAL
  total_weight: DECIMAL
  total_cost: DECIMAL
}

-- Componentes
product_components {
  id: UUID
  product_id: UUID
  material_id: UUID (nullable)
  name: VARCHAR
  description: TEXT
  quantity: DECIMAL
  unit: VARCHAR
  -- Dimensiones para cálculo
  outer_diameter: DECIMAL
  thickness: DECIMAL  
  length: DECIMAL
  calculated_weight: DECIMAL
  unit_cost: DECIMAL
  total_cost: DECIMAL
}
```

---

**Fecha creación**: 25 de Diciembre, 2024
**Versión**: 1.0
**Autor**: GitHub Copilot
