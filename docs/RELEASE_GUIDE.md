# Guia de Release - Industrial de Molinos

## Proceso para publicar una nueva version

### Archivos que se deben actualizar con cada release

| # | Archivo | Que cambiar |
|---|---------|-------------|
| 1 | `pubspec.yaml` | `version: X.Y.Z+N` (linea 5) |
| 2 | `lib/core/constants/app_constants.dart` | `appVersion = 'X.Y.Z'` y `appBuildNumber = N` |
| 3 | `installer/molinos_app.iss` | `#define MyAppVersion "X.Y.Z"` (linea 11) |
| 4 | `CHANGELOG.md` | Agregar seccion con la nueva version y cambios |

**IMPORTANTE:** Los 3 primeros archivos DEBEN tener la misma version. El build_number debe ser siempre incremental (nunca repetir ni bajar).

### Formato de version

```
MAJOR.MINOR.PATCH+BUILD_NUMBER

Ejemplos:
  1.0.0+1   → Release inicial
  1.0.1+2   → Correccion de bug
  1.1.0+3   → Nueva funcionalidad
  2.0.0+4   → Cambio mayor
```

- **MAJOR**: Cambios grandes o incompatibles
- **MINOR**: Nueva funcionalidad
- **PATCH**: Correccion de bugs
- **BUILD_NUMBER**: Siempre se incrementa en +1 con cada release, nunca se repite

### Pasos del release

#### Paso 1: Actualizar version en los 3 archivos

Ejemplo para version 1.1.0, build 2:

**pubspec.yaml** (linea 5):
```yaml
version: 1.1.0+2
```

**lib/core/constants/app_constants.dart**:
```dart
static const String appVersion = '1.1.0';
static const int appBuildNumber = 2;
```

**installer/molinos_app.iss** (linea 11):
```ini
#define MyAppVersion "1.1.0"
```

#### Paso 2: Actualizar CHANGELOG.md

Agregar una nueva seccion al inicio del changelog (despues del encabezado), con el formato:

```markdown
## [1.1.0] - YYYY-MM-DD

### Agregado
- Descripcion de features nuevos

### Corregido
- Descripcion de bugs corregidos

### Cambiado
- Descripcion de cambios en funcionalidad existente
```

#### Paso 3: Compilar

Ejecutar en terminal desde la raiz del proyecto:

```powershell
flutter build windows --release
```

Verificar que el .exe se genero:
```powershell
Test-Path "build\windows\x64\runner\Release\molinos_app.exe"
```

#### Paso 4: Generar instalador

```powershell
& "C:\Users\wilo\AppData\Local\Programs\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.1.0 "installer\molinos_app.iss"
```

El instalador se genera en: `build\installer\MolinosApp_Setup_X.Y.Z.exe`

**Alternativa:** Ejecutar `build_release.bat` que hace los pasos 3 y 4 automaticamente.

#### Paso 5: Actualizar tabla app_releases en Supabase

Ejecutar en el SQL Editor de Supabase:

```sql
INSERT INTO app_releases (version, build_number, download_url, release_notes, is_mandatory, is_active, file_size_mb)
VALUES (
    '1.1.0',
    2,
    'URL_DEL_INSTALADOR_AQUI',
    'Descripcion de los cambios de esta version',
    false,
    true,
    16.3
);
```

**Notas:**
- `download_url`: URL donde se subio el instalador (GitHub Releases, servidor, etc.)
- `is_mandatory`: Poner `true` si es una actualizacion critica que el usuario DEBE instalar
- `file_size_mb`: Tamano del instalador en MB (verificar con `Get-Item build\installer\*.exe | Select-Object Length`)

#### Paso 6: Git tag (opcional pero recomendado)

```bash
git add -A
git commit -m "Release v1.1.0 - descripcion breve"
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin main --tags
```

---

## Estructura del sistema de auto-update

### Como funciona

1. La app se abre
2. Espera 3 segundos para que la UI cargue
3. Consulta la tabla `app_releases` en Supabase (busca la version activa con mayor `build_number`)
4. Compara el `build_number` del servidor contra `AppConstants.appBuildNumber`
5. Si el servidor tiene un build mayor Y tiene `download_url` no vacio → muestra dialogo
6. El dialogo muestra version, notas del release y boton "Descargar"
7. El boton abre la URL de descarga en el navegador del sistema
8. El usuario descarga y ejecuta el nuevo instalador (sobreescribe la version anterior)

### Archivos involucrados

| Archivo | Funcion |
|---------|---------|
| `lib/data/datasources/app_update_datasource.dart` | Servicio que consulta Supabase y compara versiones |
| `lib/presentation/widgets/update_dialog.dart` | Widget del dialogo de actualizacion |
| `lib/main.dart` | Llama a `_checkForUpdates()` al iniciar la app |
| `lib/core/constants/app_constants.dart` | Contiene `appVersion` y `appBuildNumber` actuales |
| `supabase_migrations/054_app_releases.sql` | Esquema de la tabla `app_releases` |

### Tabla app_releases (Supabase)

| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | UUID | PK auto-generado |
| version | TEXT | Version semantica (ej: '1.1.0') |
| build_number | INTEGER | Numero incremental de build |
| download_url | TEXT | URL del instalador .exe |
| release_notes | TEXT | Notas del release |
| is_mandatory | BOOLEAN | Si true, el usuario no puede cerrar el dialogo |
| is_active | BOOLEAN | Si false, esta version se ignora |
| min_version | TEXT | Version minima requerida para actualizar |
| file_size_mb | DECIMAL | Tamano del archivo en MB |
| created_at | TIMESTAMPTZ | Fecha de creacion |

---

## Herramientas necesarias

- **Flutter SDK** (para compilar la app)
- **Visual Studio Build Tools** (compilador C++ para Windows)
- **Inno Setup 6** (para crear el instalador) - Instalado en: `C:\Users\wilo\AppData\Local\Programs\Inno Setup 6\`
- **Supabase Dashboard** (para actualizar la tabla de releases)

## Rutas importantes

| Que | Ruta |
|-----|------|
| Proyecto | `c:\Users\wilo\OneDrive\Desktop\industrial de molinos\` |
| Build output | `build\windows\x64\runner\Release\` |
| Instalador output | `build\installer\` |
| Script Inno Setup | `installer\molinos_app.iss` |
| Script automatizado | `build_release.bat` |
