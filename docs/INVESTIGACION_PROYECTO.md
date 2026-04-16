# 📋 INVESTIGACIÓN Y PLANIFICACIÓN DEL PROYECTO
## Sistema de Gestión Contable para PYME - "Industrial de Molinos"

**Fecha de creación:** 8 de Diciembre, 2025  
**Versión:** 1.0  
**Estado:** Investigación Inicial

---

## 📑 ÍNDICE

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Análisis de Aplicaciones Similares](#2-análisis-de-aplicaciones-similares)
3. [Módulos y Funcionalidades](#3-módulos-y-funcionalidades)
4. [Arquitectura de Software](#4-arquitectura-de-software)
5. [Stack Tecnológico Recomendado](#5-stack-tecnológico-recomendado)
6. [Visualización de Datos](#6-visualización-de-datos)
7. [Integración con Supabase](#7-integración-con-supabase)
8. [Estructura del Proyecto](#8-estructura-del-proyecto)
9. [Diseño de Base de Datos](#9-diseño-de-base-de-datos)
10. [Plan de Implementación](#10-plan-de-implementación)

---

## 1. RESUMEN EJECUTIVO

### 🎯 Objetivo del Proyecto
Desarrollar una aplicación de escritorio para la gestión contable de una pequeña/mediana empresa (PYME), con almacenamiento local y sincronización con Supabase para la futura integración con una aplicación móvil.

### 📋 Requisitos Principales
- ✅ Aplicación de escritorio liviana
- ✅ Funcionar en computadores con recursos limitados
- ✅ Almacenamiento local (offline-first)
- ✅ Sincronización con Supabase (online)
- ✅ Gestión contable completa
- ✅ Manejo de inventarios
- ✅ Proyecciones financieras
- ✅ Reportes y análisis

### 🔑 Credenciales de Supabase
```
URL: https://slpawyxxqzjdkbhwikwt.supabase.co
ANON KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNscGF3eXh4cXpqZGtiaHdpa3d0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyMjk5OTMsImV4cCI6MjA4MDgwNTk5M30.ClD1mxj--zPwQ1Ey4DA9K7PrlAxwxK4vc5yEuJnoffg
```

---

## 2. ANÁLISIS DE APLICACIONES SIMILARES

### 📊 Comparativa de Software de Contabilidad para PYMEs

| Característica | Zoho Books | Wave | QuickBooks | **Nuestra App** |
|---------------|------------|------|------------|-----------------|
| Facturación | ✅ | ✅ | ✅ | ✅ |
| Inventarios | ✅ | ❌ | ✅ | ✅ |
| Reportes | ✅ | ✅ | ✅ | ✅ |
| Multi-moneda | ✅ | ❌ | ✅ | ✅ |
| Proyecciones | ❌ | ❌ | ✅ | ✅ |
| Offline | ❌ | ❌ | ❌ | ✅ |
| App móvil | ✅ | ✅ | ✅ | ✅ (futuro) |
| Costo | $$$ | Gratis | $$$$ | Propio |

### 🌟 Funcionalidades Clave Identificadas

#### De Zoho Books:
- Dashboard con métricas financieras clave
- Automatización de recordatorios
- Colaboración con contadores
- Múltiples templates de facturas
- Conexiones bancarias

#### De Wave:
- Interfaz simple y amigable
- Contabilidad de doble entrada
- Reportes de flujo de caja
- Categorización automática de transacciones

#### Mejores Prácticas Identificadas:
1. **Simplicidad** - Interfaz no sobrecargada
2. **Automatización** - Reducir entrada manual de datos
3. **Visualización clara** - Gráficos y métricas fáciles de entender
4. **Seguridad** - Encriptación de datos sensibles
5. **Respaldo** - Sincronización y backups automáticos

---

## 3. MÓDULOS Y FUNCIONALIDADES

### 📦 Módulo 1: Dashboard Principal
```
┌─────────────────────────────────────────────────────────────┐
│                    DASHBOARD PRINCIPAL                       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ Ingresos │ │ Gastos   │ │ Balance  │ │ Cuentas  │       │
│  │ del Mes  │ │ del Mes  │ │ General  │ │ x Cobrar │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│                                                              │
│  ┌─────────────────────────┐ ┌─────────────────────────┐   │
│  │   Gráfico de Ingresos   │ │   Productos más        │   │
│  │   vs Gastos (6 meses)   │ │   Vendidos             │   │
│  └─────────────────────────┘ └─────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            Alertas y Notificaciones                   │  │
│  │  • Stock bajo: Producto X (5 unidades)               │  │
│  │  • Factura vencida: Cliente Y                        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**KPIs del Dashboard:**
- 💰 Ingresos totales del período
- 📉 Gastos totales del período
- 📊 Margen de beneficio
- 📈 Comparativa vs período anterior
- ⚠️ Cuentas por cobrar vencidas
- 📦 Alertas de inventario bajo

### 💳 Módulo 2: Contabilidad

#### 2.1 Plan de Cuentas
- Activos
- Pasivos
- Capital
- Ingresos
- Gastos

#### 2.2 Movimientos Contables
- Libro Diario
- Libro Mayor
- Balance de Comprobación
- Asientos automáticos

#### 2.3 Cuentas por Cobrar/Pagar
- Registro de deudores
- Registro de acreedores
- Vencimientos y alertas
- Estados de cuenta

### 🧾 Módulo 3: Facturación

#### 3.1 Ventas
- Cotizaciones
- Facturas de venta
- Notas de crédito
- Recibos de pago

#### 3.2 Compras
- Órdenes de compra
- Facturas de proveedor
- Registro de pagos
- Devoluciones

### 📦 Módulo 4: Inventario

#### 4.1 Productos
- Catálogo de productos
- Categorías
- Unidades de medida
- Códigos de barras

#### 4.2 Control de Stock
- Kardex de inventario
- Ajustes de inventario
- Transferencias entre almacenes
- Alertas de stock mínimo

#### 4.3 Valorización
- Método PEPS (Primero en Entrar, Primero en Salir)
- Costo promedio
- Reportes de valorización

### 📈 Módulo 5: Reportes y Análisis

#### 5.1 Reportes Financieros
- Estado de Resultados
- Balance General
- Flujo de Caja
- Análisis de Rentabilidad

#### 5.2 Reportes de Gestión
- Ventas por período/cliente/producto
- Compras por proveedor
- Inventario valorizado
- Cartera de clientes

### 🔮 Módulo 6: Proyecciones

#### 6.1 Proyecciones Financieras
- Proyección de ventas
- Proyección de gastos
- Flujo de caja proyectado
- Punto de equilibrio

#### 6.2 Análisis de Escenarios
- Escenario optimista
- Escenario conservador
- Escenario pesimista
- What-if analysis

### ⚙️ Módulo 7: Configuración

#### 7.1 Empresa
- Datos de la empresa
- Logo y personalización
- Configuración fiscal

#### 7.2 Usuarios
- Gestión de usuarios
- Roles y permisos
- Auditoría de acciones

#### 7.3 Sistema
- Sincronización con Supabase
- Respaldo de datos
- Importar/Exportar datos

---

## 4. ARQUITECTURA DE SOFTWARE

### 🏗️ Clean Architecture (Arquitectura Limpia)

Basándonos en los principios de Uncle Bob, implementaremos una arquitectura en capas que garantiza:

1. **Independencia del Framework** - No depender de librerías específicas
2. **Testeable** - Reglas de negocio probables sin UI/DB
3. **Independencia de la UI** - Poder cambiar la interfaz sin afectar la lógica
4. **Independencia de la Base de Datos** - Poder cambiar SQLite por otra DB
5. **Independencia de agentes externos** - Las reglas de negocio no conocen el mundo exterior

```
┌─────────────────────────────────────────────────────────────────┐
│                    FRAMEWORKS & DRIVERS                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │   Flutter   │ │   SQLite    │ │  Supabase   │               │
│  │   (UI)      │ │   (Local)   │ │  (Remote)   │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
├─────────────────────────────────────────────────────────────────┤
│                    INTERFACE ADAPTERS                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │  Providers  │ │   Pages/    │ │ Repositories│               │
│  │ (Riverpod)  │ │  Widgets    │ │  (Impl)     │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
├─────────────────────────────────────────────────────────────────┤
│                    APPLICATION BUSINESS RULES                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      USE CASES                           │   │
│  │  • CrearFactura  • RegistrarPago  • CalcularBalance     │   │
│  │  • AgregarProducto  • AjustarInventario  • GenerarReporte│   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                    ENTERPRISE BUSINESS RULES                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      ENTITIES                            │   │
│  │  • Factura  • Producto  • Cliente  • Cuenta             │   │
│  │  • MovimientoContable  • Inventario  • Usuario          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 📁 Regla de Dependencia

```
        Entities (Core)
             ↑
        Use Cases
             ↑
    Interface Adapters
             ↑
   Frameworks & Drivers
```

**La dependencia SIEMPRE apunta hacia adentro**. Los círculos internos no conocen nada de los externos.

---

## 5. STACK TECNOLÓGICO RECOMENDADO

### 🚀 Framework Multiplataforma: **Flutter**

**¿Por qué Flutter?**

| Aspecto | Flutter | Electron | Tauri |
|---------|---------|----------|-------|
| Tamaño del ejecutable | ~15-25MB | ~150MB+ | ~3-10MB |
| Uso de RAM | ~50-80MB | ~150-300MB | ~20-40MB |
| Lenguaje | Dart | JavaScript | Rust + JS |
| Multiplataforma | Windows, Mac, Linux, Web, iOS, Android | Desktop + Web | Desktop |
| Hot Reload | ✅ Excelente | ❌ | ❌ |
| UI Nativa | Skia (60fps) | Web View | Web View |
| Ecosistema | Muy maduro | Muy maduro | En crecimiento |

**Ventajas de Flutter para este proyecto:**
- ✅ **Una sola base de código** para desktop, web y móvil
- ✅ **Hot reload** - desarrollo ultra rápido
- ✅ **Rendimiento nativo** - UI a 60fps con Skia
- ✅ **Material Design 3** incluido
- ✅ **Dart** - lenguaje fácil, tipado fuerte, null safety
- ✅ **Ecosistema maduro** - muchos paquetes disponibles
- ✅ **Futuro móvil** - misma app para Android/iOS

### 🎨 Stack de Desarrollo Flutter

```dart
// Dependencias principales (pubspec.yaml)
dependencies:
  flutter: sdk
  
  # Base de datos
  supabase_flutter: ^2.8.4      # Supabase oficial
  sqflite: ^2.4.2               # SQLite local (desktop/mobile)
  path: ^1.9.1                  # Manejo de rutas
  
  # Estado y navegación
  flutter_riverpod: ^2.6.1      # State management reactivo
  go_router: ^15.1.1            # Navegación declarativa
  
  # UI y utilidades
  fl_chart: ^1.0.0              # Gráficos animados
  intl: ^0.20.2                 # Internacionalización
  uuid: ^4.5.1                  # Generación de IDs únicos
```

**¿Por qué esta combinación?**
- **Riverpod**: State management moderno, compile-safe, testeable
- **GoRouter**: Navegación declarativa, deep linking, guards
- **fl_chart**: Gráficos hermosos y animados para dashboards
- **Supabase Flutter**: SDK oficial con auth, realtime, storage

### 🗄️ Base de Datos Local: **SQLite (sqflite)**

```dart
// Características de sqflite
- Base de datos embebida, sin servidor
- Un solo archivo .db
- Soporte para Windows, macOS, Linux, Android, iOS
- Transacciones ACID
- Queries SQL nativas
```

**Ventajas de SQLite:**
- ✅ No requiere servidor de base de datos
- ✅ Un solo archivo para toda la DB
- ✅ Extremadamente rápido para lecturas
- ✅ Soporta hasta 281TB de datos
- ✅ ACID compliant
- ✅ Cero configuración

### ☁️ Backend Remoto: **Supabase**

```dart
// Supabase Features a usar
- PostgreSQL (Base de datos remota)
- Supabase Auth (Autenticación con email, Google, etc.)
- Realtime (Sincronización en tiempo real con streams)
- Storage (Archivos/imágenes de productos)
- Edge Functions (Lógica serverless para reportes)
```

### 📦 Resumen del Stack

```
┌────────────────────────────────────────────────────────────┐
│                    UI & BUSINESS LOGIC                      │
│           Flutter + Dart + Material Design 3                │
├────────────────────────────────────────────────────────────┤
│                    STATE MANAGEMENT                         │
│              Riverpod + GoRouter Navigation                 │
├────────────────────────────────────────────────────────────┤
│                      LOCAL DATABASE                         │
│                    SQLite (sqflite)                         │
├────────────────────────────────────────────────────────────┤
│                      REMOTE BACKEND                         │
│          Supabase (PostgreSQL + Auth + Realtime)           │
├────────────────────────────────────────────────────────────┤
│                      PLATAFORMAS                            │
│         Windows │ macOS │ Linux │ Web │ Android │ iOS      │
└────────────────────────────────────────────────────────────┘
```

---

## 6. VISUALIZACIÓN DE DATOS

### 📊 Tipos de Gráficos Recomendados

#### Para el Dashboard:
| Métrica | Tipo de Gráfico | Justificación |
|---------|-----------------|---------------|
| Ingresos vs Gastos | Gráfico de líneas | Muestra tendencia temporal |
| Distribución de gastos | Gráfico circular/dona | Proporciones claras |
| Ventas por producto | Gráfico de barras | Comparación directa |
| Flujo de caja | Gráfico de área | Volumen acumulado |
| KPIs | Tarjetas con indicadores | Lectura rápida |
| Comparativas | Gráfico de barras agrupadas | Antes vs después |

### 🎨 Paleta de Colores Financieros

```css
/* Colores Semánticos */
--color-income: #10B981;     /* Verde - Ingresos */
--color-expense: #EF4444;    /* Rojo - Gastos */
--color-neutral: #6B7280;    /* Gris - Neutral */
--color-warning: #F59E0B;    /* Amarillo - Alerta */
--color-info: #3B82F6;       /* Azul - Información */

/* Colores para gráficos */
--chart-1: #0088FE;
--chart-2: #00C49F;
--chart-3: #FFBB28;
--chart-4: #FF8042;
--chart-5: #8884D8;
```

### 📐 Principios de Diseño de Dashboards

1. **Jerarquía Visual**: Lo más importante arriba/izquierda
2. **Regla de los 5 segundos**: Info clave visible inmediatamente
3. **Consistencia**: Mismos colores para mismos conceptos
4. **Espacio en blanco**: No sobrecargar la pantalla
5. **Responsive**: Adaptable a diferentes resoluciones
6. **Modo oscuro**: Reducir fatiga visual

### 📱 Layout del Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                           │
│  │ KPI │ │ KPI │ │ KPI │ │ KPI │    ← Métricas Principales │
│  └─────┘ └─────┘ └─────┘ └─────┘                           │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────┐ ┌───────────────────────┐       │
│  │                       │ │                       │       │
│  │   Gráfico Principal   │ │   Gráfico Secundario  │       │
│  │    (Líneas/Área)      │ │    (Barras/Dona)      │       │
│  │                       │ │                       │       │
│  └───────────────────────┘ └───────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────┐ ┌───────────────────────┐       │
│  │   Tabla Resumen       │ │   Alertas/Tareas      │       │
│  │   (Top 5 productos)   │ │   Pendientes          │       │
│  └───────────────────────┘ └───────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. INTEGRACIÓN CON SUPABASE

### 🔄 Estrategia de Sincronización: Offline-First

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUJO DE DATOS                            │
│                                                              │
│   ┌──────────┐                          ┌──────────┐        │
│   │  Usuario │                          │ Supabase │        │
│   └────┬─────┘                          └────┬─────┘        │
│        │                                     │              │
│        ▼                                     │              │
│   ┌──────────┐      Sync cuando hay         │              │
│   │  SQLite  │ ◄─── conexión a internet ───►│              │
│   │  (Local) │                              │              │
│   └──────────┘                              │              │
│        │                                     │              │
│        │  Siempre lee/escribe               │              │
│        │  primero en local                  │              │
│        ▼                                     │              │
│   ┌──────────┐                              │              │
│   │   App    │                              │              │
│   └──────────┘                              │              │
└─────────────────────────────────────────────────────────────┘
```

### 📝 Configuración de Supabase Client

```typescript
// src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'

const supabaseUrl = process.env.SUPABASE_URL    // Configurar en .env
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY  // Configurar en .env

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
})
```

### 🔐 Seguridad y Row Level Security (RLS)

```sql
-- Ejemplo de política RLS para la tabla de facturas
CREATE POLICY "Users can only see their company invoices"
ON invoices
FOR SELECT
USING (company_id = auth.jwt() ->> 'company_id');

CREATE POLICY "Users can insert invoices for their company"
ON invoices
FOR INSERT
WITH CHECK (company_id = auth.jwt() ->> 'company_id');
```

### 🔄 Sistema de Sincronización

```dart
// lib/data/services/sync_service.dart

class SyncRecord {
  final String id;
  final String tableName;
  final String operation; // 'INSERT', 'UPDATE', 'DELETE'
  final Map<String, dynamic> data;
  final bool synced;
  final DateTime createdAt;

  SyncRecord({
    required this.id,
    required this.tableName,
    required this.operation,
    required this.data,
    this.synced = false,
    required this.createdAt,
  });
}

class SyncService {
  final LocalDatabase _localDb;
  final SupabaseDataSource _supabase;

  SyncService(this._localDb, this._supabase);

  // Registrar un cambio local para sincronizar después
  Future<void> trackChange(String table, String operation, Map<String, dynamic> data) async {
    final record = SyncRecord(
      id: const Uuid().v4(),
      tableName: table,
      operation: operation,
      data: data,
      synced: false,
      createdAt: DateTime.now(),
    );
    
    // Guardar en cola de sincronización local
    await _localDb.savePendingChange(record);
  }

  // Sincronizar cuando hay conexión
  Future<void> sync() async {
    // Verificar conexión a internet
    // if (!await hasInternetConnection()) return;

    final pending = await _localDb.getPendingChanges();
    
    for (final change in pending) {
      try {
        await _pushToSupabase(change);
        await _localDb.markAsSynced(change.id);
      } catch (e) {
        print('Error de sincronización: $e');
      }
    }

    // Descargar cambios del servidor
    await _pullFromSupabase();
  }

  Future<void> _pushToSupabase(SyncRecord change) async {
    // Implementar push según la operación
  }

  Future<void> _pullFromSupabase() async {
    // Implementar pull de datos remotos
  }
}
```

### 📊 Tablas de Supabase (Schema Inicial)

```sql
-- Schema para Supabase
-- Estas tablas serán espejo de SQLite local

-- Empresas
CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  tax_id TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Usuarios
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  company_id UUID REFERENCES companies(id),
  full_name TEXT,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Plan de Cuentas
CREATE TABLE chart_of_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- asset, liability, equity, income, expense
  parent_id UUID REFERENCES chart_of_accounts(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Clientes
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  name TEXT NOT NULL,
  tax_id TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  credit_limit DECIMAL(15,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Proveedores
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  name TEXT NOT NULL,
  tax_id TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Productos
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  category_id UUID,
  unit_of_measure TEXT,
  cost_price DECIMAL(15,2) DEFAULT 0,
  sale_price DECIMAL(15,2) DEFAULT 0,
  min_stock DECIMAL(15,2) DEFAULT 0,
  current_stock DECIMAL(15,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Facturas
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  customer_id UUID REFERENCES customers(id),
  invoice_number TEXT NOT NULL,
  invoice_date DATE NOT NULL,
  due_date DATE,
  subtotal DECIMAL(15,2) NOT NULL,
  tax_amount DECIMAL(15,2) DEFAULT 0,
  total DECIMAL(15,2) NOT NULL,
  status TEXT DEFAULT 'draft', -- draft, sent, paid, cancelled
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Detalle de Facturas
CREATE TABLE invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID REFERENCES invoices(id),
  product_id UUID REFERENCES products(id),
  description TEXT,
  quantity DECIMAL(15,2) NOT NULL,
  unit_price DECIMAL(15,2) NOT NULL,
  discount DECIMAL(15,2) DEFAULT 0,
  tax_rate DECIMAL(5,2) DEFAULT 0,
  total DECIMAL(15,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Movimientos de Inventario
CREATE TABLE inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  product_id UUID REFERENCES products(id),
  movement_type TEXT NOT NULL, -- purchase, sale, adjustment, transfer
  quantity DECIMAL(15,2) NOT NULL,
  unit_cost DECIMAL(15,2),
  reference_id UUID, -- id de factura o documento relacionado
  reference_type TEXT, -- invoice, purchase, adjustment
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Asientos Contables
CREATE TABLE journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  entry_date DATE NOT NULL,
  description TEXT,
  reference TEXT,
  is_posted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Detalle de Asientos
CREATE TABLE journal_entry_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_entry_id UUID REFERENCES journal_entries(id),
  account_id UUID REFERENCES chart_of_accounts(id),
  debit DECIMAL(15,2) DEFAULT 0,
  credit DECIMAL(15,2) DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de sincronización
CREATE TABLE sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  operation TEXT NOT NULL,
  device_id TEXT,
  synced_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para mejor rendimiento
CREATE INDEX idx_invoices_company ON invoices(company_id);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);
CREATE INDEX idx_invoices_date ON invoices(invoice_date);
CREATE INDEX idx_products_company ON products(company_id);
CREATE INDEX idx_inventory_product ON inventory_movements(product_id);
CREATE INDEX idx_journal_company ON journal_entries(company_id);
```

---

## 8. ESTRUCTURA DEL PROYECTO

### 📁 Estructura de Carpetas (Clean Architecture - Flutter)

```
molinos_app/
├── 📁 lib/
│   ├── 📁 core/                        # Utilidades compartidas
│   │   ├── 📁 constants/
│   │   │   └── app_constants.dart      # Constantes de la app, credenciales Supabase
│   │   ├── 📁 theme/
│   │   │   └── app_theme.dart          # Temas claro/oscuro, Material Design 3
│   │   └── 📁 utils/
│   │       └── helpers.dart            # Formateadores, validadores
│   │
│   ├── 📁 domain/                      # Capa de dominio (Entidades)
│   │   ├── 📁 entities/
│   │   │   ├── product.dart            # Entidad Producto
│   │   │   ├── customer.dart           # Entidad Cliente
│   │   │   ├── invoice.dart            # Entidad Factura
│   │   │   ├── account.dart            # Entidad Cuenta Contable
│   │   │   └── journal_entry.dart      # Entidad Asiento Contable
│   │   │
│   │   └── 📁 repositories/            # Contratos/Interfaces (abstracciones)
│   │       ├── product_repository.dart
│   │       ├── customer_repository.dart
│   │       ├── invoice_repository.dart
│   │       └── sync_repository.dart
│   │
│   ├── 📁 data/                        # Capa de datos (Implementaciones)
│   │   ├── 📁 datasources/
│   │   │   ├── local_database.dart     # SQLite - Base de datos local
│   │   │   └── supabase_datasource.dart # Supabase - Backend remoto
│   │   │
│   │   ├── 📁 models/                  # Modelos con serialización
│   │   │   ├── product_model.dart
│   │   │   ├── customer_model.dart
│   │   │   └── invoice_model.dart
│   │   │
│   │   └── 📁 repositories/            # Implementaciones de repositorios
│   │       ├── product_repository_impl.dart
│   │       ├── customer_repository_impl.dart
│   │       └── invoice_repository_impl.dart
│   │
│   ├── 📁 presentation/                # Capa de presentación (UI)
│   │   ├── 📁 pages/                   # Páginas/Pantallas
│   │   │   ├── dashboard_page.dart     # Dashboard principal
│   │   │   ├── products_page.dart      # Lista de productos
│   │   │   ├── customers_page.dart     # Lista de clientes
│   │   │   ├── invoices_page.dart      # Lista de facturas
│   │   │   ├── reports_page.dart       # Reportes y gráficos
│   │   │   └── settings_page.dart      # Configuración
│   │   │
│   │   ├── 📁 widgets/                 # Widgets reutilizables
│   │   │   ├── 📁 common/              # Widgets genéricos
│   │   │   │   ├── loading_widget.dart
│   │   │   │   ├── error_widget.dart
│   │   │   │   └── empty_state.dart
│   │   │   ├── 📁 dashboard/           # Widgets del dashboard
│   │   │   │   ├── summary_card.dart
│   │   │   │   ├── chart_widget.dart
│   │   │   │   └── recent_table.dart
│   │   │   └── 📁 forms/               # Formularios
│   │   │       ├── product_form.dart
│   │   │       ├── customer_form.dart
│   │   │       └── invoice_form.dart
│   │   │
│   │   └── 📁 providers/               # Providers de Riverpod
│   │       ├── products_provider.dart
│   │       ├── customers_provider.dart
│   │       ├── invoices_provider.dart
│   │       └── sync_provider.dart
│   │
│   ├── main.dart                       # Punto de entrada
│   └── router.dart                     # Configuración de GoRouter
│
├── 📁 test/                            # Tests unitarios y de widgets
│   ├── 📁 domain/
│   ├── 📁 data/
│   └── 📁 presentation/
│
├── 📁 android/                         # Proyecto Android nativo
├── 📁 ios/                             # Proyecto iOS nativo
├── 📁 windows/                         # Proyecto Windows nativo
├── 📁 web/                             # Proyecto Web
├── 📁 docs/                            # Documentación
│   └── INVESTIGACION_PROYECTO.md
│
├── pubspec.yaml                        # Dependencias de Flutter/Dart
├── analysis_options.yaml               # Configuración de linter
└── README.md
│
├── 📁 docs/                        # Documentación
│   ├── INVESTIGACION_PROYECTO.md   # Este documento
│   ├── API.md
│   └── DEPLOYMENT.md
│
├── 📁 tests/                       # Tests
│   ├── 📁 unit/
│   ├── 📁 integration/
│   └── 📁 e2e/
│
├── package.json
├── tsconfig.json
├── tailwind.config.js
├── vite.config.ts
└── README.md
```

### 🔗 Flujo de Dependencias

```
presentation (UI)
      │
      ▼
  providers ──────────► domain ──────────► entities
  (Riverpod)              │
      │                   ▼
      │            repositories (interfaces)
      │                   │
      ▼                   ▼
   pages/           repositories (impl)
   widgets               │
                         ▼
                   datasources
                   (SQLite, Supabase)
```

---

## 9. DISEÑO DE BASE DE DATOS

### 📊 Diagrama Entidad-Relación

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  COMPANIES  │────<│   USERS     │     │  CUSTOMERS  │
│─────────────│     │─────────────│     │─────────────│
│ id (PK)     │     │ id (PK)     │     │ id (PK)     │
│ name        │     │ company_id  │     │ company_id  │
│ tax_id      │     │ full_name   │     │ name        │
│ ...         │     │ role        │     │ tax_id      │
└─────────────┘     └─────────────┘     │ ...         │
      │                                  └──────┬──────┘
      │                                         │
      │    ┌─────────────┐                     │
      ├───<│  PRODUCTS   │                     │
      │    │─────────────│                     │
      │    │ id (PK)     │                     │
      │    │ company_id  │                     │
      │    │ code        │                     │
      │    │ name        │                     │
      │    │ cost_price  │                     │
      │    │ sale_price  │                     │
      │    │ ...         │                     │
      │    └──────┬──────┘                     │
      │           │                            │
      │           │                            │
      │    ┌──────┴──────┐              ┌──────┴──────┐
      │    │ INVENTORY   │              │  INVOICES   │
      │    │ MOVEMENTS   │              │─────────────│
      │    │─────────────│              │ id (PK)     │
      │    │ id (PK)     │              │ company_id  │
      │    │ product_id  │              │ customer_id │
      │    │ quantity    │              │ number      │
      │    │ type        │              │ date        │
      │    │ ...         │              │ total       │
      │    └─────────────┘              │ status      │
      │                                 └──────┬──────┘
      │                                        │
      │    ┌─────────────┐              ┌──────┴──────┐
      ├───<│  CHART OF   │              │ INVOICE     │
      │    │  ACCOUNTS   │              │ ITEMS       │
      │    │─────────────│              │─────────────│
      │    │ id (PK)     │              │ id (PK)     │
      │    │ company_id  │              │ invoice_id  │
      │    │ code        │              │ product_id  │
      │    │ name        │              │ quantity    │
      │    │ type        │              │ unit_price  │
      │    │ parent_id   │              │ total       │
      │    └──────┬──────┘              └─────────────┘
      │           │
      │    ┌──────┴──────┐
      ├───<│  JOURNAL    │
           │  ENTRIES    │
           │─────────────│
           │ id (PK)     │
           │ company_id  │
           │ entry_date  │
           │ description │
           └──────┬──────┘
                  │
           ┌──────┴──────┐
           │ JOURNAL     │
           │ ENTRY LINES │
           │─────────────│
           │ id (PK)     │
           │ entry_id    │
           │ account_id  │
           │ debit       │
           │ credit      │
           └─────────────┘
```

---

## 10. PLAN DE IMPLEMENTACIÓN

### 📅 Fases del Proyecto

```
FASE 1: Fundamentos (Semana 1-2) ✅ COMPLETADA
├── ✅ Configurar proyecto Flutter
├── ✅ Configurar SQLite (sqflite)
├── ✅ Crear schema de base de datos local
├── ✅ Implementar estructura de carpetas (Clean Architecture)
├── ✅ Configurar Supabase datasource
└── ✅ UI básica: Dashboard y Productos

FASE 2: Core - Módulos Principales (Semana 3-4)
├── Página de Clientes
├── Página de Facturas/Ventas
├── Conexión real con base de datos
├── CRUD completo de productos
└── CRUD completo de clientes

FASE 3: Contabilidad Básica (Semana 5-6)
├── Plan de cuentas
├── Libro diario
├── Asientos contables
├── Balance de comprobación
└── UI de contabilidad

FASE 4: Inventario Avanzado (Semana 7-8)
├── Kardex de inventario
├── Movimientos de stock
├── Alertas de stock bajo
├── Reportes de inventario
└── Valorización de inventario

FASE 5: Dashboard y Reportes (Semana 9-10)
├── Gráficos con fl_chart
├── Reportes financieros
├── Estado de resultados
├── Balance general
└── KPIs en tiempo real

FASE 6: Proyecciones y Análisis (Semana 11-12)
├── Proyecciones de ventas
├── Proyecciones de gastos
├── Flujo de caja proyectado
├── Análisis de escenarios
└── Exportación de reportes

FASE 7: Sincronización Cloud (Semana 13-14)
├── Crear tablas en Supabase
├── Sincronización bidireccional
├── Manejo de conflictos
├── Modo offline completo
└── Autenticación de usuarios

FASE 8: Despliegue (Semana 15-16)
├── Build de producción Windows
├── Build para Android/iOS
├── Documentación de usuario
├── Capacitación
└── Soporte inicial
```

### ✅ Checklist de Progreso

- [x] Instalar Flutter y configurar entorno
- [x] Crear proyecto con `flutter create`
- [x] Configurar dependencias (pubspec.yaml)
- [x] Crear tema con Material Design 3
- [x] Configurar SQLite (sqflite)
- [x] Crear cliente de Supabase
- [x] Configurar estructura de carpetas
- [x] Crear entidades base (Product, Customer, Invoice)
- [x] Implementar Dashboard con NavigationRail
- [x] Implementar página de Productos
- [ ] Implementar página de Clientes
- [ ] Implementar página de Facturas
- [ ] Crear tablas en Supabase
- [ ] Conectar UI con base de datos real

---

## 📚 RECURSOS Y REFERENCIAS

### Documentación Oficial
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Riverpod](https://riverpod.dev/)
- [GoRouter](https://pub.dev/packages/go_router)
- [fl_chart](https://pub.dev/packages/fl_chart)

### Arquitectura
- [Clean Architecture - Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Clean Architecture](https://resocoder.com/flutter-clean-architecture-tdd/)

### Diseño UI/UX para Apps Financieras
- [Financial Dashboard Design Best Practices](https://www.geckoboard.com/best-practice/dashboard-design/)
- [Material Design 3](https://m3.material.io/)

---

## 🎯 PRÓXIMOS PASOS

1. **✅ Proyecto Flutter configurado** - Completado
2. **✅ Estructura Clean Architecture** - Completado
3. **En progreso:** Completar UI de todas las páginas
4. **Pendiente:** Crear tablas en Supabase según el schema
5. **Pendiente:** Conectar UI con base de datos real
6. **Pendiente:** Implementar sincronización

---

**Documento creado por:** GitHub Copilot  
**Para:** Proyecto Industrial de Molinos  
**Fecha:** 8 de Diciembre, 2025  
**Última actualización:** 8 de Diciembre, 2025 (Migrado a Flutter)

---

*Proyecto en desarrollo activo con Flutter 🚀*
