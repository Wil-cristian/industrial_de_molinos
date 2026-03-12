# Industrial de Molinos — Sistema de Diseño Completo

> **Propósito**: Documento maestro que define TODA la estética visual de la aplicación.
> Se usa como referencia para rediseñar todas las pantallas desde cero con coherencia total.
> Aplica a **Android (móvil)**, **tablet** y **Windows (escritorio)**.

---

## 1. IDENTIDAD VISUAL Y FILOSOFÍA

### 1.1 Concepto
Aplicación ERP industrial para gestión de molinos. La identidad debe transmitir:
- **Solidez**: Es un sistema de datos financieros/inventario — debe inspirar confianza
- **Claridad**: Dashboards con datos densos deben ser legibles de un vistazo
- **Modernidad**: Material Design 3 completo, no genérico sino con personalidad industrial
- **Eficiencia**: Navegación rápida, información jerarquizada, cero decoración innecesaria

### 1.2 Personalidad de marca
- Profesional pero accesible (no corporativo frío)
- Data-driven: los números son protagonistas
- Industrial-cálido: paleta de azules industriales con acentos cálidos (ámbar/bronce)

---

## 2. PALETA DE COLORES

### 2.1 Sistema de color M3 — Generado desde seed color

Usar `ColorScheme.fromSeed()` con seed color como fuente. El algoritmo HCT de Material genera automáticamente las 26+ roles de color con contraste accesible.

```dart
// SEED COLOR PRINCIPAL
static const Color seedColor = Color(0xFF1B4F72); // Azul industrial profundo

// Generación automática del esquema
ColorScheme.fromSeed(
  seedColor: seedColor,
  brightness: Brightness.light,
)
```

### 2.2 Paleta Light Theme

| Rol | Token | Hex aprox. | Uso |
|-----|-------|-----------|-----|
| `primary` | Primary | `#1B4F72` | Botones principales, FAB, enlaces activos |
| `onPrimary` | On Primary | `#FFFFFF` | Texto/iconos sobre primary |
| `primaryContainer` | Primary Container | `#D1E4F0` | Fondo de chips seleccionados, badges |
| `onPrimaryContainer` | On Primary Container | `#0A2540` | Texto sobre primaryContainer |
| `secondary` | Secondary | `#526070` | Elementos secundarios, botones outlined |
| `onSecondary` | On Secondary | `#FFFFFF` | Texto sobre secondary |
| `secondaryContainer` | Secondary Container | `#D6E4F0` | Fondo de navigation bar seleccionado, filtros |
| `tertiary` | Tertiary | `#8B5E3C` | Acentos cálidos (bronce), highlights, alertas no-urgentes |
| `onTertiary` | On Tertiary | `#FFFFFF` | Texto sobre tertiary |
| `tertiaryContainer` | Tertiary Container | `#FFDCC2` | Fondo de estados pendientes, badges warm |
| `surface` | Surface | `#F8FAFB` | Fondo de pantallas, body principal |
| `onSurface` | On Surface | `#1A1C1E` | Texto principal del body |
| `surfaceContainerLowest` | Surface Container Lowest | `#FFFFFF` | Cards elevadas |
| `surfaceContainerLow` | Surface Container Low | `#F2F4F6` | Cards de segundo nivel |
| `surfaceContainer` | Surface Container | `#ECEEF0` | Bottom nav bar, side sheets |
| `surfaceContainerHigh` | Surface Container High | `#E6E8EA` | Dropdowns, menús |
| `surfaceContainerHighest` | Surface Container Highest | `#E1E3E5` | Inputs deshabilitados |
| `outline` | Outline | `#73777F` | Bordes de inputs, dividers importantes |
| `outlineVariant` | Outline Variant | `#C3C7CF` | Dividers sutiles, bordes decorativos |
| `error` | Error | `#BA1A1A` | Errores, validaciones fallidas, deudas vencidas |
| `errorContainer` | Error Container | `#FFDAD6` | Fondo de alertas de error |

### 2.3 Paleta Dark Theme

Generada automáticamente por `ColorScheme.fromSeed(brightness: Brightness.dark)`. Los tonos se invierten: primary usa tono 80 en vez de 40, surfaces usan tonos 6-12 del neutral.

### 2.4 Colores Semánticos Personalizados (Fixed/Custom)

Estos NO vienen del seed color. Se definen manualmente y se armonizan con el tema:

```dart
// Colores semánticos para estados de negocio
static const Color successGreen   = Color(0xFF2E7D32); // Pagado, completado, en stock
static const Color warningAmber   = Color(0xFFF9A825); // Pendiente, stock bajo, próximo a vencer
static const Color dangerRed      = Color(0xFFC62828); // Vencido, sin stock, error
static const Color infoBlue       = Color(0xFF1565C0); // Informativo, links, ayuda
static const Color neutralGrey    = Color(0xFF616161); // Inactivo, deshabilitado

// Colores para gráficos/charts (armonizados con el seed)
static const List<Color> chartPalette = [
  Color(0xFF1B4F72), // Primary
  Color(0xFF2E86C1), // Primary lighter
  Color(0xFF8B5E3C), // Tertiary/bronce
  Color(0xFFF39C12), // Ámbar
  Color(0xFF27AE60), // Verde
  Color(0xFFE74C3C), // Rojo
  Color(0xFF8E44AD), // Púrpura
  Color(0xFF16A085), // Teal
];
```

### 2.5 Reglas de Uso de Color

1. **Nunca hardcodear colores** → Siempre usar `Theme.of(context).colorScheme.xxx`
2. **Jerarquía por tono**: primary para acciones principales, secondary para secundarias, tertiary para acentos
3. **Surfaces por elevación**: surfaceContainerLowest (más elevado) → surfaceContainerHighest (fondo)
4. **Señales de negocio**: Siempre usar los colores semánticos, nunca rojo/verde genérico
5. **Contraste mínimo**: 4.5:1 para texto normal, 3:1 para texto grande y elementos UI

---

## 3. TIPOGRAFÍA

### 3.1 Familia tipográfica

```dart
// Font principal: Inter (o Google Sans si se prefiere más "Google-like")
// Alternativa: Roboto (default de M3)
// Para números/datos: usar tabularFigures para alineación en tablas
static const String fontFamily = 'Inter'; // O dejar default Roboto
```

### 3.2 Escala tipográfica M3 (15 estilos base)

| Rol | Estilo | Tamaño | Peso | Line Height | Tracking | Uso en la App |
|-----|--------|--------|------|-------------|----------|---------------|
| **Display** | Large | 57sp | 400 | 64sp | -0.25sp | NO USAR en móvil |
| | Medium | 45sp | 400 | 52sp | 0sp | NO USAR en móvil |
| | Small | 36sp | 400 | 44sp | 0sp | Hero numbers en dashboard desktop |
| **Headline** | Large | 32sp | 400 | 40sp | 0sp | Títulos de sección grandes (desktop) |
| | Medium | 28sp | 400 | 36sp | 0sp | KPI principal en cards |
| | Small | 24sp | 400 | 32sp | 0sp | Títulos de páginas |
| **Title** | Large | 22sp | 500 | 28sp | 0sp | App bar titles |
| | Medium | 16sp | 500 | 24sp | 0.15sp | Subtítulos de cards, nombre de sección |
| | Small | 14sp | 500 | 20sp | 0.1sp | Tab labels, navigation labels |
| **Body** | Large | 16sp | 400 | 24sp | 0.5sp | Texto principal, descripciones |
| | Medium | 14sp | 400 | 20sp | 0.25sp | Texto de listas, contenido general |
| | Small | 12sp | 400 | 16sp | 0.4sp | Texto auxiliar, captions |
| **Label** | Large | 14sp | 500 | 20sp | 0.1sp | Botones, labels de inputs |
| | Medium | 12sp | 500 | 16sp | 0.5sp | Chips, badges, tags |
| | Small | 11sp | 500 | 16sp | 0.5sp | Timestamps, metadata mínima |

### 3.3 Tipografía en móvil — Ajustes específicos

```dart
// En móvil (< 600dp), reducir displays y headlines
// headlineSmall → 22sp (en vez de 24sp)
// KPI numbers → headlineMedium 26sp (en vez de 28sp)
// Nunca usar displayLarge/Medium en móvil
```

### 3.4 Reglas tipográficas

1. **Máximo 3 pesos** en una misma pantalla (400 regular, 500 medium, 700 bold)
2. **Números financieros**: siempre `fontFeatures: [FontFeature.tabularFigures()]` para alineación
3. **Nunca ALL CAPS** excepto en labels de botones pequeños y chips
4. **Truncar con ellipsis** (`overflow: TextOverflow.ellipsis, maxLines: 1`) en listas — nunca dejar overflow
5. **Color de texto**: `onSurface` para principal, `onSurfaceVariant` para secundario, `outline` para disabled

---

## 4. ESPACIADO Y GRID

### 4.1 Sistema de espaciado (base 4dp)

| Token | Valor | Uso |
|-------|-------|-----|
| `space-none` | 0dp | — |
| `space-xxs` | 2dp | Separación mínima entre iconos y texto inline |
| `space-xs` | 4dp | Padding interno de chips, gap entre badges |
| `space-sm` | 8dp | Gap entre elementos de un grupo, padding de buttons |
| `space-md` | 12dp | Padding interno de cards, gap entre cards |
| `space-base` | 16dp | Margin principal en móvil, padding de listas |
| `space-lg` | 20dp | Gap entre secciones dentro de una pantalla |
| `space-xl` | 24dp | Margin en tablet, spacer entre panes |
| `space-2xl` | 32dp | Separación de secciones grandes |
| `space-3xl` | 40dp | Espaciado de headers generosos |
| `space-4xl` | 48dp | Gap máximo entre bloques |

### 4.2 Implementación en Dart

```dart
class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double xxxxl = 48;
}
```

### 4.3 Márgenes por breakpoint

| Breakpoint | Margin lateral | Spacer entre panes |
|-----------|----------------|---------------------|
| Compact (< 600dp) | 16dp | N/A (single pane) |
| Medium (600–839dp) | 24dp | 24dp |
| Expanded (840–1199dp) | 24dp | 24dp |
| Large (1200dp+) | 24dp | 24dp |

### 4.4 Reglas de espaciado

1. **Padding interno de cards**: 16dp (móvil), 20dp (tablet+)
2. **Gap entre cards en grid**: 12dp (móvil), 16dp (desktop)
3. **Padding de la pantalla (scaffold body)**: `EdgeInsets.symmetric(horizontal: 16)` en móvil
4. **Separación entre secciones**: 24dp mínimo
5. **Nunca usar valores arbitrarios**: todo debe ser múltiplo de 4dp

---

## 5. FORMAS Y BORDES (SHAPE SYSTEM)

### 5.1 Escala de corner radius M3

| Token | Valor | Componentes que lo usan |
|-------|-------|------------------------|
| `shape-none` | 0dp | Bordes de pantalla, dividers |
| `shape-xs` | 4dp | Tooltips, badges pequeños |
| `shape-sm` | 8dp | Buttons, chips, small FABs, inputs, snackbars |
| `shape-md` | 12dp | **Cards** (valor principal), dialogs, menus, dropdowns |
| `shape-lg` | 16dp | FAB grande, navigation drawer, cards hero |
| `shape-lg-inc` | 20dp | Bottom sheets (top corners) |
| `shape-xl` | 28dp | Search bar, large cards decorativas |
| `shape-xl-inc` | 32dp | — |
| `shape-xxl` | 48dp | — |
| `shape-full` | 9999dp | Avatars, indicadores de navigation bar, pills |

### 5.2 Implementación

```dart
class AppShapes {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double lgInc = 20;
  static const double xl = 28;
  static const double full = 9999;

  // Helpers para BorderRadius
  static final BorderRadius cardRadius = BorderRadius.circular(md);
  static final BorderRadius buttonRadius = BorderRadius.circular(sm);
  static final BorderRadius inputRadius = BorderRadius.circular(sm);
  static final BorderRadius dialogRadius = BorderRadius.circular(xl);
  static final BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(lgInc),
  );
  static final BorderRadius chipRadius = BorderRadius.circular(sm);
  static final BorderRadius avatarRadius = BorderRadius.circular(full);
}
```

### 5.3 Regla de optical roundness

Cuando un container redondeado contiene otro con borde redondeado:
```
radio_interno = radio_externo - padding_entre_ambos
```
Ejemplo: Card con radio 12dp y padding 16dp → contenido interior con radio 0dp (12-16 < 0).

---

## 6. ELEVACIÓN Y SOMBRAS

### 6.1 Niveles de elevación M3

M3 usa **tonal elevation** (color de surface cambia en tono) en lugar de sombras. En light theme, sombras mínimas; en dark theme, tones en lugar de sombras.

| Nivel | dp | Surface Token | Uso | Sombra |
|-------|-----|---------------|-----|--------|
| Level 0 | 0dp | `surface` | Fondo de pantalla | Ninguna |
| Level 1 | 1dp | `surfaceContainerLow` | Cards estándar, nav rail | Sutil (blur 3) |
| Level 2 | 3dp | `surfaceContainer` | Bottom nav bar, bottom sheet (rest) | Leve (blur 6) |
| Level 3 | 6dp | `surfaceContainerHigh` | FAB, bottom sheet (drag), dropdown | Media (blur 8) |
| Level 4 | 8dp | `surfaceContainerHighest` | App bar scrolled | Marcada (blur 12) |
| Level 5 | 12dp | — | Menus, tooltips | Fuerte (blur 16) |

### 6.2 Implementación

```dart
class AppElevation {
  // Cards → Level 1, sin sombra, usar surfaceContainerLowest
  static const double card = 0; // Usar tonal surface en vez de sombra
  static const double cardHover = 1;
  static const double fab = 6;
  static const double dialog = 6;
  static const double dropdown = 3;
  static const double appBarScrolled = 2;

  // Box shadows opcionales para modo light (complementan tonal elevation)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
```

### 6.3 Reglas de elevación

1. **Cards**: usar `surfaceContainerLowest` sin elevation (flat cards) — aspecto limpio y moderno
2. **Cards interactivas**: agregar `cardShadow` sutil en hover/press estado
3. **FAB**: elevation 6, shadow real
4. **Dialogs**: elevation 6 con overlay scrim
5. **Bottom sheets**: elevation 1 en rest, 3 cuando se arrastra

---

## 7. MOTION Y ANIMACIONES

### 7.1 Curvas de animación M3

M3 define dos esquemas de motion: **Standard** (funcional) y **Expressive** (con personalidad).

Para una app ERP, usar **Standard** como base con **Expressive** solo para transiciones de navegación y hero moments.

```dart
class AppMotion {
  // === STANDARD EASING ===
  // Para la mayoría de transiciones UI
  static const Curve standard = Curves.easeInOutCubicEmphasized;
  static const Curve standardAccelerate = Curves.easeInCubic;
  static const Curve standardDecelerate = Curves.easeOutCubic;

  // === EXPRESSIVE EASING ===
  // Solo para transiciones de navegación y hero animations
  static const Curve expressive = Curves.easeInOutCubicEmphasized;

  // === DURACIONES ===
  static const Duration fast = Duration(milliseconds: 150);       // Ripple, icon change
  static const Duration medium = Duration(milliseconds: 250);     // Expand/collapse, tab switch
  static const Duration mediumSlow = Duration(milliseconds: 350); // Page transition
  static const Duration slow = Duration(milliseconds: 500);       // Complex transitions
  static const Duration extraSlow = Duration(milliseconds: 700);  // Hero animations, onboarding

  // === SPRING CONFIGS ===
  // Para physics-based animations (drag, fling, sheet)
  static const SpringDescription sheetSpring = SpringDescription(
    mass: 1,
    stiffness: 600,
    damping: 30,
  );
}
```

### 7.2 Cuándo animar qué

| Tipo de transición | Duración | Curva | Ejemplo |
|-------------------|----------|-------|---------|
| Ripple / press feedback | fast (150ms) | standard | Tap en botón, card |
| Toggle / switch | fast (150ms) | standard | Checkbox, switch, icon toggle |
| Expand / collapse | medium (250ms) | standard | ExpansionTile, accordion, dropdown |
| Tab / segment switch | medium (250ms) | standard | Cambiar de tab, segmented button |
| Dialog enter | mediumSlow (350ms) | standardDecelerate | Abrir dialog, bottom sheet |
| Dialog exit | medium (250ms) | standardAccelerate | Cerrar dialog |
| Page transition | mediumSlow (350ms) | expressive | Navegar entre pantallas |
| Hero / shared element | slow (500ms) | expressive | Card → detail, FAB → full screen |
| Loading spinner | — | linear | CircularProgressIndicator |
| Staggered list items | medium (250ms) × index | standardDecelerate | Lista que aparece item por item |

### 7.3 Transiciones de página

```dart
// Para GoRouter page transitions
CustomTransitionPage(
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AppMotion.standard,
      ),
      child: child,
    );
  },
  transitionDuration: AppMotion.mediumSlow,
)
```

### 7.4 Reglas de animación

1. **Nunca animar solo por animar** — cada animación debe comunicar algo (dirección, jerarquía, resultado)
2. **Parallel > Sequential** — preferir animaciones simultáneas con stagger leve vs. secuenciales
3. **Respetar reducedMotion** — verificar `MediaQuery.of(context).disableAnimations`
4. **Loading states** — shimmer placeholders, nunca pantalla en blanco
5. **Feedback háptico** — agregar `HapticFeedback.lightImpact()` en acciones críticas (confirmar pago, etc.)

---

## 8. ICONOGRAFÍA

### 8.1 Estilo de iconos

Usar **Material Symbols Rounded** (variante redondeada) para consistencia con shape system.

```dart
// En ThemeData
iconTheme: const IconThemeData(
  size: 24,
  opticalSize: 24,
  weight: 400, // Normal
),
```

### 8.2 Tamaños de iconos

| Tamaño | Valor | Uso |
|--------|-------|-----|
| XS | 16dp | Inline con texto small, badges |
| SM | 20dp | Inline con texto body, lista trailing |
| MD | 24dp | **Default** — navigation, buttons, list leading |
| LG | 32dp | Cards KPI, empty states |
| XL | 40dp | Hero icons, onboarding |
| XXL | 48dp | Empty states grandes, error pages |

### 8.3 Reglas de iconos

1. Usar iconos Outlined para navegación NO seleccionada, Filled para seleccionada
2. Color: `onSurfaceVariant` por default, `primary` para acción/seleccionado
3. Siempre acompañar icon buttons de un tooltip (`Tooltip` widget)

---

## 9. COMPONENTES — Especificaciones Detalladas

### 9.1 Cards

La card es el componente MÁS USADO en esta app (KPIs, listados, resúmenes).

```
┌─────────────────────────────────────────┐
│  [Icon]  Title          [Action Button] │  ← Header: padding 16dp
│─────────────────────────────────────────│
│                                         │
│  Content area                           │  ← Body: padding 16dp
│  Numbers, charts, lists                 │
│                                         │
│─────────────────────────────────────────│
│  [Secondary Action]    [Primary Action] │  ← Footer (opcional): padding 12dp
└─────────────────────────────────────────┘
```

**Variantes de card**:

| Variante | Background | Border | Shadow | Uso |
|----------|-----------|--------|--------|-----|
| Elevated | `surfaceContainerLowest` | none | `cardShadow` | Default en desktop |
| Filled | `surfaceContainerLow` | none | none | Default en móvil, KPI cards |
| Outlined | `surface` | 1px `outlineVariant` | none | Documentos, facturas |

**Especificaciones**:
- Corner radius: 12dp (`shape-md`)
- Padding interno: 16dp
- Espacio entre cards: 12dp (móvil), 16dp (desktop)
- Min height: 80dp (para tap targets)
- Ancho en grid: ver sección Layout

### 9.2 Botones

| Tipo | Uso | Background | Foreground | Shape |
|------|-----|-----------|------------|-------|
| Filled | Acción principal (Guardar, Confirmar) | `primary` | `onPrimary` | 8dp radius |
| Filled Tonal | Acción secundaria importante | `secondaryContainer` | `onSecondaryContainer` | 8dp radius |
| Outlined | Acción secundaria (Cancelar, Filtrar) | transparent | `primary` | 8dp radius, border `outline` |
| Text | Acción terciaria, links | transparent | `primary` | 8dp radius |
| FAB | Acción flotante principal (Nueva venta) | `primaryContainer` | `onPrimaryContainer` | 16dp radius |
| Extended FAB | FAB con texto (+ Nueva Venta) | `primaryContainer` | `onPrimaryContainer` | 16dp radius |

**Tamaños de botón**:
- Height: 40dp (default), 56dp (FAB)
- Min width: 64dp
- Padding horizontal: 24dp (filled), 12dp (icon button)
- Icon + text gap: 8dp

### 9.3 Inputs (TextFields)

```
┌─────────────────────────────────────────┐
│  Label (floating)                       │
│  ┌───────────────────────────────────┐  │
│  │ ✏️  Placeholder text...         ▼ │  │  ← Height: 56dp
│  └───────────────────────────────────┘  │
│  Helper text / Error text               │
└─────────────────────────────────────────┘
```

- Estilo: **Outlined** (no Filled) — mejor legibilidad en data-heavy forms
- Border radius: 8dp
- Border color: `outline` (rest), `primary` (focus), `error` (error)
- Border width: 1dp (rest), 2dp (focus)
- Padding: 16dp horizontal, 14dp vertical
- Label: `bodySmall` en rest, floats a `labelSmall` en focus
- Helper: `bodySmall` en `onSurfaceVariant`
- Error: `bodySmall` en `error`

### 9.4 Navigation Bar (Bottom — Móvil)

```
┌─────────────────────────────────────────────────────────────┐
│   🏠      💰      📦      📋     ⋯                         │
│  Inicio   Caja   Materiales Ventas  Más                    │
└─────────────────────────────────────────────────────────────┘
```

- Height: 80dp
- Background: `surfaceContainer`
- Active icon: Filled, color `onSecondaryContainer`
- Active indicator: `secondaryContainer`, pill shape (full radius)
- Active label: `labelMedium`, `onSurface`
- Inactive icon: Outlined, `onSurfaceVariant`
- Inactive label: `labelMedium`, `onSurfaceVariant`
- Max items: 5 (incluyendo "Más")
- Elevation: 2dp (tonal)

### 9.5 Navigation Rail (Tablet/Desktop)

- Width: 80dp (collapsed), 256dp (expanded with labels)
- Background: `surfaceContainerLow`
- Items: mismo estilo que bottom bar
- FAB position: top del rail
- Divider tras FAB: 16dp spacing

### 9.6 App Bar (Top)

| Variante | Uso | Height |
|----------|-----|--------|
| Small | Pantallas normales en móvil | 64dp |
| Medium | Pantallas con título largo | 112dp |
| Large | Hero sections | 152dp |

- Background: `surface` (transparente, tonal elevation on scroll)
- Title: `titleLarge` en `onSurface`
- Leading: back button 48dp touch target
- Actions: icon buttons 48dp touch target, max 3 visibles + overflow menu

### 9.7 Dialogs

- Max width: 560dp (o 90% del viewport en móvil)
- Corner radius: 28dp
- Padding: 24dp
- Title: `headlineSmall`
- Content: `bodyMedium`
- Actions: aligned right, gap 8dp between buttons
- Scrim: `Colors.black.withValues(alpha: 0.32)`

### 9.8 Bottom Sheets

- Corner radius top: 20dp
- Drag handle: 32dp × 4dp, `onSurfaceVariant` con opacity 0.4
- Background: `surfaceContainerLow`
- Max height: 90% del viewport
- Content padding: 16dp horizontal, 24dp top (bajo drag handle)

### 9.9 Chips

| Tipo | Uso | Ejemplo |
|------|-----|---------|
| Filter | Filtros activos/inactivos | Estado: Pagado, Pendiente |
| Input | Tags editables | Categorías de producto |
| Suggestion | Acciones sugeridas | "Agregar descuento" |
| Assist | Acciones con icono | "Adjuntar factura" |

- Height: 32dp
- Corner radius: 8dp
- Padding: 8dp horizontal
- Label: `labelLarge`
- Selected: `secondaryContainer` + `onSecondaryContainer`
- Unselected: transparent + border `outline`

### 9.10 Data Tables

Las tablas son CRÍTICAS en esta app (facturas, inventario, reportes).

```
┌──────────────────────────────────────────────────────┐
│  # │ Producto      │ Cantidad │  Precio │   Total    │  ← Header: bold, sticky
├──────────────────────────────────────────────────────┤
│  1 │ Harina Extra  │    50    │  $12.50 │   $625.00  │  ← Row: alternating bg
│  2 │ Maíz Molido   │    30    │  $8.00  │   $240.00  │
│  3 │ Salvado       │   100    │  $3.50  │   $350.00  │
├──────────────────────────────────────────────────────┤
│                                  Total:  │ $1,215.00  │  ← Footer: bold, primary
└──────────────────────────────────────────────────────┘
```

**En móvil** → transformar a **list of cards**:
```
┌─────────────────────────────────┐
│  Harina Extra             $625  │
│  50 × $12.50                    │
│  ─────────────────────────────  │
│  Maíz Molido              $240  │
│  30 × $8.00                     │
└─────────────────────────────────┘
```

- Header: `titleSmall`, `onSurfaceVariant`, sticky en scroll
- Rows: `bodyMedium`, alternating `surface`/`surfaceContainerLowest`
- Row height: 52dp min (48dp content + 4dp padding)
- Numbers: alineados a la derecha, font tabular figures
- Números negativos: color `error`
- Números positivos financieros: color `successGreen` (solo cuando es relevante)
- Horizontal scroll en desktop si hay muchas columnas, card pattern en móvil

### 9.11 KPI Cards

Componente custom — el más importante del dashboard:

```
┌───────────────────────────┐
│  📈  Ventas del Mes       │  ← labelLarge, onSurfaceVariant
│                           │
│  $45,230.00               │  ← headlineMedium, onSurface, bold
│                           │
│  ▲ +12.5% vs mes anterior │  ← bodySmall, successGreen / dangerRed
└───────────────────────────┘
```

- Background: `surfaceContainerLow` (filled variant)
- Corner radius: 12dp
- Padding: 16dp
- Icon: 24dp, `primary`
- Label: `labelLarge`, `onSurfaceVariant`
- Value: `headlineMedium` (mobile) / `headlineLarge` (desktop), `onSurface`, `FontWeight.w600`
- Trend: `bodySmall`, green ▲ o red ▼
- Min width: fill available, max 2 per row on mobile, 4 on desktop

---

## 10. LAYOUT RESPONSIVO

### 10.1 Breakpoints

| Clase | Rango | Nav | Panes | Columns | Margin |
|-------|-------|-----|-------|---------|--------|
| Compact | < 600dp | Bottom bar (5 items) | 1 | 4 | 16dp |
| Medium | 600–839dp | Rail 80dp | 1-2 | 8 | 24dp |
| Expanded | 840–1199dp | Rail 80dp | 2 | 12 | 24dp |
| Large | 1200dp+ | Rail expanded 256dp | 2-3 | 12 | 24dp |

### 10.2 Grid system

**Móvil (Compact) — 4 columnas**:
```
|--16dp--|--col--|--8dp--|--col--|--8dp--|--col--|--8dp--|--col--|--16dp--|
```
- KPI cards: 2 por fila (cada una ocupa 2 columnas)
- Listas: full width (4 columnas)
- Charts: full width
- Forms: full width, inputs stack verticalmente

**Desktop (Expanded) — 12 columnas**:
```
|--24dp--|--col × 12 con 16dp gutter--|--24dp--|
```
- KPI cards: 3-4 por fila
- List + Detail: 4col + 8col (o 5 + 7)
- Dashboard: grid libre con cards de distintos spans

### 10.3 Patrones de layout por pantalla

| Pantalla | Compact (Móvil) | Expanded (Desktop) |
|----------|-----------------|---------------------|
| Dashboard | KPIs stacked 2×N → charts full width | KPIs 4-col → charts 2-col |
| Caja Diaria | Summary card top → list below | Summary sidebar → list main |
| Clientes | Searchable list | List + detail side panel |
| Facturas | Card list with swipe actions | Table with inline actions |
| Nueva Venta | Full-screen form, step by step | Form + preview side by side |
| Materiales | Card grid 2-col | Table + filters sidebar |
| Reportes | Tab bar → full-width charts | Sidebar filters → charts grid |
| Empleados | Card list | Table |
| Contabilidad | Card list | Table + summary sidebar |

### 10.4 Reglas de layout

1. **Mobile-first**: diseñar primero para compact, luego adaptar hacia arriba
2. **Single pane en compact**: NUNCA dos panes en < 600dp
3. **Contenido priorizado**: en mobile, mostrar solo info esencial, detalles en expansión/bottom sheet
4. **Touch targets**: mínimo 48dp × 48dp para todos los elementos interactivos
5. **Scroll**: siempre vertical, NUNCA horizontal (excepto tablas/carousels)
6. **Pull to refresh**: en todas las listas principales
7. **FAB**: solo en pantallas de creación principal (Nueva Venta, Nueva Factura)

---

## 11. ESTADOS Y FEEDBACK

### 11.1 Estados de componentes interactivos

| Estado | Visual |
|--------|--------|
| Enabled (rest) | Colores base |
| Hovered | Overlay `primary` al 8% opacity |
| Focused | Outline `primary` 2dp + overlay 10% |
| Pressed | Overlay `primary` al 10% + ripple |
| Dragged | Elevation +3, shadow real |
| Disabled | Opacity 38%, no interactivo |
| Selected | `primaryContainer` bg, `onPrimaryContainer` fg |
| Error | Border `error`, text `error` |

### 11.2 Loading states

```dart
// Skeleton/Shimmer placeholder — usar SIEMPRE en vez de spinner solitario
// El shimmer debe reflejar la estructura real del contenido
Shimmer.fromColors(
  baseColor: theme.colorScheme.surfaceContainerHighest,
  highlightColor: theme.colorScheme.surfaceContainerLow,
  child: _buildSkeletonLayout(),
)
```

### 11.3 Empty states

Cuando una lista/sección no tiene datos:
```
┌─────────────────────────────────┐
│          📦                     │
│    No hay facturas              │  ← headlineSmall, onSurfaceVariant
│    pendientes este mes          │  ← bodyMedium, onSurfaceVariant, 60% opacity
│                                 │
│    [+ Crear Factura]            │  ← FilledTonalButton
└─────────────────────────────────┘
```

### 11.4 Snackbars / Toasts

- Position: bottom, encima del bottom nav bar
- Duration: 4 segundos (default), 10 segundos (con acción)
- Background: `inverseSurface`
- Text: `inverseOnSurface`
- Action: `inversePrimary`
- Max lines: 2

---

## 12. PANTALLAS — DISEÑO ESPECÍFICO

### 12.1 Login Page

**Layout**: Centrado, sin nav bar
```
┌─────────────────────────────────┐
│                                 │
│         [Logo 80dp]             │
│    Industrial de Molinos        │  ← headlineMedium
│                                 │
│  ┌───────────────────────────┐  │
│  │  📧  Email               │  │  ← OutlinedTextField
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │  🔒  Contraseña           │  │  ← OutlinedTextField, obscure
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Iniciar Sesión      │  │  ← FilledButton, full width
│  └───────────────────────────┘  │
│                                 │
│    ¿Olvidaste tu contraseña?    │  ← TextButton
│                                 │
│  v1.0.0                        │  ← labelSmall, opacity 0.5
└─────────────────────────────────┘
```

- Background: gradient sutil `surface` → `surfaceContainerLow`
- Form max width: 400dp (centrado en desktop)
- Logo con resplandor sutil o sombra
- Animación: fade in de 500ms al cargar

### 12.2 Dashboard

**Móvil**:
```
┌─────────────────────────────────┐
│  Industrial de Molinos      🔔  │  ← AppBar con greeting
│─────────────────────────────────│
│  ┌──────┐ ┌──────┐             │  ← KPI cards 2×2
│  │Ventas│ │Gastos│             │
│  └──────┘ └──────┘             │
│  ┌──────┐ ┌──────┐             │
│  │Clien.│ │Invent│             │
│  └──────┘ └──────┘             │
│─────────────────────────────────│
│  📊 Ventas del mes             │  ← LineChart full width
│  [gráfico]                     │
│─────────────────────────────────│
│  📋 Actividad Reciente         │  ← List of 5 últimas transacciones
│  • Factura #234 - $500         │
│  • Pago recibido - $200        │
│  • Stock bajo: Harina          │
└─────────────────────────────────┘
```

**Desktop**: KPIs en 4 columnas → charts en 2 columnas → activity feed sidebar

### 12.3 Caja Diaria

**Móvil**:
```
┌─────────────────────────────────┐
│  ← Caja Diaria         📅 Hoy  │
│─────────────────────────────────│
│  ┌─────────────────────────────┐│
│  │  Saldo del Día              ││  ← Hero card, primaryContainer
│  │  $12,450.00                 ││  ← headlineLarge, bold
│  │  Ingresos: $15,000          ││  
│  │  Egresos:  -$2,550          ││
│  └─────────────────────────────┘│
│─────────────────────────────────│
│  [Ingreso] [Egreso] [Transfer] │  ← SegmentedButton o 3 chips
│─────────────────────────────────│
│  ┌─────────────────────────────┐│
│  │  09:30  Venta #234   +$500 ││  ← List tile, green amount
│  │  10:15  Pago proveedor -$200││  ← List tile, red amount
│  │  11:00  Cobro cliente +$300 ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

### 12.4 Clientes

**Móvil**: Searchable list → tap → detail bottom sheet o push page
**Desktop**: Master-detail (list left, detail right)

### 12.5 Facturas / Ventas

**Móvil**: Card list con status chip (Pagada ✓, Pendiente ⏳, Vencida ⚠), swipe-to-action
**Desktop**: DataTable con filtros top, inline actions

### 12.6 Nueva Venta (Form)

**Móvil**: Wizard/stepper vertical
1. Seleccionar cliente (search + select)
2. Agregar productos (search, qty, inline total)
3. Resumen + condiciones de pago
4. Confirmar

**Desktop**: Todo visible en 2 columnas (form left, preview/total right)

### 12.7 Materiales / Inventario

**Móvil**: Card grid 2 columnas con indicador visual de stock
**Desktop**: Table con barras de stock visual

### 12.8 Reportes / Analytics

**Móvil**: Tabs para categorías → full-width charts stacked
**Desktop**: Sidebar de filtros + main area con grid de charts

### 12.9 Contabilidad / Control IVA

**Móvil**: Card summary top → list of entries
**Desktop**: Table con filtros y resumen sidebar

---

## 13. IMPLEMENTACIÓN EN FLUTTER — app_theme.dart

```dart
import 'package:flutter/material.dart';

class AppTheme {
  // === SEED COLOR ===
  static const Color seedColor = Color(0xFF1B4F72);

  // === COLORES SEMÁNTICOS ===
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // === CHART COLORS ===
  static const List<Color> chartColors = [
    Color(0xFF1B4F72),
    Color(0xFF2E86C1),
    Color(0xFF8B5E3C),
    Color(0xFFF39C12),
    Color(0xFF27AE60),
    Color(0xFFE74C3C),
    Color(0xFF8E44AD),
    Color(0xFF16A085),
  ];

  // === LIGHT THEME ===
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ),
    // Typography
    textTheme: const TextTheme(
      // Display — solo desktop
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, height: 1.12),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.16),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.22),
      // Headline — KPIs, títulos de sección
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.25),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.29),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.33),
      // Title — app bar, subtítulos
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.27),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, height: 1.50),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.43),
      // Body — contenido general
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.50),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.43),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33),
      // Label — botones, chips, inputs
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.43),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.33),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.45),
    ),
    // Cards
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(64, 40),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(64, 40),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(64, 40),
      ),
    ),
    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: false,
    ),
    // App Bar
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
    ),
    // Navigation Bar (bottom)
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      elevation: 2,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(size: 24);
        }
        return const IconThemeData(size: 24);
      }),
    ),
    // Navigation Rail
    navigationRailTheme: const NavigationRailThemeData(
      minWidth: 80,
      groupAlignment: -0.85,
      labelType: NavigationRailLabelType.all,
      indicatorShape: StadiumBorder(),
    ),
    // FAB
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Dialogs
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 6,
    ),
    // Bottom Sheets
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    // Chips
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    // Dividers
    dividerTheme: const DividerThemeData(
      thickness: 1,
      space: 1,
    ),
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 6,
    ),
    // DataTable
    dataTableTheme: const DataTableThemeData(
      headingRowHeight: 48,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
      horizontalMargin: 16,
      columnSpacing: 16,
    ),
    // Tab Bar
    tabBarTheme: TabBarThemeData(
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 3, color: seedColor),
      ),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    ),
    // Tooltips
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
  );

  // === DARK THEME ===
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
    // Heredar mismas configuraciones de componentes que light con ajustes
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}
```

---

## 14. TOKENS DE DISEÑO — RESUMEN RÁPIDO

| Categoría | Token | Valor |
|-----------|-------|-------|
| **Color seed** | seed | `#1B4F72` |
| **Spacing base** | unit | 4dp |
| **Card radius** | shape-md | 12dp |
| **Button radius** | shape-sm | 8dp |
| **Dialog radius** | shape-xl | 28dp |
| **Bottom sheet radius** | shape-lg-inc | 20dp |
| **Input radius** | shape-sm | 8dp |
| **FAB radius** | shape-lg | 16dp |
| **Mobile margin** | margin-compact | 16dp |
| **Desktop margin** | margin-expanded | 24dp |
| **Card gap** | gap-md | 12dp (mobile), 16dp (desktop) |
| **Section gap** | gap-xl | 24dp |
| **Touch target min** | tap-target | 48dp × 48dp |
| **Nav bar height** | nav-height | 80dp |
| **App bar height** | appbar-height | 64dp |
| **Animation fast** | duration-fast | 150ms |
| **Animation medium** | duration-medium | 250ms |
| **Animation slow** | duration-slow | 350ms |
| **Easing standard** | easing | easeInOutCubicEmphasized |
| **Icon size default** | icon-md | 24dp |
| **Body text** | body-md | 14sp |
| **KPI number** | headline-md | 28sp |
| **Page title** | headline-sm | 24sp |

---

## 15. CHECKLIST DE CALIDAD POR PANTALLA

Antes de dar por terminada cualquier pantalla, verificar:

- [ ] Todos los colores usan `Theme.of(context).colorScheme.xxx` — CERO colores hardcodeados
- [ ] Tipografía usa `Theme.of(context).textTheme.xxx` — CERO tamaños manuales
- [ ] Spacing es múltiplo de 4dp
- [ ] Corner radius usa los tokens definidos (4, 8, 12, 16, 20, 28)
- [ ] Touch targets ≥ 48dp × 48dp
- [ ] Sin overflow en 360dp width (móvil más pequeño)
- [ ] Sin overflow en 430dp width (móvil estándar)
- [ ] Funciona en 1920dp width (desktop)
- [ ] Empty states diseñados (no pantalla en blanco)
- [ ] Loading states con shimmer (no spinner solitario)
- [ ] Errores se muestran en context (inline, no solo snackbar)
- [ ] Navigation bar items coinciden con router branches
- [ ] Pull-to-refresh en listas
- [ ] Números financieros alineados con tabular figures
- [ ] Contraste accesible verificado (4.5:1 mínimo texto normal)
- [ ] Animaciones con curva standard, duración apropiada

---

## 16. ARCHIVOS A MODIFICAR

| Archivo | Acción |
|---------|--------|
| `lib/core/theme/app_theme.dart` | **REESCRIBIR** — Reemplazar con implementación §13 |
| `lib/core/constants/app_constants.dart` | Agregar spacing/shape constants |
| `lib/core/theme/app_spacing.dart` | **CREAR** — Clase AppSpacing §4.2 |
| `lib/core/theme/app_shapes.dart` | **CREAR** — Clase AppShapes §5.2 |
| `lib/core/theme/app_motion.dart` | **CREAR** — Clase AppMotion §7.1 |
| `lib/core/theme/app_elevation.dart` | **CREAR** — Clase AppElevation §6.2 |
| Todas las pantallas en `lib/presentation/pages/` | Migrar colores/sizes a tokens del tema |
| `lib/presentation/widgets/` | Actualizar widgets compartidos al nuevo sistema |

---

> **Nota para el rediseño**: Este documento define el SISTEMA. Cada pantalla debe rediseñarse
> siguiendo estos tokens y reglas, no copiando el diseño anterior. El objetivo es que TODAS
> las pantallas se vean como parte de la misma familia visual, con coherencia total en color,
> tipografía, espaciado, shapes y animaciones.
