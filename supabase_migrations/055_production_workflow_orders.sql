-- 055_production_workflow_orders.sql
-- Ordenes de produccion + flujo por etapas + mesa de trabajo

CREATE TABLE IF NOT EXISTS production_orders (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code          VARCHAR(50) NOT NULL UNIQUE,
    product_id    UUID REFERENCES products(id) ON DELETE SET NULL,
    product_code  VARCHAR(100),
    product_name  VARCHAR(200),
    quantity      DECIMAL(12,2) NOT NULL DEFAULT 1,
    status        VARCHAR(30) NOT NULL DEFAULT 'planificada',
    priority      VARCHAR(20) NOT NULL DEFAULT 'media',
    start_date    DATE,
    due_date      DATE,
    completed_at  TIMESTAMPTZ,
    notes         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT production_orders_status_check
        CHECK (status IN ('planificada', 'en_proceso', 'pausada', 'completada', 'cancelada')),
    CONSTRAINT production_orders_priority_check
        CHECK (priority IN ('baja', 'media', 'alta', 'urgente'))
);

CREATE INDEX IF NOT EXISTS idx_production_orders_status ON production_orders(status);
CREATE INDEX IF NOT EXISTS idx_production_orders_due_date ON production_orders(due_date);
CREATE INDEX IF NOT EXISTS idx_production_orders_product ON production_orders(product_id);

CREATE TABLE IF NOT EXISTS production_order_materials (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    production_order_id  UUID NOT NULL REFERENCES production_orders(id) ON DELETE CASCADE,
    material_id          UUID REFERENCES materials(id) ON DELETE SET NULL,
    material_name        VARCHAR(200),
    material_code        VARCHAR(100),
    required_quantity    DECIMAL(12,3) NOT NULL DEFAULT 0,
    consumed_quantity    DECIMAL(12,3) NOT NULL DEFAULT 0,
    unit                 VARCHAR(20) NOT NULL DEFAULT 'UND',
    estimated_cost       DECIMAL(14,2) NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT production_order_materials_quantity_check
        CHECK (required_quantity >= 0 AND consumed_quantity >= 0)
);

CREATE INDEX IF NOT EXISTS idx_prod_order_materials_order ON production_order_materials(production_order_id);
CREATE INDEX IF NOT EXISTS idx_prod_order_materials_material ON production_order_materials(material_id);

CREATE TABLE IF NOT EXISTS production_stages (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    production_order_id  UUID NOT NULL REFERENCES production_orders(id) ON DELETE CASCADE,
    sequence_order       INTEGER NOT NULL,
    process_name         VARCHAR(120) NOT NULL,
    workstation          VARCHAR(120) NOT NULL,
    estimated_hours      DECIMAL(8,2) NOT NULL DEFAULT 0,
    actual_hours         DECIMAL(8,2) NOT NULL DEFAULT 0,
    status               VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    assigned_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    resources            TEXT[] NOT NULL DEFAULT '{}',
    report               TEXT,
    notes                TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT production_stages_status_check
        CHECK (status IN ('pendiente', 'en_proceso', 'bloqueada', 'completada')),
    CONSTRAINT production_stages_hours_check
        CHECK (estimated_hours >= 0 AND actual_hours >= 0),
    CONSTRAINT production_stages_sequence_unique
        UNIQUE (production_order_id, sequence_order)
);

CREATE INDEX IF NOT EXISTS idx_production_stages_order ON production_stages(production_order_id);
CREATE INDEX IF NOT EXISTS idx_production_stages_status ON production_stages(status);
CREATE INDEX IF NOT EXISTS idx_production_stages_employee ON production_stages(assigned_employee_id);

-- Relacion blanda para tareas por etapa/opcional
ALTER TABLE employee_tasks
    ADD COLUMN IF NOT EXISTS production_stage_id UUID REFERENCES production_stages(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_employee_tasks_production_stage ON employee_tasks(production_stage_id);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_production_order ON employee_tasks(production_order_id);

-- Trigger updated_at (si ya existe la funcion global, se reutiliza)
DROP TRIGGER IF EXISTS trigger_update_production_orders_updated_at ON production_orders;
CREATE TRIGGER trigger_update_production_orders_updated_at
    BEFORE UPDATE ON production_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_production_order_materials_updated_at ON production_order_materials;
CREATE TRIGGER trigger_update_production_order_materials_updated_at
    BEFORE UPDATE ON production_order_materials
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_production_stages_updated_at ON production_stages;
CREATE TRIGGER trigger_update_production_stages_updated_at
    BEFORE UPDATE ON production_stages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
