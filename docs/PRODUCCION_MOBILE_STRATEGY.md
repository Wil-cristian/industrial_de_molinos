# Estrategia Mobile — Módulo Órdenes de Producción

> **Fecha**: 28 Marzo 2026  
> **Target**: iPhone 15 Pro Max (430×932dp lógicos, 6.7")  
> **Breakpoint móvil**: < 600dp  
> **Estado**: EN IMPLEMENTACIÓN

---

## 1. Diagnóstico del Módulo Actual

### Inventario de Secciones (Desktop → 1100dp+)

| # | Sección | Complejidad | Problema en 430dp |
|---|---------|-------------|-------------------|
| 1 | **Header** (título + búsqueda + filtros) | Media | Búsqueda y filtros se apilan bien (ya tiene <700dp layout) |
| 2 | **Lista OP** (panel izq 420dp) | Baja | Ya existe `_buildMobileList()` con bottom sheet al 94% |
| 3 | **Detalle Header** (código, producto, estado, botones) | Alta | 4 botones de estado + 4 _InfoText en Wrap — se aprietan |
| 4 | **BOM** (lista colapsable + agregar) | Media | ListTiles con stock badge + pieza/dimensiones — apretado |
| 5 | **KPI Cards** (4 en Row) | Alta | 4 cards de ~100dp cada una — texto se trunca |
| 6 | **Process Chain Board** (timeline horizontal) | Alta | Nodos + flechas horizontales overflow a 430dp |
| 7 | **Stage Tiles** (tarjetas de etapa) | Media | Ya tiene modo compact <480dp pero detalles largos |
| 8 | **Mesa de Trabajo** (chips) | Baja | Wrap ya funciona bien |
| 9 | **Dialog: Crear OP** | Alta | Employee assignment Row con dropdown muy angosto |
| 10 | **Dialog: Editar Etapa** | Alta | Multi-select sections con Autocomplete — ancho limitado |
| 11 | **Dialog: Agregar BOM** | Alta | Tabs + calculadora de peso + result box — 520dp max actual |

### Lo que YA funciona en <600dp
- Header se apila verticalmente (título → búsqueda → filtros)
- Lista usa `_buildMobileList()` con cards completas
- Al tappear OP → `showModalBottomSheet` al 94% con `_buildOrderDetail()`
- Stage tiles tienen modo compact <480dp
- Botones de estado usan Wrap

### Lo que se ROMPE en 430dp
1. **KPI Cards en Row** → 4 Expanded = ~95dp cada uno = texto ilegible
2. **Process Chain** → nodos horizontales overflow o se comprimen demasiado
3. **Stock badges** en BOM overflow con nombres largos de materiales
4. **Dialogs** → max width 520-650dp no cabe; deben ser fullscreen en móvil
5. **Employee assignment** en crear OP → Row con # + nombre + Dropdown apretado
6. **Autocomplete dropdowns** → maxWidth 430-490dp hardcoded

---

## 2. Estrategia de Conversión

### Principio: Progressive Disclosure
En 430dp no podemos mostrar todo a la vez. La estrategia es:
1. **Mostrar lo esencial** primero (status, progreso, acciones principales)
2. **Ocultar detalles** en secciones colapsables
3. **Fullscreen** para dialogs y formularios
4. **Scroll vertical** en vez de layouts horizontales

### 2.1 Detalle de OP (Bottom Sheet 94%)

**Layout actual (6 secciones en ListView):**
```
[Header]     → compactar a card con info esencial + chips
[BOM]        → ya colapsable (✓) — optimizar ListTile para móvil
[KPIs]       → cambiar de 4-col Row a 2×2 Grid
[Chain]      → scroll horizontal con nodos más compactos
[Stages]     → stack vertical con cards más densos
[Mesa]       → sin cambios (Wrap ya funciona)
```

### 2.2 Header del Detalle (430dp)

**Desktop (>600dp):**
```
┌──────────────────────────────────────────┐
│ OP-202603 • trituradora 1,5  [Planificada]│
│ Cant: 1.00 | Entrega: 30/03 | Etapas: 1/4│
│ ████████ 25%                              │
│ [Planificada] [En proceso] [Pausada] [✓]  │
└──────────────────────────────────────────┘
```

**Mobile (≤430dp):**
```
┌────────────────────────────────┐
│ OP-202603           [Planificada]
│ trituradora 1,5                │
│ Cant: 1.00 • Entrega: 30/03   │
│ Etapas: 1/4 • $2.545.748      │
│ ████████████ 25%               │
│ ┌─────────┐┌─────────┐        │
│ │Planificada││En proceso│       │
│ └─────────┘└─────────┘        │
│ ┌─────────┐┌─────────┐        │
│ │ Pausada  ││✓Completar│       │
│ └─────────┘└─────────┘        │
└────────────────────────────────┘
```
→ Usar `Wrap` con `spacing: 8` para botones de estado (2×2 en 430dp)

### 2.3 KPI Cards (430dp)

**Desktop:** `Row[4 × Expanded(_KpiChip)]`  
**Mobile:** `Wrap` con 2 chips por fila (cada uno ~200dp)

```
┌──────────────┐┌──────────────┐
│ 📊 Avance 25%││ 📅 2 días     │
└──────────────┘└──────────────┘
┌──────────────┐┌──────────────┐
│ ⚡ Efic. 45% ││ 💰 $2.5M     │
└──────────────┘└──────────────┘
```

### 2.4 Process Chain (430dp)

**Desktop (>920dp):** Row horizontal con nodos y flechas  
**Mobile:** `SingleChildScrollView(horizontal)` ya existe pero nodos necesitan ser más compactos

→ Reducir ancho de nodos: maxWidth 100dp (vs 150dp desktop)  
→ Flechas: 18dp width (vs 34dp)  
→ Mantener scroll horizontal con indicador visual de scroll

### 2.5 BOM List (430dp)

**Optimización:**
- Nombre pieza + material en una sola línea si posible
- Stock badge debajo del nombre (no al lado) en <430dp
- Subtitle más compacto: "Req: 6 UND • Pend: 6"
- Eliminar icono delete explícito → swipe-to-delete o long-press menu

```
┌────────────────────────────────┐
│ ✓ Tapa superior                │
│   TUBERIA DE 20" (TUBO)       │
│   Tubo Ø20"×1/4"×100cm       │
│   Req: 6.00 KG • $10,000     │
│                    [Stock: 12] │
└────────────────────────────────┘
```

### 2.6 Dialogs → Fullscreen en Móvil

**Regla:** Si `width < 600dp`, todos los dialogs se abren como **páginas fullscreen** en lugar de AlertDialog/Dialog.

| Dialog | Desktop | Mobile (430dp) |
|--------|---------|----------------|
| Crear OP | AlertDialog 650dp | Fullscreen con AppBar + scroll |
| Editar Etapa | AlertDialog 620dp | Fullscreen con AppBar + scroll |
| Agregar BOM | Dialog 520dp | Fullscreen con AppBar + scroll |
| Confirmar eliminar | AlertDialog small | AlertDialog (ok, es pequeño) |

**Implementación:** Wrapper helper:
```dart
void showResponsiveDialog(BuildContext context, {
  required Widget Function(bool isMobile) builder,
}) {
  final isMobile = MediaQuery.sizeOf(context).width < 600;
  if (isMobile) {
    Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => builder(true),
    ));
  } else {
    showDialog(context: context, builder: (_) => builder(false));
  }
}
```

### 2.7 Dialog Agregar BOM (Fullscreen Mobile)

```
┌────────────────────────────────┐
│ ← Agregar material al BOM     │  ← AppBar
├────────────────────────────────┤
│ Nombre de la pieza             │
│ [Tapa superior___________]     │
│                                │
│ Buscar material                │
│ [🔍 TUBERIA DE 20"________]   │
│                                │
│ 📦 TUBERIA 20" — Stock: 0 KG  │
│                                │
│ [Directo] [Calcular Peso]     │ ← Tabs
│                                │
│ ─── Directo ───                │
│ Cantidad requerida             │
│ [1________________] KG         │
│ Costo estimado                 │
│ [$ 10000.00___________]        │
│                                │
│ ─── Calcular Peso ───         │
│ (Tubo) (Lámina) (Eje)         │
│ Ø Exterior [1________] "      │
│ Espesor    [1/4______] "      │
│ Largo      [100______] cm     │
│ Cantidad   [1___]             │
│ Costo: $X/KG                  │
│ ┌──────────────────────┐      │
│ │ Peso: 12.3 KG        │      │
│ │ Costo: $123,456       │      │
│ └──────────────────────┘      │
│                                │
│         [Agregar material]     │ ← FAB o Bottom button
└────────────────────────────────┘
```

→ En mobile, `Row[qty | cost]` se convierte en `Column[qty, cost]`  
→ Calc dimension fields usan todo el ancho (no Row + SizedBox fijo)

---

## 3. Plan de Implementación

### Cambios por Componente

| # | Componente | Cambio | Prioridad |
|---|-----------|--------|-----------|
| 1 | `_buildOrderHeader()` | Wrap botones estado 2×2 en <600dp | P0 |
| 2 | `_KpiCards` | Wrap 2×2 en <600dp | P0 |
| 3 | `_ProcessChainBoard` | Nodos compactos + scroll hint en <600dp | P1 |
| 4 | `_StageTile` | Ajustar padding y font sizes en <480dp | P1 |
| 5 | `_buildBomList()` | Stack vertical stock badge en <430dp | P1 |
| 6 | `_AddBomMaterialDialog` | Fullscreen + fields stacked en <600dp | P0 |
| 7 | `_CreateProductionOrderDialog` | Fullscreen + employee wrap en <600dp | P0 |
| 8 | `_EditStageDialog` | Fullscreen + autocomplete full-width en <600dp | P0 |
| 9 | `_buildSectionCard` | Reducir padding a 12 en <600dp | P2 |

### Orden de Ejecución
1. Detalle header (botones estado responsive)
2. KPI cards (2×2 grid)
3. BOM list (stock badge stacked)
4. Dialogs fullscreen wrapper
5. Dialog crear OP (fullscreen + layout)
6. Dialog agregar BOM (fullscreen + fields stacked)
7. Dialog editar etapa (fullscreen + layout)
8. Process chain (nodos compactos)
9. Stage tiles refinamiento
10. Polish y testing

---

## 4. Especificaciones iPhone 15 Pro Max

| Propiedad | Valor |
|-----------|-------|
| Pantalla | 6.7" OLED |
| Resolución lógica | 430 × 932 dp |
| Pixel ratio | 3x |
| Safe area top | ~59dp (Dynamic Island) |
| Safe area bottom | ~34dp (Home Indicator) |
| Área útil | 430 × 839dp |
| Bottom sheet al 94% | 430 × 876dp |

### Tipografía Recomendada en Mobile
- Título principal: 16sp (vs 20sp desktop)
- Subtítulo: 13sp (vs 14sp)
- Body: 13sp (vs 14sp)
- Caption/detail: 11sp (vs 12sp)
- KPI value: 16sp (vs 18sp)

### Espaciado Mobile
- Padding secciones: 12dp (vs 16dp desktop)
- Spacing entre secciones: 8dp (vs 12dp desktop)
- Card padding: 10dp (vs 14dp desktop)
