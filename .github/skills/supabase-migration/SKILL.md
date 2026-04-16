---
name: supabase-migration
description: "Create Supabase/PostgreSQL migrations for Industrial de Molinos. Use when: creating tables, altering schemas, adding indexes, creating RLS policies, writing database functions, triggers, views. Follows project naming conventions and sequential numbering."
argument-hint: "Describe the schema change (e.g., 'add payments table')"
---

# Supabase Migration Builder — Industrial de Molinos

## When to Use
- Creating new database tables
- Altering existing table schemas
- Adding indexes, views, or functions
- Writing RLS policies
- Creating triggers for `updated_at` or audit logging

## Migration File Location & Naming

```
supabase_migrations/
├── 000_initial_schema.sql
├── 001_inventory_tables.sql
├── 002_invoices_tables.sql
├── ...
├── NNN_description.sql        ← next sequential number
```

**Convention**: `{NNN}_{snake_case_description}.sql`

Check the highest existing number and use the next one.

## Migration Template

```sql
-- =====================================================
-- DESCRIPCIÓN DE LA MIGRACIÓN
-- Industrial de Molinos
-- =====================================================

-- 1. Crear tabla
CREATE TABLE IF NOT EXISTS nombre_tabla (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- campos del negocio
    name VARCHAR(255) NOT NULL,
    description TEXT,
    amount DECIMAL(15, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Crear índices
CREATE INDEX IF NOT EXISTS idx_nombre_tabla_name ON nombre_tabla(name);
CREATE INDEX IF NOT EXISTS idx_nombre_tabla_active ON nombre_tabla(is_active);

-- 3. Habilitar RLS
ALTER TABLE nombre_tabla ENABLE ROW LEVEL SECURITY;

-- 4. Política RLS (ajustar según necesidad)
DROP POLICY IF EXISTS "Allow all operations on nombre_tabla" ON nombre_tabla;
CREATE POLICY "Allow all operations on nombre_tabla" ON nombre_tabla
    FOR ALL USING (true) WITH CHECK (true);

-- 5. Trigger para updated_at
CREATE OR REPLACE FUNCTION update_nombre_tabla_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_nombre_tabla_updated_at ON nombre_tabla;
CREATE TRIGGER trigger_update_nombre_tabla_updated_at
    BEFORE UPDATE ON nombre_tabla
    FOR EACH ROW
    EXECUTE FUNCTION update_nombre_tabla_updated_at();
```

## Column Type Reference

| Dart Type | PostgreSQL Type | Notes |
|-----------|----------------|-------|
| `String` (UUID) | `UUID DEFAULT gen_random_uuid()` | Primary keys |
| `String` (short) | `VARCHAR(N)` | Use appropriate max length |
| `String` (long) | `TEXT` | Descriptions, notes |
| `double` | `DECIMAL(15, 2)` | Money, quantities |
| `int` | `INTEGER` | Counts, sequences |
| `bool` | `BOOLEAN DEFAULT TRUE/FALSE` | Flags |
| `DateTime` | `TIMESTAMP WITH TIME ZONE DEFAULT NOW()` | Always with time zone |
| `enum` | `VARCHAR(20) CHECK (type IN (...))` | Constrained values |
| `Map` / JSON | `JSONB DEFAULT '{}'::jsonb` | Flexible data |

## Foreign Key Pattern

```sql
-- FK with cascade
supplier_id UUID REFERENCES proveedores(id) ON DELETE SET NULL,

-- FK with restrict (prevent orphans)
product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
```

## View Pattern

```sql
CREATE OR REPLACE VIEW v_feature_summary AS
SELECT
    t.id,
    t.name,
    t.amount,
    s.name AS supplier_name
FROM nombre_tabla t
LEFT JOIN proveedores s ON t.supplier_id = s.id
WHERE t.is_active = true;
```

## RPC Function Pattern

```sql
CREATE OR REPLACE FUNCTION do_something(
    p_param_id UUID,
    p_amount DECIMAL
)
RETURNS VOID AS $$
BEGIN
    UPDATE nombre_tabla
    SET amount = amount + p_amount,
        updated_at = NOW()
    WHERE id = p_param_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Key Rules
1. **Always use `IF NOT EXISTS`** / `IF EXISTS` for idempotent migrations
2. **Always enable RLS** on every new table
3. **Always add `updated_at` trigger** on tables that have that column
4. **Use `DECIMAL(15, 2)`** for all monetary values
5. **Use `UUID` for primary keys** with `gen_random_uuid()`
6. **Use `TIMESTAMP WITH TIME ZONE`** — never without timezone
7. **Drop policies/triggers before recreating** with `DROP IF EXISTS`
8. **Add indexes** on frequently queried columns (name, document_number, is_active, foreign keys)
9. **Comments in Spanish** for business logic descriptions
10. **`SECURITY DEFINER`** on RPC functions that need elevated permissions
