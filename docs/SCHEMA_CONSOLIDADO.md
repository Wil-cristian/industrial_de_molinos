# ESQUEMA DE BASE DE DATOS CONSOLIDADO
## Industrial de Molinos — PostgreSQL (Supabase)
**Generado**: 21 de Febrero, 2026  
**Fuente**: `database/supabase_schema.sql` + migraciones 002–033

---

## ENUM TYPES

| Enum | Valores |
|------|---------|
| `customer_type` | `'individual'`, `'business'` |
| `document_type` | `'cc'`, `'nit'`, `'ce'`, `'pasaporte'`, `'ti'`, `'ruc'`, `'dni'` |
| `stock_movement_type` | `'incoming'`, `'outgoing'`, `'adjustment'` |
| `quotation_status` | `'Borrador'`, `'Enviada'`, `'Aprobada'`, `'Rechazada'`, `'Vencida'`, `'Anulada'` |
| `component_type` | `'cylinder'`, `'circular_plate'`, `'rectangular_plate'`, `'shaft'`, `'ring'`, `'custom'`, `'product'` |
| `invoice_type` | `'invoice'`, `'receipt'`, `'credit_note'`, `'debit_note'` |
| `invoice_status` | `'draft'`, `'issued'`, `'paid'`, `'partial'`, `'cancelled'`, `'overdue'` |
| `payment_method` | `'cash'`, `'card'`, `'transfer'`, `'credit'`, `'check'` *(007 intenta agregar `'yape'`, `'plin'` pero si el tipo ya existe, se omite)* |

---

## TABLAS ELIMINADAS (migración 029)

Las siguientes tablas fueron creadas en el esquema base o en migraciones previas y **eliminadas con `DROP TABLE ... CASCADE`** en `029_eliminar_tablas_muertas.sql`:

| Tabla eliminada | Razón |
|---|---|
| `journal_entry_lines` | Contabilidad no implementada |
| `journal_entries` | Contabilidad no implementada |
| `employee_payments` | Reemplazada por `payroll` + `payroll_details` |
| `product_templates` | Reemplazada por `products.is_recipe` + `product_components` |

Adicionalmente, en migración **027**: `suppliers` fue eliminada (`DROP TABLE IF EXISTS suppliers CASCADE`) y reemplazada por la tabla `proveedores` + una vista `suppliers` que apunta a `proveedores`.

En migración **028**: `material_prices` fue renombrada a `material_prices_deprecated` y se creó una vista `material_prices` que apunta a `materials`.

---

## TABLAS ACTUALES (40 tablas)

### 1. `company_settings`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `name` | VARCHAR(255) | NOT NULL, DEFAULT 'Industrial de Molinos' |
| `trade_name` | VARCHAR(255) | |
| `ruc` | VARCHAR(11) | |
| `address` | TEXT | |
| `phone` | VARCHAR(20) | |
| `email` | VARCHAR(255) | |
| `logo_url` | TEXT | |
| `currency` | VARCHAR(10) | DEFAULT 'PEN' |
| `tax_rate` | DECIMAL(5,2) | DEFAULT 18.00 |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 2. `operational_costs`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `labor_rate_per_hour` | DECIMAL(10,2) | DEFAULT 25.00 |
| `energy_rate_per_kwh` | DECIMAL(10,4) | DEFAULT 0.50 |
| `gas_rate_per_m3` | DECIMAL(10,4) | DEFAULT 2.00 |
| `default_profit_margin` | DECIMAL(5,2) | DEFAULT 20.00 |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 3. `categories`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `name` | VARCHAR(100) | NOT NULL |
| `description` | TEXT | |
| `parent_id` | UUID | FK → categories(id) ON DELETE SET NULL |
| `is_active` | BOOLEAN | DEFAULT TRUE |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 4. `material_prices_deprecated`
**Origen**: `supabase_schema.sql` (como `material_prices`), renombrada en migración 028  
**Nota**: Existe una **vista** `material_prices` que apunta a `materials`.

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `name` | VARCHAR(100) | NOT NULL |
| `category` | VARCHAR(50) | NOT NULL |
| `type` | VARCHAR(50) | |
| `thickness` | DECIMAL(10,2) | DEFAULT 0 |
| `price_per_kg` | DECIMAL(10,2) | NOT NULL |
| `density` | DECIMAL(10,4) | DEFAULT 7.85 |
| `unit` | VARCHAR(10) | DEFAULT 'kg' |
| `is_active` | BOOLEAN | DEFAULT TRUE |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 5. `customers`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `type` | customer_type | NOT NULL, DEFAULT 'business' |
| `document_type` | document_type | NOT NULL, DEFAULT 'nit' |
| `document_number` | VARCHAR(20) | NOT NULL, UNIQUE |
| `name` | VARCHAR(255) | NOT NULL |
| `trade_name` | VARCHAR(255) | |
| `address` | TEXT | |
| `phone` | VARCHAR(20) | |
| `email` | VARCHAR(255) | |
| `credit_limit` | DECIMAL(12,2) | DEFAULT 0 |
| `current_balance` | DECIMAL(12,2) | DEFAULT 0 |
| `is_active` | BOOLEAN | DEFAULT TRUE |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 6. `products`
**Origen**: `supabase_schema.sql` + columnas agregadas en migración 008

| Columna | Tipo | Constraints | Origen |
|---------|------|-------------|--------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | base |
| `code` | VARCHAR(50) | NOT NULL, UNIQUE | base |
| `name` | VARCHAR(255) | NOT NULL | base |
| `description` | TEXT | | base |
| `category_id` | UUID | FK → categories(id) ON DELETE SET NULL | base |
| `unit_price` | DECIMAL(12,2) | NOT NULL, DEFAULT 0 | base |
| `cost_price` | DECIMAL(12,2) | NOT NULL, DEFAULT 0 | base |
| `stock` | DECIMAL(12,3) | DEFAULT 0 | base |
| `min_stock` | DECIMAL(12,3) | DEFAULT 0 | base |
| `unit` | VARCHAR(20) | DEFAULT 'UND' | base |
| `is_active` | BOOLEAN | DEFAULT TRUE | base |
| `image_url` | TEXT | | base |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | base |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() | base |
| `is_recipe` | BOOLEAN | DEFAULT false | 008 |
| `recipe_description` | TEXT | | 008 |
| `total_weight` | DECIMAL(12,2) | DEFAULT 0 | 008 |
| `total_cost` | DECIMAL(12,2) | DEFAULT 0 | 008 |

**CHECK constraints** (migración 033):
- `chk_products_stock_non_negative`: `stock >= 0`

---

### 7. `stock_movements`
**Origen**: `supabase_schema.sql` (con enum) / `007_setup_completo.sql` (con CHECK)

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `product_id` | UUID | NOT NULL, FK → products(id) ON DELETE CASCADE |
| `type` | stock_movement_type / VARCHAR(20) | NOT NULL, CHECK IN ('incoming','outgoing','adjustment') |
| `quantity` | DECIMAL(12,3) | NOT NULL |
| `previous_stock` | DECIMAL(12,3) | |
| `new_stock` | DECIMAL(12,3) | |
| `reason` | TEXT / VARCHAR(200) | |
| `reference` | VARCHAR(100) | |
| `created_by` | UUID | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 8. `quotations`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `number` | VARCHAR(20) | NOT NULL, UNIQUE |
| `date` | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| `valid_until` | DATE | NOT NULL |
| `customer_id` | UUID | FK → customers(id) ON DELETE SET NULL |
| `customer_name` | VARCHAR(255) | NOT NULL |
| `customer_document` | VARCHAR(20) | |
| `status` | quotation_status | DEFAULT 'Borrador' |
| `materials_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `labor_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `labor_hours` | DECIMAL(8,2) | DEFAULT 0 |
| `labor_rate` | DECIMAL(10,2) | DEFAULT 25.00 |
| `energy_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `gas_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `supplies_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `other_costs` | DECIMAL(12,2) | DEFAULT 0 |
| `subtotal` | DECIMAL(12,2) | DEFAULT 0 |
| `profit_margin` | DECIMAL(5,2) | DEFAULT 20.00 |
| `profit_amount` | DECIMAL(12,2) | DEFAULT 0 |
| `total` | DECIMAL(12,2) | DEFAULT 0 |
| `total_weight` | DECIMAL(12,3) | DEFAULT 0 |
| `notes` | TEXT | |
| `terms` | TEXT | |
| `created_by` | UUID | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 9. `quotation_items`
**Origen**: `supabase_schema.sql` + columnas de migraciones 009, 023, 023_quotation_item_costs, 028

| Columna | Tipo | Constraints | Origen |
|---------|------|-------------|--------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | base |
| `quotation_id` | UUID | NOT NULL, FK → quotations(id) ON DELETE CASCADE | base |
| `name` | VARCHAR(255) | NOT NULL | base |
| `description` | TEXT | | base |
| `type` | component_type | NOT NULL, DEFAULT 'custom' | base |
| `material_id` | UUID | FK → materials(id) ON DELETE SET NULL | base→reapuntada en 028 |
| `material_name` | VARCHAR(100) | | base / 009 |
| `material_type` | VARCHAR(50) | | base |
| `dimensions` | JSONB | DEFAULT '{}' | base |
| `dimensions_text` | VARCHAR(255) | | base |
| `quantity` | INTEGER | DEFAULT 1 | base |
| `unit_weight` | DECIMAL(12,3) | DEFAULT 0 | base |
| `total_weight` | DECIMAL(12,3) | DEFAULT 0 | base |
| `price_per_kg` | DECIMAL(10,2) | DEFAULT 0 | base |
| `unit_price` | DECIMAL(12,2) | DEFAULT 0 | base |
| `total_price` | DECIMAL(12,2) | DEFAULT 0 | base |
| `sort_order` | INTEGER | DEFAULT 0 | base |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | base |
| `cost_price` | DECIMAL(12,2) | DEFAULT 0 | 023_profit_margins |
| `cost_per_kg` | DECIMAL(12,2) | DEFAULT 0 | 023_quotation_item_costs |
| `unit_cost` | DECIMAL(12,2) | DEFAULT 0 | 023_quotation_item_costs |
| `total_cost` | DECIMAL(12,2) | DEFAULT 0 | 023_quotation_item_costs |

> **Nota**: La columna `inv_material_id` fue eliminada en migración 028.

---

### 10. `invoices`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `type` | invoice_type | NOT NULL, DEFAULT 'invoice' |
| `series` | VARCHAR(10) | NOT NULL |
| `number` | VARCHAR(20) | NOT NULL |
| `full_number` | VARCHAR(30) | GENERATED ALWAYS AS (series \|\| '-' \|\| number) STORED |
| `customer_id` | UUID | FK → customers(id) ON DELETE SET NULL |
| `customer_name` | VARCHAR(255) | NOT NULL |
| `customer_document` | VARCHAR(20) | |
| `customer_address` | TEXT | |
| `issue_date` | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| `due_date` | DATE | |
| `subtotal` | DECIMAL(12,2) | NOT NULL, DEFAULT 0 |
| `tax_rate` | DECIMAL(5,2) | DEFAULT 18.00 |
| `tax_amount` | DECIMAL(12,2) | DEFAULT 0 |
| `discount` | DECIMAL(12,2) | DEFAULT 0 |
| `total` | DECIMAL(12,2) | NOT NULL, DEFAULT 0 |
| `paid_amount` | DECIMAL(12,2) | DEFAULT 0 |
| `pending_amount` | DECIMAL(12,2) | GENERATED ALWAYS AS (total - paid_amount) STORED |
| `status` | invoice_status | DEFAULT 'draft' |
| `payment_method` | payment_method | |
| `quotation_id` | UUID | FK → quotations(id) ON DELETE SET NULL |
| `notes` | TEXT | |
| `created_by` | UUID | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

**UNIQUE**: `(series, number)`

---

### 11. `invoice_items`
**Origen**: `supabase_schema.sql` + columnas de 006/007, 009, 023

| Columna | Tipo | Constraints | Origen |
|---------|------|-------------|--------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | base |
| `invoice_id` | UUID | NOT NULL, FK → invoices(id) ON DELETE CASCADE | base |
| `product_id` | UUID | FK → products(id) ON DELETE SET NULL | base / 006/007 |
| `product_code` | VARCHAR(50) | | base / 007 |
| `product_name` | VARCHAR(255) | NOT NULL | base |
| `description` | TEXT | | base |
| `quantity` | DECIMAL(12,3) | NOT NULL | base |
| `unit` | VARCHAR(20) | DEFAULT 'UND' | base |
| `unit_price` | DECIMAL(12,2) | NOT NULL | base |
| `discount` | DECIMAL(12,2) | DEFAULT 0 | base |
| `tax_rate` | DECIMAL(5,2) | DEFAULT 18.00 | base |
| `subtotal` | DECIMAL(12,2) | NOT NULL | base |
| `tax_amount` | DECIMAL(12,2) | DEFAULT 0 | base |
| `total` | DECIMAL(12,2) | NOT NULL | base |
| `sort_order` | INTEGER | DEFAULT 0 | base |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | base |
| `material_id` | UUID | FK → materials(id) ON DELETE SET NULL | 009→reapuntada en 028 |
| `cost_price` | DECIMAL(12,2) | DEFAULT 0 | 023_profit_margins |

---

### 12. `payments`
**Origen**: `supabase_schema.sql` / `007_setup_completo.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `invoice_id` | UUID | NOT NULL, FK → invoices(id) ON DELETE CASCADE |
| `amount` | DECIMAL(12,2) | NOT NULL |
| `method` | payment_method | DEFAULT 'cash' |
| `reference` | VARCHAR(100) | |
| `notes` | TEXT | |
| `payment_date` | DATE | DEFAULT CURRENT_DATE |
| `created_by` | UUID | *(del esquema base; 007 no la incluye)* |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() *(del 007)* |

---

### 13. `chart_of_accounts`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `code` | VARCHAR(20) | NOT NULL, UNIQUE |
| `name` | VARCHAR(255) | NOT NULL |
| `type` | VARCHAR(50) | NOT NULL |
| `parent_code` | VARCHAR(20) | |
| `level` | INTEGER | DEFAULT 1 |
| `is_active` | BOOLEAN | DEFAULT TRUE |
| `accepts_entries` | BOOLEAN | DEFAULT TRUE |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 14. `sync_log`
**Origen**: `supabase_schema.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() |
| `table_name` | VARCHAR(100) | NOT NULL |
| `record_id` | UUID | NOT NULL |
| `action` | VARCHAR(20) | NOT NULL |
| `old_data` | JSONB | |
| `new_data` | JSONB | |
| `synced_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `device_id` | VARCHAR(100) | |

---

### 15. `accounts`
**Origen**: `002_daily_cash_tables.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `name` | VARCHAR(100) | NOT NULL |
| `type` | VARCHAR(20) | NOT NULL, DEFAULT 'cash' |
| `balance` | DECIMAL(12,2) | NOT NULL, DEFAULT 0 |
| `bank_name` | VARCHAR(100) | |
| `account_number` | VARCHAR(50) | |
| `color` | VARCHAR(10) | |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 16. `cash_movements`
**Origen**: `002_daily_cash_tables.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `account_id` | UUID | NOT NULL, FK → accounts(id) |
| `to_account_id` | UUID | FK → accounts(id) |
| `type` | VARCHAR(20) | NOT NULL |
| `category` | VARCHAR(30) | NOT NULL |
| `amount` | DECIMAL(12,2) | NOT NULL |
| `description` | VARCHAR(255) | NOT NULL |
| `reference` | VARCHAR(100) | |
| `person_name` | VARCHAR(100) | |
| `date` | TIMESTAMPTZ | NOT NULL |
| `linked_transfer_id` | VARCHAR(50) | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 17. `proveedores`
**Origen**: `005_suppliers_table.sql` + columnas agregadas en migración 027

| Columna | Tipo | Constraints | Origen |
|---------|------|-------------|--------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | 005 |
| `type` | VARCHAR(20) | DEFAULT 'business', CHECK IN ('individual','business') | 005 |
| `document_type` | VARCHAR(20) | DEFAULT 'RUC' | 005 |
| `document_number` | VARCHAR(50) | NOT NULL | 005 |
| `name` | VARCHAR(255) | NOT NULL | 005 |
| `trade_name` | VARCHAR(255) | | 005 |
| `address` | TEXT | | 005 |
| `phone` | VARCHAR(50) | | 005 |
| `email` | VARCHAR(255) | | 005 |
| `contact_person` | VARCHAR(255) | | 005 |
| `bank_account` | VARCHAR(100) | | 005 |
| `bank_name` | VARCHAR(100) | | 005 |
| `current_debt` | DECIMAL(15,2) | DEFAULT 0 | 005 |
| `is_active` | BOOLEAN | DEFAULT TRUE | 005 |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | 005 |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() | 005 |
| `code` | VARCHAR(20) | UNIQUE | 027 |
| `category` | VARCHAR(50) | | 027 |
| `payment_terms` | VARCHAR(100) | | 027 |
| `credit_limit` | DECIMAL(12,2) | DEFAULT 0 | 027 |
| `rating` | INTEGER | DEFAULT 3, CHECK (rating BETWEEN 1 AND 5) | 027 |
| `notes` | TEXT | | 027 |

> **Vista**: `suppliers` → `SELECT * FROM proveedores`

---

### 18. `materials`
**Origen**: `008_materials_y_recetas.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `code` | VARCHAR(50) | UNIQUE, NOT NULL |
| `name` | VARCHAR(200) | NOT NULL |
| `description` | TEXT | |
| `category` | VARCHAR(50) | DEFAULT 'general' |
| `shape` | VARCHAR(30) | DEFAULT 'custom' |
| `price_per_kg` | DECIMAL(12,2) | DEFAULT 0 |
| `unit_price` | DECIMAL(12,2) | DEFAULT 0 |
| `cost_price` | DECIMAL(12,2) | DEFAULT 0 |
| `stock` | DECIMAL(12,2) | DEFAULT 0 |
| `min_stock` | DECIMAL(12,2) | DEFAULT 0 |
| `unit` | VARCHAR(20) | DEFAULT 'KG' |
| `density` | DECIMAL(8,2) | DEFAULT 7850 |
| `default_thickness` | DECIMAL(8,2) | |
| `fixed_weight` | DECIMAL(8,4) | |
| `supplier` | VARCHAR(200) | |
| `location` | VARCHAR(100) | |
| `is_active` | BOOLEAN | DEFAULT true |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

**CHECK constraints** (migración 033):
- `chk_materials_stock_non_negative`: `stock >= 0 OR stock IS NULL`

---

### 19. `product_components`
**Origen**: `008_materials_y_recetas.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `product_id` | UUID | NOT NULL, FK → products(id) ON DELETE CASCADE |
| `material_id` | UUID | FK → materials(id) ON DELETE SET NULL |
| `name` | VARCHAR(200) | NOT NULL |
| `description` | TEXT | |
| `quantity` | DECIMAL(12,4) | NOT NULL, DEFAULT 1 |
| `unit` | VARCHAR(20) | DEFAULT 'KG' |
| `outer_diameter` | DECIMAL(10,2) | |
| `inner_diameter` | DECIMAL(10,2) | |
| `thickness` | DECIMAL(10,2) | |
| `length` | DECIMAL(10,2) | |
| `width` | DECIMAL(10,2) | |
| `calculated_weight` | DECIMAL(12,4) | DEFAULT 0 |
| `unit_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `total_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `sort_order` | INT | DEFAULT 0 |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 20. `material_movements`
**Origen**: `009_descontar_inventario.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `material_id` | UUID | NOT NULL, FK → materials(id) |
| `type` | VARCHAR(20) | NOT NULL |
| `quantity` | DECIMAL(12,4) | NOT NULL |
| `previous_stock` | DECIMAL(12,4) | |
| `new_stock` | DECIMAL(12,4) | |
| `reason` | VARCHAR(200) | |
| `reference` | VARCHAR(100) | |
| `quotation_id` | UUID | FK → quotations(id) |
| `invoice_id` | UUID | FK → invoices(id) |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `created_by` | VARCHAR(100) | |

---

### 21. `employees`
**Origen**: `014_analytics_tables.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `code` | VARCHAR(20) | UNIQUE |
| `first_name` | VARCHAR(100) | NOT NULL |
| `last_name` | VARCHAR(100) | NOT NULL |
| `document_type` | VARCHAR(10) | DEFAULT 'dni' |
| `document_number` | VARCHAR(20) | UNIQUE |
| `position` | VARCHAR(100) | |
| `department` | VARCHAR(50) | |
| `hire_date` | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| `termination_date` | DATE | |
| `salary` | DECIMAL(12,2) | DEFAULT 0 |
| `hourly_rate` | DECIMAL(10,2) | DEFAULT 0 |
| `phone` | VARCHAR(20) | |
| `email` | VARCHAR(255) | |
| `address` | TEXT | |
| `emergency_contact` | VARCHAR(255) | |
| `bank_name` | VARCHAR(100) | |
| `bank_account` | VARCHAR(50) | |
| `is_active` | BOOLEAN | DEFAULT TRUE |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 22. `monthly_expenses`
**Origen**: `014_analytics_tables.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `year` | INTEGER | NOT NULL |
| `month` | INTEGER | NOT NULL, CHECK (month >= 1 AND month <= 12) |
| `electricity_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `gas_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `water_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `internet_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `rent_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `maintenance_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `salaries_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `benefits_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `supplies_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `transport_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `insurance_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `taxes_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `other_cost` | DECIMAL(12,2) | DEFAULT 0 |
| `other_description` | TEXT | |
| `total_fixed` | DECIMAL(12,2) | GENERATED ALWAYS AS (sum of all costs) STORED |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

**UNIQUE**: `(year, month)`

---

### 23. `purchases`
**Origen**: `014_analytics_tables.sql`  
**FK actualizada**: migración 027 — `supplier_id` ahora referencia `proveedores(id)`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `number` | VARCHAR(20) | NOT NULL, UNIQUE |
| `date` | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| `supplier_id` | UUID | FK → proveedores(id) ON DELETE SET NULL |
| `supplier_name` | VARCHAR(255) | NOT NULL |
| `supplier_ruc` | VARCHAR(11) | |
| `subtotal` | DECIMAL(12,2) | DEFAULT 0 |
| `tax_rate` | DECIMAL(5,2) | DEFAULT 18.00 |
| `tax_amount` | DECIMAL(12,2) | DEFAULT 0 |
| `discount` | DECIMAL(12,2) | DEFAULT 0 |
| `total` | DECIMAL(12,2) | DEFAULT 0 |
| `status` | VARCHAR(20) | DEFAULT 'pending' |
| `payment_status` | VARCHAR(20) | DEFAULT 'pending' |
| `paid_amount` | DECIMAL(12,2) | DEFAULT 0 |
| `payment_method` | VARCHAR(20) | |
| `payment_date` | DATE | |
| `invoice_number` | VARCHAR(50) | |
| `delivery_date` | DATE | |
| `received_date` | DATE | |
| `notes` | TEXT | |
| `created_by` | UUID | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 24. `purchase_items`
**Origen**: `014_analytics_tables.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `purchase_id` | UUID | NOT NULL, FK → purchases(id) ON DELETE CASCADE |
| `material_id` | UUID | FK → materials(id) ON DELETE SET NULL |
| `code` | VARCHAR(50) | |
| `name` | VARCHAR(255) | NOT NULL |
| `description` | TEXT | |
| `category` | VARCHAR(50) | |
| `quantity` | DECIMAL(12,3) | NOT NULL |
| `unit` | VARCHAR(20) | DEFAULT 'UND' |
| `received_quantity` | DECIMAL(12,3) | DEFAULT 0 |
| `unit_price` | DECIMAL(12,2) | NOT NULL |
| `subtotal` | DECIMAL(12,2) | NOT NULL |
| `sort_order` | INTEGER | DEFAULT 0 |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 25. `material_price_history`
**Origen**: `014_analytics_tables.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `material_id` | UUID | NOT NULL, FK → materials(id) ON DELETE CASCADE |
| `old_price` | DECIMAL(12,2) | |
| `new_price` | DECIMAL(12,2) | |
| `old_cost` | DECIMAL(12,2) | |
| `new_cost` | DECIMAL(12,2) | |
| `changed_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `changed_by` | UUID | |
| `reason` | TEXT | |

---

### 26. `activities`
**Origen**: `016_activities_notifications.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `title` | VARCHAR(255) | NOT NULL |
| `description` | TEXT | |
| `activity_type` | VARCHAR(50) | NOT NULL, DEFAULT 'general', CHECK IN ('payment','delivery','project_start','project_end','collection','meeting','reminder','general','stock_alert','maintenance') |
| `start_date` | TIMESTAMPTZ | NOT NULL |
| `end_date` | TIMESTAMPTZ | |
| `due_date` | DATE | |
| `status` | VARCHAR(50) | NOT NULL, DEFAULT 'pending', CHECK IN ('pending','in_progress','completed','cancelled','overdue') |
| `priority` | VARCHAR(20) | NOT NULL, DEFAULT 'medium', CHECK IN ('low','medium','high','urgent') |
| `customer_id` | UUID | FK → customers(id) ON DELETE SET NULL |
| `invoice_id` | UUID | FK → invoices(id) ON DELETE SET NULL |
| `quotation_id` | UUID | FK → quotations(id) ON DELETE SET NULL |
| `reminder_enabled` | BOOLEAN | DEFAULT false |
| `reminder_date` | TIMESTAMPTZ | |
| `reminder_sent` | BOOLEAN | DEFAULT false |
| `amount` | DECIMAL(12,2) | |
| `color` | VARCHAR(20) | DEFAULT '#2196F3' |
| `icon` | VARCHAR(50) | |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `created_by` | UUID | |

---

### 27. `notifications`
**Origen**: `016_activities_notifications.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `notification_type` | VARCHAR(50) | NOT NULL, CHECK IN ('low_stock','overdue_invoice','upcoming_delivery','activity_reminder','payment_due','collection_due','general','project_update') |
| `title` | VARCHAR(255) | NOT NULL |
| `message` | TEXT | NOT NULL |
| `is_read` | BOOLEAN | DEFAULT false |
| `is_dismissed` | BOOLEAN | DEFAULT false |
| `severity` | VARCHAR(20) | NOT NULL, DEFAULT 'info', CHECK IN ('info','warning','error','success') |
| `activity_id` | UUID | FK → activities(id) ON DELETE CASCADE |
| `customer_id` | UUID | FK → customers(id) ON DELETE SET NULL |
| `invoice_id` | UUID | FK → invoices(id) ON DELETE SET NULL |
| `material_id` | UUID | FK → materials(id) ON DELETE SET NULL |
| `action_url` | VARCHAR(255) | |
| `icon` | VARCHAR(50) | |
| `data` | JSONB | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `read_at` | TIMESTAMPTZ | |
| `expires_at` | TIMESTAMPTZ | |

---

### 28. `invoice_interests`
**Origen**: `017_invoice_interests.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `invoice_id` | UUID | NOT NULL, FK → invoices(id) ON DELETE CASCADE |
| `customer_id` | UUID | NOT NULL, FK → customers(id) ON DELETE CASCADE |
| `original_amount` | DECIMAL(12,2) | NOT NULL |
| `interest_rate` | DECIMAL(5,2) | NOT NULL, DEFAULT 2.0 |
| `interest_amount` | DECIMAL(12,2) | NOT NULL |
| `total_amount` | DECIMAL(12,2) | NOT NULL |
| `days_overdue` | INTEGER | NOT NULL, DEFAULT 0 |
| `applied_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `applied_by` | UUID | FK → auth.users(id) |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 29. `payroll_concepts`
**Origen**: `018_payroll_system.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `code` | VARCHAR(20) | UNIQUE, NOT NULL |
| `name` | VARCHAR(100) | NOT NULL |
| `type` | VARCHAR(20) | NOT NULL |
| `category` | VARCHAR(50) | NOT NULL |
| `is_percentage` | BOOLEAN | DEFAULT FALSE |
| `default_value` | DECIMAL(12,2) | DEFAULT 0 |
| `affects_taxes` | BOOLEAN | DEFAULT TRUE |
| `is_active` | BOOLEAN | DEFAULT TRUE |
| `description` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 30. `payroll_periods`
**Origen**: `018_payroll_system.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `period_type` | VARCHAR(20) | NOT NULL |
| `period_number` | INTEGER | NOT NULL |
| `year` | INTEGER | NOT NULL |
| `start_date` | DATE | NOT NULL |
| `end_date` | DATE | NOT NULL |
| `payment_date` | DATE | |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'abierto' |
| `total_earnings` | DECIMAL(12,2) | DEFAULT 0 |
| `total_deductions` | DECIMAL(12,2) | DEFAULT 0 |
| `total_net` | DECIMAL(12,2) | DEFAULT 0 |
| `notes` | TEXT | |
| `closed_at` | TIMESTAMPTZ | |
| `closed_by` | UUID | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

**UNIQUE**: `(period_type, period_number, year)`

---

### 31. `payroll`
**Origen**: `018_payroll_system.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `period_id` | UUID | NOT NULL, FK → payroll_periods(id) ON DELETE CASCADE |
| `base_salary` | DECIMAL(12,2) | NOT NULL, DEFAULT 0 |
| `days_worked` | INTEGER | DEFAULT 0 |
| `days_absent` | INTEGER | DEFAULT 0 |
| `days_vacation` | INTEGER | DEFAULT 0 |
| `days_incapacity` | INTEGER | DEFAULT 0 |
| `regular_hours` | DECIMAL(6,2) | DEFAULT 0 |
| `overtime_hours_25` | DECIMAL(6,2) | DEFAULT 0 |
| `overtime_hours_35` | DECIMAL(6,2) | DEFAULT 0 |
| `overtime_hours_100` | DECIMAL(6,2) | DEFAULT 0 |
| `total_earnings` | DECIMAL(12,2) | DEFAULT 0 |
| `total_deductions` | DECIMAL(12,2) | DEFAULT 0 |
| `net_pay` | DECIMAL(12,2) | DEFAULT 0 |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'borrador' |
| `payment_date` | TIMESTAMPTZ | |
| `payment_method` | VARCHAR(30) | |
| `payment_reference` | VARCHAR(100) | |
| `account_id` | UUID | FK → accounts(id) |
| `cash_movement_id` | UUID | FK → cash_movements(id) |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `approved_by` | UUID | |
| `approved_at` | TIMESTAMPTZ | |

**UNIQUE**: `(employee_id, period_id)`

---

### 32. `payroll_details`
**Origen**: `018_payroll_system.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `payroll_id` | UUID | NOT NULL, FK → payroll(id) ON DELETE CASCADE |
| `concept_id` | UUID | NOT NULL, FK → payroll_concepts(id) |
| `concept_code` | VARCHAR(20) | NOT NULL |
| `concept_name` | VARCHAR(100) | NOT NULL |
| `type` | VARCHAR(20) | NOT NULL |
| `quantity` | DECIMAL(10,2) | DEFAULT 1 |
| `unit_value` | DECIMAL(12,2) | DEFAULT 0 |
| `amount` | DECIMAL(12,2) | NOT NULL |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 33. `employee_incapacities`
**Origen**: `018_payroll_system.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `type` | VARCHAR(30) | NOT NULL |
| `start_date` | DATE | NOT NULL |
| `end_date` | DATE | NOT NULL |
| `days_total` | INTEGER | NOT NULL |
| `certificate_number` | VARCHAR(50) | |
| `medical_entity` | VARCHAR(100) | |
| `diagnosis` | TEXT | |
| `payment_percentage` | DECIMAL(5,2) | DEFAULT 100 |
| `employer_days` | INTEGER | DEFAULT 0 |
| `status` | VARCHAR(20) | DEFAULT 'activa' |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 34. `employee_loans`
**Origen**: `018_payroll_system.sql` + columnas confirmadas en 024

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `loan_date` | DATE | NOT NULL |
| `total_amount` | DECIMAL(12,2) | NOT NULL |
| `installments` | INTEGER | NOT NULL, DEFAULT 1 |
| `installment_amount` | DECIMAL(12,2) | NOT NULL |
| `paid_amount` | DECIMAL(12,2) | DEFAULT 0 |
| `paid_installments` | INTEGER | DEFAULT 0 |
| `remaining_amount` | DECIMAL(12,2) | NOT NULL |
| `reason` | TEXT | |
| `status` | VARCHAR(20) | DEFAULT 'activo' |
| `cash_movement_id` | UUID | FK → cash_movements(id) |
| `account_id` | UUID | FK → accounts(id) |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 35. `loan_payments`
**Origen**: `018_payroll_system.sql` / recreada en 025

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `loan_id` | UUID | NOT NULL, FK → employee_loans(id) ON DELETE CASCADE |
| `payroll_id` | UUID | FK → payroll(id) |
| `payment_date` | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| `amount` | DECIMAL(12,2) | NOT NULL |
| `installment_number` | INTEGER | |
| `payment_method` | VARCHAR(20/30) | DEFAULT 'nomina' |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 36. `employee_tasks`
**Origen**: `019_employee_tasks.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `title` | VARCHAR(200) | NOT NULL |
| `description` | TEXT | |
| `assigned_date` | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| `due_date` | DATE | |
| `completed_date` | DATE | |
| `priority` | VARCHAR(20) | DEFAULT 'normal' |
| `status` | VARCHAR(20) | DEFAULT 'pendiente' |
| `category` | VARCHAR(50) | |
| `production_order_id` | UUID | |
| `notes` | TEXT | |
| `completion_notes` | TEXT | |
| `assigned_by` | UUID | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 37. `employee_time_entries`
**Origen**: `031_employee_time_tracking.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `entry_date` | DATE | NOT NULL |
| `scheduled_start` | VARCHAR(10) | |
| `scheduled_end` | VARCHAR(10) | |
| `scheduled_minutes` | INTEGER | DEFAULT 0 |
| `check_in` | TIMESTAMPTZ | |
| `check_out` | TIMESTAMPTZ | |
| `break_minutes` | INTEGER | DEFAULT 0 |
| `worked_minutes` | INTEGER | DEFAULT 0 |
| `overtime_minutes` | INTEGER | DEFAULT 0 |
| `deficit_minutes` | INTEGER | DEFAULT 0 |
| `status` | VARCHAR(20) | DEFAULT 'registrado' |
| `source` | VARCHAR(20) | DEFAULT 'manual' |
| `notes` | TEXT | |
| `approval_notes` | TEXT | |
| `approved_by` | UUID | FK → employees(id) |
| `approved_at` | TIMESTAMPTZ | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

**UNIQUE**: `(employee_id, entry_date)`

---

### 38. `employee_time_sheets`
**Origen**: `031_employee_time_tracking.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `period_id` | UUID | FK → payroll_periods(id) |
| `week_start` | DATE | NOT NULL |
| `week_end` | DATE | NOT NULL |
| `scheduled_minutes` | INTEGER | DEFAULT 2660 |
| `worked_minutes` | INTEGER | DEFAULT 0 |
| `overtime_minutes` | INTEGER | DEFAULT 0 |
| `deficit_minutes` | INTEGER | DEFAULT 0 |
| `status` | VARCHAR(20) | DEFAULT 'abierto' |
| `notes` | TEXT | |
| `locked_by` | UUID | FK → employees(id) |
| `locked_at` | TIMESTAMPTZ | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

**UNIQUE**: `(employee_id, week_start)`

---

### 39. `employee_time_adjustments`
**Origen**: `031_employee_time_tracking.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `timesheet_id` | UUID | FK → employee_time_sheets(id) ON DELETE SET NULL |
| `entry_id` | UUID | FK → employee_time_entries(id) ON DELETE SET NULL |
| `period_id` | UUID | FK → payroll_periods(id) |
| `adjustment_date` | DATE | NOT NULL |
| `minutes` | INTEGER | NOT NULL |
| `type` | VARCHAR(30) | NOT NULL |
| `reason` | TEXT | |
| `status` | VARCHAR(20) | DEFAULT 'pendiente' |
| `notes` | TEXT | |
| `approved_by` | UUID | FK → employees(id) |
| `approved_at` | TIMESTAMPTZ | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

### 40. `employee_task_time_logs`
**Origen**: `031_employee_time_tracking.sql`

| Columna | Tipo | Constraints |
|---------|------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() |
| `task_id` | UUID | NOT NULL, FK → employee_tasks(id) ON DELETE CASCADE |
| `employee_id` | UUID | NOT NULL, FK → employees(id) ON DELETE CASCADE |
| `start_time` | TIMESTAMPTZ | NOT NULL |
| `end_time` | TIMESTAMPTZ | |
| `minutes` | INTEGER | DEFAULT 0 |
| `status` | VARCHAR(20) | DEFAULT 'registrado' |
| `notes` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

## CHECK CONSTRAINTS (migración 033)

| Tabla | Constraint | Expresión |
|-------|-----------|-----------|
| `products` | `chk_products_stock_non_negative` | `stock >= 0` |
| `materials` | `chk_materials_stock_non_negative` | `stock >= 0 OR stock IS NULL` |

Además, se crean **triggers de validación** en `products` y `materials` (`trg_validate_product_stock`, `trg_validate_material_stock`) que lanzan excepciones con mensajes legibles cuando se intenta establecer stock negativo.

---

## VISTAS COMPATIBILIDAD

| Vista | Apunta a | Origen |
|-------|----------|--------|
| `suppliers` | `SELECT * FROM proveedores` | migración 027 |
| `material_prices` | `SELECT ... FROM materials` (con columnas mapeadas) | migración 028 |

---

## RESUMEN DE RELACIONES (Foreign Keys)

```
customers ←── invoices.customer_id
customers ←── quotations.customer_id
customers ←── activities.customer_id
customers ←── notifications.customer_id
customers ←── invoice_interests.customer_id

invoices ←── invoice_items.invoice_id
invoices ←── payments.invoice_id
invoices ←── invoice_interests.invoice_id
invoices ←── activities.invoice_id
invoices ←── notifications.invoice_id
invoices ←── material_movements.invoice_id

quotations ←── quotation_items.quotation_id
quotations ←── invoices.quotation_id
quotations ←── activities.quotation_id
quotations ←── material_movements.quotation_id

products ←── stock_movements.product_id
products ←── product_components.product_id
products ←── invoice_items.product_id

materials ←── product_components.material_id
materials ←── material_movements.material_id
materials ←── quotation_items.material_id
materials ←── invoice_items.material_id
materials ←── purchase_items.material_id
materials ←── material_price_history.material_id
materials ←── notifications.material_id

categories ←── products.category_id

accounts ←── cash_movements.account_id
accounts ←── cash_movements.to_account_id
accounts ←── payroll.account_id
accounts ←── employee_loans.account_id

proveedores ←── purchases.supplier_id

purchases ←── purchase_items.purchase_id

employees ←── payroll.employee_id
employees ←── employee_incapacities.employee_id
employees ←── employee_loans.employee_id
employees ←── employee_tasks.employee_id
employees ←── employee_time_entries.employee_id
employees ←── employee_time_sheets.employee_id
employees ←── employee_time_adjustments.employee_id
employees ←── employee_task_time_logs.employee_id

payroll_periods ←── payroll.period_id
payroll_periods ←── employee_time_sheets.period_id
payroll_periods ←── employee_time_adjustments.period_id

payroll ←── payroll_details.payroll_id
payroll ←── loan_payments.payroll_id

payroll_concepts ←── payroll_details.concept_id

employee_loans ←── loan_payments.loan_id

employee_tasks ←── employee_task_time_logs.task_id

employee_time_entries ←── employee_time_adjustments.entry_id
employee_time_sheets ←── employee_time_adjustments.timesheet_id

cash_movements ←── payroll.cash_movement_id
cash_movements ←── employee_loans.cash_movement_id
```
