# 🏭 Industrial de Molinos - Sistema de Gestión Contable

Sistema de gestión contable para PYME desarrollado con Flutter, con soporte offline y sincronización con Supabase.

![Flutter](https://img.shields.io/badge/Flutter-3.38.1-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.10.0-0175C2?logo=dart)
![Supabase](https://img.shields.io/badge/Supabase-Cloud-3ECF8E?logo=supabase)

## 📋 Características

- ✅ **Multiplataforma**: Windows, Web, Android, iOS
- ✅ **Offline-first**: Funciona sin conexión a internet
- ✅ **Sincronización cloud**: Con Supabase
- ✅ **Material Design 3**: UI moderna y responsiva
- ✅ **Clean Architecture**: Código mantenible y testeable

## 🚀 Módulos

- 📊 **Dashboard**: KPIs, gráficos, resumen ejecutivo
- 📦 **Inventario**: Productos, stock, movimientos
- 👥 **Clientes**: Gestión de clientes y créditos
- 🧾 **Ventas**: Facturación y cuentas por cobrar
- 📈 **Reportes**: Estados financieros y análisis
- ⚙️ **Configuración**: Empresa, usuarios, sincronización

## 🛠️ Tecnologías

| Capa | Tecnología |
|------|------------|
| UI | Flutter + Material Design 3 |
| State Management | Riverpod |
| Navegación | GoRouter |
| Base de datos local | SQLite (sqflite) |
| Backend remoto | Supabase |
| Gráficos | fl_chart |

## 📁 Estructura del Proyecto

```
lib/
├── core/           # Constantes, tema, utilidades
├── domain/         # Entidades y repositorios (interfaces)
├── data/           # Datasources e implementaciones
└── presentation/   # UI (pages, widgets, providers)
```

## 🏃 Ejecutar el Proyecto

### Requisitos previos
- Flutter SDK 3.38.1+
- Dart SDK 3.10.0+

### Desarrollo

```bash
# Obtener dependencias
flutter pub get

# Ejecutar en Chrome (web)
flutter run -d chrome

# Ejecutar en Windows
flutter run -d windows

# Ejecutar en Android
flutter run -d android
```

### Build de Producción

```bash
# Build Windows
flutter build windows

# Build Web
flutter build web

# Build Android APK
flutter build apk
```

## 📄 Documentación

Ver documentación completa en [docs/INVESTIGACION_PROYECTO.md](docs/INVESTIGACION_PROYECTO.md)

## 📞 Contacto

**Proyecto:** Industrial de Molinos  
**Fecha inicio:** 8 de Diciembre, 2025

---

Desarrollado con ❤️ usando Flutter
