# 🎉 Funcionalidad de Guardado - Recipe Builder

## ✅ Implementado

### 1. **Datasource (recipes_datasource.dart)**
- `saveRecipe()` - Guardar nueva receta en Supabase
- `updateRecipe()` - Actualizar receta existente
- `deleteRecipe()` - Eliminar receta
- `getRecipes()` - Obtener todas las recetas
- `getRecipeComponents()` - Obtener componentes de una receta

**Tabla `products`:**
```sql
{
  id: UUID (autogenerado)
  code: 'REC-{timestamp}'
  name: 'Título de la receta'
  description: 'Descripción'
  is_recipe: true
  recipe_description: 'Descripción detallada'
  unit_price: Precio venta (total_cost × 1.3)
  cost_price: Costo total materiales
  total_weight: Peso total en kg
  total_cost: Costo total
  unit: 'UND'
  is_active: true
}
```

**Tabla `product_components`:**
```sql
{
  id: UUID
  product_id: FK a products
  material_id: FK a materials (nullable)
  name: 'Nombre componente'
  description: 'Dimensiones'
  quantity: Peso en kg
  unit: 'KG'
  outer_diameter, thickness, length: Dimensiones físicas
  calculated_weight: Peso calculado
  unit_cost: Precio/kg
  total_cost: Cantidad × unit_cost
  sort_order: Orden visual
}
```

### 2. **Provider (recipes_provider.dart)**
- `RecipesNotifier` - Gestión de estado
- `RecipesState` - Estado de las recetas
- `recipesProvider` - Provider principal
- `RecipeComponent` - Modelo para pasar datos desde UI

**Métodos:**
- `saveRecipe()` - Guardar receta (retorna bool)
- `updateRecipe()` - Actualizar receta
- `deleteRecipe()` - Eliminar receta
- `getRecipeComponents()` - Obtener componentes
- `clearError()` - Limpiar mensaje de error

### 3. **UI Updates (recipe_builder_page.dart)**
- Integración con `recipesProvider`
- Loading indicator en AppBar
- Validación de datos antes de guardar
- Manejo de errores con SnackBars
- Redirección a `/products` después de guardar

## 🔄 Flujo de Guardado

```
1. Usuario ingresa título y descripción
2. Usuario agrega componentes (calculadora o inventario)
3. Usuario presiona "Guardar"
   ↓
4. Validación:
   - ✓ Título no vacío
   - ✓ Al menos 1 componente
   ↓
5. Conversión de datos:
   - RecipeComponent → RecipeComponentData
   ↓
6. Cálculos:
   - Total Peso = suma de pesos componentes
   - Total Costo = suma de (peso × precio/kg)
   - Precio Venta = Total Costo × 1.3 (30% margen)
   ↓
7. Guardar en Supabase:
   - Insertar en tabla products
   - Obtener product_id
   - Insertar cada componente en product_components
   ↓
8. Actualizar estado:
   - Agregar receta a lista
   - Mostrar indicador de carga
   ↓
9. Feedback:
   - ✓ SnackBar verde: "Receta guardada exitosamente"
   - ✗ SnackBar rojo: Mostrar error
   ↓
10. Navegación:
    - Redirigir a /products
```

## 📊 Cálculos Automáticos

```
Costo Total = Σ(Peso_componente × Precio/kg)
Margen Ganancia = 30%
Precio Venta = Costo Total × 1.3

Ejemplo:
- Cilindro: 150kg × S/ 5.00 = S/ 750
- Tapa: 37kg × S/ 4.50 = S/ 166.50
- Eje: 74kg × S/ 8.00 = S/ 592
- Total Costo: S/ 1,508.50
- Precio Venta: S/ 1,511.05 × 1.3 = S/ 1,960.63
```

## 🔗 Integración Existente

El código se integra automáticamente con:
- ✅ Sistema de inventario (materials)
- ✅ Sistema de cotizaciones (products)
- ✅ Sistema de contabilidad (precios)
- ✅ Router (navegación `/products`)

## 📝 Validaciones

**Antes de guardar:**
- [ ] Título no vacío
- [ ] Descripción (opcional)
- [ ] Mínimo 1 componente
- [ ] Cada componente con peso > 0

**En la BD:**
- Código único auto-generado
- Timestamps automáticos (created_at, updated_at)
- Relaciones integrales con FOREIGN KEY
- ON DELETE CASCADE para limpiar componentes

## 🚀 Próximas Mejoras

- [ ] Editar recetas existentes
- [ ] Duplicar receta
- [ ] Preview/confirmación antes de guardar
- [ ] Validación de componentes con peso = 0
- [ ] Historial de cambios
- [ ] Exportar a PDF
- [ ] Margen de ganancia configurable
- [ ] Caché local de recetas

## 🧪 Testing

**Casos de uso:**
1. Crear receta simple (1-2 componentes)
2. Crear receta compleja (5+ componentes)
3. Intentar guardar sin componentes
4. Intentar guardar sin título
5. Verificar que aparezca en lista de productos
6. Verificar cálculos de costos

## 📁 Archivos Modificados

```
✅ lib/presentation/pages/recipe_builder_page.dart
   - Integración con recipesProvider
   - Loading indicator en AppBar
   - Lógica de guardado conectada a Supabase

✅ lib/data/providers/recipes_provider.dart
   - RecipesNotifier con lógica de negocio
   - Conversión de datos
   - Manejo de errores

✅ lib/data/datasources/recipes_datasource.dart
   - CRUD completo en Supabase
   - Manejo de transacciones

✅ lib/data/providers/providers.dart
   - Export de recipes_provider

✅ lib/router.dart
   - Ruta /recipe-builder integrada
```

---

**Estado**: ✅ IMPLEMENTADO Y LISTO
**Fecha**: 25 de Diciembre, 2024
**Funcionalidad**: Guardar y recuperar recetas en Supabase
