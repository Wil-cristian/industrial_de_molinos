---
name: "SQL Migrations"
description: "Use when writing SQL migrations, database schema changes, RLS policies, triggers, views, or functions for Industrial de Molinos Supabase database."
applyTo: "**/*.sql"
---

# SQL Migration Rules — Industrial de Molinos

## File Location & Naming
- Path: `supabase_migrations/{NNN}_{snake_case_description}.sql`
- Sequential numbering: check the highest existing number, use next
- Also check `database/` folder for consolidated schemas

## Required Elements for New Tables
1. `CREATE TABLE IF NOT EXISTS` with UUID primary key
2. Indexes on frequently queried columns
3. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
4. RLS policy (drop existing first, then create)
5. `updated_at` trigger function and trigger

## Column Conventions
- Primary key: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`
- Timestamps: `TIMESTAMP WITH TIME ZONE DEFAULT NOW()` — always with timezone
- Money: `DECIMAL(15, 2)` — never `FLOAT` or `REAL`
- Booleans: `BOOLEAN DEFAULT TRUE/FALSE`
- Enums: `VARCHAR(20) CHECK (type IN ('value1', 'value2'))`
- Foreign keys: `UUID REFERENCES other_table(id) ON DELETE SET NULL/RESTRICT`

## Idempotency
- Always use `IF NOT EXISTS` / `IF EXISTS`
- Always `DROP POLICY IF EXISTS` before `CREATE POLICY`
- Always `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER`
- Use `CREATE OR REPLACE FUNCTION` for functions

## RLS Policy
```sql
ALTER TABLE nombre_tabla ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all operations on nombre_tabla" ON nombre_tabla;
CREATE POLICY "Allow all operations on nombre_tabla" ON nombre_tabla
    FOR ALL USING (true) WITH CHECK (true);
```

## Updated_at Trigger
```sql
CREATE OR REPLACE FUNCTION update_{table}_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## Comments
- Header block with migration description and "Industrial de Molinos"
- Business logic explanations in Spanish
- SQL keywords in UPPERCASE
