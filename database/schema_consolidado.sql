-- =====================================================
-- INDUSTRIAL DE MOLINOS — ESQUEMA CONSOLIDADO
-- Supabase / PostgreSQL
-- Consolidado de: supabase_schema.sql + migraciones 002–036
-- Fecha de consolidación: 21 de Febrero, 2026
-- =====================================================
-- Este archivo representa el estado DEFINITIVO de la base
-- de datos. Es solo para documentación/referencia.
-- =====================================================

-- =========================================================
-- I. EXTENSIONES
-- =========================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- II. TIPOS ENUMERADOS (ENUMS)
-- =========================================================
DO $$ BEGIN CREATE TYPE customer_type   AS ENUM ('individual', 'business');                                     EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE document_type   AS ENUM ('cc', 'nit', 'ce', 'pasaporte', 'ti', 'ruc', 'dni');          EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE quotation_status AS ENUM ('Borrador','Enviada','Aprobada','Rechazada','Vencida','Anulada'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE component_type  AS ENUM ('cylinder','circular_plate','rectangular_plate','shaft','ring','custom','product'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE invoice_type    AS ENUM ('invoice','receipt','credit_note','debit_note');               EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE invoice_status  AS ENUM ('draft','issued','paid','partial','cancelled','overdue');      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE payment_method  AS ENUM ('cash','card','transfer','credit','check','yape','plin');      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE stock_movement_type AS ENUM ('incoming','outgoing','adjustment');                       EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =========================================================
-- III. TABLAS
-- =========================================================

-- ─────────────────────────────────────────────────────────
-- A. CONFIGURACIÓN
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS company_settings (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(255) NOT NULL DEFAULT 'Industrial de Molinos',
    trade_name  VARCHAR(255),
    ruc         VARCHAR(11),
    address     TEXT,
    phone       VARCHAR(20),
    email       VARCHAR(255),
    logo_url    TEXT,
    currency    VARCHAR(10)    DEFAULT 'PEN',
    tax_rate    DECIMAL(5,2)   DEFAULT 18.00,
    created_at  TIMESTAMPTZ    DEFAULT NOW(),
    updated_at  TIMESTAMPTZ    DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS operational_costs (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    labor_rate_per_hour   DECIMAL(10,2)  DEFAULT 25.00,
    energy_rate_per_kwh   DECIMAL(10,4)  DEFAULT 0.50,
    gas_rate_per_m3       DECIMAL(10,4)  DEFAULT 2.00,
    default_profit_margin DECIMAL(5,2)   DEFAULT 20.00,
    created_at            TIMESTAMPTZ    DEFAULT NOW(),
    updated_at            TIMESTAMPTZ    DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────
-- B. CATÁLOGOS
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS categories (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id   UUID REFERENCES categories(id) ON DELETE SET NULL,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code            VARCHAR(20) NOT NULL UNIQUE,
    name            VARCHAR(255) NOT NULL,
    type            VARCHAR(50) NOT NULL,      -- asset, liability, equity, income, expense
    parent_code     VARCHAR(20),
    level           INTEGER DEFAULT 1,
    is_active       BOOLEAN DEFAULT TRUE,
    accepts_entries BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────
-- C. CLIENTES
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS customers (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type             customer_type NOT NULL DEFAULT 'business',
    document_type    document_type NOT NULL DEFAULT 'nit',
    document_number  VARCHAR(20) NOT NULL UNIQUE,
    name             VARCHAR(255) NOT NULL,
    trade_name       VARCHAR(255),
    address          TEXT,
    phone            VARCHAR(20),
    email            VARCHAR(255),
    credit_limit     DECIMAL(12,2) DEFAULT 0,
    current_balance  DECIMAL(12,2) DEFAULT 0,
    is_active        BOOLEAN DEFAULT TRUE,
    notes            TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_document ON customers(document_number);
CREATE INDEX IF NOT EXISTS idx_customers_name     ON customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_active   ON customers(is_active);

-- ─────────────────────────────────────────────────────────
-- D. PRODUCTOS & MATERIALES
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS products (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code               VARCHAR(50) NOT NULL UNIQUE,
    name               VARCHAR(255) NOT NULL,
    description        TEXT,
    category_id        UUID REFERENCES categories(id) ON DELETE SET NULL,
    unit_price         DECIMAL(12,2) NOT NULL DEFAULT 0,
    cost_price         DECIMAL(12,2) NOT NULL DEFAULT 0,
    stock              DECIMAL(12,3) DEFAULT 0,
    min_stock          DECIMAL(12,3) DEFAULT 0,
    unit               VARCHAR(20)  DEFAULT 'UND',
    is_active          BOOLEAN DEFAULT TRUE,
    image_url          TEXT,
    is_recipe          BOOLEAN DEFAULT FALSE,
    recipe_description TEXT,
    total_weight       DECIMAL(12,2) DEFAULT 0,
    total_cost         DECIMAL(12,2) DEFAULT 0,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_products_stock_non_negative CHECK (stock >= 0)
);

CREATE INDEX IF NOT EXISTS idx_products_code       ON products(code);
CREATE INDEX IF NOT EXISTS idx_products_name       ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_category   ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active     ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_cost_price ON products(cost_price);

CREATE TABLE IF NOT EXISTS materials (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code              VARCHAR(50) UNIQUE NOT NULL,
    name              VARCHAR(200) NOT NULL,
    description       TEXT,
    category          VARCHAR(50) DEFAULT 'general',
    shape             VARCHAR(30) DEFAULT 'custom',
    price_per_kg      DECIMAL(12,2) DEFAULT 0,
    unit_price        DECIMAL(12,2) DEFAULT 0,
    cost_price        DECIMAL(12,2) DEFAULT 0,
    stock             DECIMAL(12,2) DEFAULT 0,
    min_stock         DECIMAL(12,2) DEFAULT 0,
    unit              VARCHAR(20)  DEFAULT 'KG',
    density           DECIMAL(8,2) DEFAULT 7850,
    default_thickness DECIMAL(8,2),
    fixed_weight      DECIMAL(8,4),
    supplier          VARCHAR(200),
    location          VARCHAR(100),
    is_active         BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_materials_stock_non_negative CHECK (stock >= 0 OR stock IS NULL)
);

CREATE INDEX IF NOT EXISTS idx_materials_code       ON materials(code);
CREATE INDEX IF NOT EXISTS idx_materials_category   ON materials(category);
CREATE INDEX IF NOT EXISTS idx_materials_active     ON materials(is_active);
CREATE INDEX IF NOT EXISTS idx_materials_cost_price ON materials(cost_price);

CREATE TABLE IF NOT EXISTS product_components (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id        UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    material_id       UUID REFERENCES materials(id) ON DELETE SET NULL,
    name              VARCHAR(200) NOT NULL,
    description       TEXT,
    quantity          DECIMAL(12,4) NOT NULL DEFAULT 1,
    unit              VARCHAR(20) DEFAULT 'KG',
    outer_diameter    DECIMAL(10,2),
    inner_diameter    DECIMAL(10,2),
    thickness         DECIMAL(10,2),
    length            DECIMAL(10,2),
    width             DECIMAL(10,2),
    calculated_weight DECIMAL(12,4) DEFAULT 0,
    unit_cost         DECIMAL(12,2) DEFAULT 0,
    total_cost        DECIMAL(12,2) DEFAULT 0,
    sort_order        INT DEFAULT 0,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_product_components_product          ON product_components(product_id);
CREATE INDEX IF NOT EXISTS idx_product_components_material         ON product_components(material_id);
CREATE INDEX IF NOT EXISTS idx_product_components_product_material ON product_components(product_id, material_id);

-- ─────────────────────────────────────────────────────────
-- E. COTIZACIONES
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS quotations (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    number           VARCHAR(20) NOT NULL UNIQUE,
    date             DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until      DATE NOT NULL,
    customer_id      UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name    VARCHAR(255) NOT NULL,
    customer_document VARCHAR(20),
    status           quotation_status DEFAULT 'Borrador',
    materials_cost   DECIMAL(12,2) DEFAULT 0,
    labor_cost       DECIMAL(12,2) DEFAULT 0,
    labor_hours      DECIMAL(8,2)  DEFAULT 0,
    labor_rate       DECIMAL(10,2) DEFAULT 25.00,
    energy_cost      DECIMAL(12,2) DEFAULT 0,
    gas_cost         DECIMAL(12,2) DEFAULT 0,
    supplies_cost    DECIMAL(12,2) DEFAULT 0,
    other_costs      DECIMAL(12,2) DEFAULT 0,
    subtotal         DECIMAL(12,2) DEFAULT 0,
    profit_margin    DECIMAL(5,2)  DEFAULT 20.00,
    profit_amount    DECIMAL(12,2) DEFAULT 0,
    total            DECIMAL(12,2) DEFAULT 0,
    total_weight     DECIMAL(12,3) DEFAULT 0,
    notes            TEXT,
    terms            TEXT,
    created_by       UUID,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotations_number   ON quotations(number);
CREATE INDEX IF NOT EXISTS idx_quotations_customer ON quotations(customer_id);
CREATE INDEX IF NOT EXISTS idx_quotations_status   ON quotations(status);
CREATE INDEX IF NOT EXISTS idx_quotations_date     ON quotations(date);

CREATE TABLE IF NOT EXISTS quotation_items (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quotation_id     UUID NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    name             VARCHAR(255) NOT NULL,
    description      TEXT,
    type             component_type NOT NULL DEFAULT 'custom',
    material_id      UUID REFERENCES materials(id) ON DELETE SET NULL,
    material_name    VARCHAR(100),
    material_type    VARCHAR(50),
    product_id       UUID REFERENCES products(id) ON DELETE SET NULL,
    dimensions       JSONB DEFAULT '{}',
    dimensions_text  VARCHAR(255),
    quantity         INTEGER DEFAULT 1,
    unit_weight      DECIMAL(12,3) DEFAULT 0,
    total_weight     DECIMAL(12,3) DEFAULT 0,
    price_per_kg     DECIMAL(10,2) DEFAULT 0,
    unit_price       DECIMAL(12,2) DEFAULT 0,
    total_price      DECIMAL(12,2) DEFAULT 0,
    cost_price       DECIMAL(12,2) DEFAULT 0,
    cost_per_kg      DECIMAL(12,2) DEFAULT 0,
    unit_cost        DECIMAL(12,2) DEFAULT 0,
    total_cost       DECIMAL(12,2) DEFAULT 0,
    sort_order       INTEGER DEFAULT 0,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotation_items_quotation   ON quotation_items(quotation_id);
CREATE INDEX IF NOT EXISTS idx_quotation_items_product_id  ON quotation_items(product_id);
CREATE INDEX IF NOT EXISTS idx_quotation_items_material_id ON quotation_items(material_id);
CREATE INDEX IF NOT EXISTS idx_quotation_items_cost_price  ON quotation_items(cost_price);

-- ─────────────────────────────────────────────────────────
-- F. FACTURAS / COMPROBANTES
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS invoices (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type              invoice_type NOT NULL DEFAULT 'invoice',
    series            VARCHAR(10) NOT NULL,
    number            VARCHAR(20) NOT NULL,
    full_number       VARCHAR(30) GENERATED ALWAYS AS (series || '-' || number) STORED,
    customer_id       UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name     VARCHAR(255) NOT NULL,
    customer_document VARCHAR(20),
    customer_address  TEXT,
    issue_date        DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date          DATE,
    subtotal          DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax_rate          DECIMAL(5,2)  DEFAULT 18.00,
    tax_amount        DECIMAL(12,2) DEFAULT 0,
    discount          DECIMAL(12,2) DEFAULT 0,
    total             DECIMAL(12,2) NOT NULL DEFAULT 0,
    paid_amount       DECIMAL(12,2) DEFAULT 0,
    pending_amount    DECIMAL(12,2) GENERATED ALWAYS AS (total - paid_amount) STORED,
    status            invoice_status DEFAULT 'draft',
    payment_method    payment_method,
    quotation_id      UUID REFERENCES quotations(id) ON DELETE SET NULL,
    notes             TEXT,
    created_by        UUID,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(series, number)
);

CREATE INDEX IF NOT EXISTS idx_invoices_full_number   ON invoices(full_number);
CREATE INDEX IF NOT EXISTS idx_invoices_customer      ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status        ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_date          ON invoices(issue_date);
CREATE INDEX IF NOT EXISTS idx_invoices_due_date      ON invoices(due_date);
CREATE INDEX IF NOT EXISTS idx_invoices_status_date   ON invoices(status, issue_date DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_quotation_id  ON invoices(quotation_id);

CREATE TABLE IF NOT EXISTS invoice_items (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id    UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    product_id    UUID REFERENCES products(id) ON DELETE SET NULL,
    material_id   UUID REFERENCES materials(id) ON DELETE SET NULL,
    product_code  VARCHAR(50),
    product_name  VARCHAR(255) NOT NULL,
    description   TEXT,
    quantity      DECIMAL(12,3) NOT NULL,
    unit          VARCHAR(20) DEFAULT 'UND',
    unit_price    DECIMAL(12,2) NOT NULL,
    discount      DECIMAL(12,2) DEFAULT 0,
    tax_rate      DECIMAL(5,2)  DEFAULT 18.00,
    subtotal      DECIMAL(12,2) NOT NULL,
    tax_amount    DECIMAL(12,2) DEFAULT 0,
    total         DECIMAL(12,2) NOT NULL,
    cost_price    DECIMAL(12,2) DEFAULT 0,
    sort_order    INTEGER DEFAULT 0,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice     ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_product_id  ON invoice_items(product_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_material_id ON invoice_items(material_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_cost_price  ON invoice_items(cost_price);

CREATE TABLE IF NOT EXISTS payments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id    UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    amount        DECIMAL(12,2) NOT NULL,
    method        payment_method DEFAULT 'cash',
    reference     VARCHAR(100),
    notes         TEXT,
    payment_date  DATE DEFAULT CURRENT_DATE,
    created_by    UUID,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_date    ON payments(payment_date);

CREATE TABLE IF NOT EXISTS invoice_interests (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id       UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    customer_id      UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    original_amount  DECIMAL(12,2) NOT NULL,
    interest_rate    DECIMAL(5,2) NOT NULL DEFAULT 2.0,
    interest_amount  DECIMAL(12,2) NOT NULL,
    total_amount     DECIMAL(12,2) NOT NULL,
    days_overdue     INTEGER NOT NULL DEFAULT 0,
    applied_at       TIMESTAMPTZ DEFAULT NOW(),
    applied_by       UUID,
    notes            TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoice_interests_invoice    ON invoice_interests(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_interests_customer   ON invoice_interests(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoice_interests_applied_at ON invoice_interests(applied_at);

-- ─────────────────────────────────────────────────────────
-- G. FINANZAS / CAJA
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS accounts (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           VARCHAR(100) NOT NULL,
    type           VARCHAR(20) NOT NULL DEFAULT 'cash',
    balance        DECIMAL(12,2) NOT NULL DEFAULT 0,
    bank_name      VARCHAR(100),
    account_number VARCHAR(50),
    color          VARCHAR(10),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cash_movements (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id          UUID NOT NULL REFERENCES accounts(id),
    to_account_id       UUID REFERENCES accounts(id),
    type                VARCHAR(20) NOT NULL,
    category            VARCHAR(30) NOT NULL,
    amount              DECIMAL(12,2) NOT NULL,
    description         VARCHAR(255) NOT NULL,
    reference           VARCHAR(100),
    person_name         VARCHAR(100),
    date                TIMESTAMPTZ NOT NULL,
    linked_transfer_id  VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_movements_account        ON cash_movements(account_id);
CREATE INDEX IF NOT EXISTS idx_movements_date           ON cash_movements(date);
CREATE INDEX IF NOT EXISTS idx_movements_type           ON cash_movements(type);
CREATE INDEX IF NOT EXISTS idx_cash_movements_date_type ON cash_movements(date, type);
CREATE INDEX IF NOT EXISTS idx_cash_movements_category  ON cash_movements(category);
CREATE INDEX IF NOT EXISTS idx_cash_movements_reference ON cash_movements(reference);

-- ─────────────────────────────────────────────────────────
-- H. PROVEEDORES
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS proveedores (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code             VARCHAR(20) UNIQUE,
    type             VARCHAR(20) DEFAULT 'business' CHECK (type IN ('individual','business')),
    document_type    VARCHAR(20) DEFAULT 'RUC',
    document_number  VARCHAR(50) NOT NULL,
    name             VARCHAR(255) NOT NULL,
    trade_name       VARCHAR(255),
    address          TEXT,
    phone            VARCHAR(50),
    email            VARCHAR(255),
    contact_person   VARCHAR(255),
    bank_account     VARCHAR(100),
    bank_name        VARCHAR(100),
    current_debt     DECIMAL(15,2) DEFAULT 0,
    category         VARCHAR(50),
    payment_terms    VARCHAR(100),
    credit_limit     DECIMAL(12,2) DEFAULT 0,
    rating           INTEGER DEFAULT 3 CHECK (rating BETWEEN 1 AND 5),
    notes            TEXT,
    is_active        BOOLEAN DEFAULT TRUE,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_proveedores_name     ON proveedores(name);
CREATE INDEX IF NOT EXISTS idx_proveedores_document ON proveedores(document_number);
CREATE INDEX IF NOT EXISTS idx_proveedores_active   ON proveedores(is_active);

CREATE OR REPLACE VIEW suppliers AS SELECT * FROM proveedores;

-- ─────────────────────────────────────────────────────────
-- I. COMPRAS
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS purchases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    number          VARCHAR(20) NOT NULL UNIQUE,
    date            DATE NOT NULL DEFAULT CURRENT_DATE,
    supplier_id     UUID REFERENCES proveedores(id) ON DELETE SET NULL,
    supplier_name   VARCHAR(255) NOT NULL,
    supplier_ruc    VARCHAR(11),
    subtotal        DECIMAL(12,2) DEFAULT 0,
    tax_rate        DECIMAL(5,2)  DEFAULT 18.00,
    tax_amount      DECIMAL(12,2) DEFAULT 0,
    discount        DECIMAL(12,2) DEFAULT 0,
    total           DECIMAL(12,2) DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'pending',
    payment_status  VARCHAR(20) DEFAULT 'pending',
    paid_amount     DECIMAL(12,2) DEFAULT 0,
    payment_method  VARCHAR(20),
    payment_date    DATE,
    invoice_number  VARCHAR(50),
    delivery_date   DATE,
    received_date   DATE,
    notes           TEXT,
    created_by      UUID,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchases_date     ON purchases(date);
CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchases_status   ON purchases(status);

CREATE TABLE IF NOT EXISTS purchase_items (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_id       UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    material_id       UUID REFERENCES materials(id) ON DELETE SET NULL,
    code              VARCHAR(50),
    name              VARCHAR(255) NOT NULL,
    description       TEXT,
    category          VARCHAR(50),
    quantity          DECIMAL(12,3) NOT NULL,
    unit              VARCHAR(20) DEFAULT 'UND',
    received_quantity DECIMAL(12,3) DEFAULT 0,
    unit_price        DECIMAL(12,2) NOT NULL,
    subtotal          DECIMAL(12,2) NOT NULL,
    sort_order        INTEGER DEFAULT 0,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_material ON purchase_items(material_id);

-- ─────────────────────────────────────────────────────────
-- J. INVENTARIO — MOVIMIENTOS
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS stock_movements (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id     UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    type           VARCHAR(20) NOT NULL CHECK (type IN ('incoming','outgoing','adjustment')),
    quantity       DECIMAL(12,2) NOT NULL,
    previous_stock DECIMAL(12,2) DEFAULT 0,
    new_stock      DECIMAL(12,2) DEFAULT 0,
    reason         VARCHAR(200),
    reference      VARCHAR(100),
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_date    ON stock_movements(created_at);

CREATE TABLE IF NOT EXISTS material_movements (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    material_id    UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    type           VARCHAR(20) NOT NULL,
    quantity       DECIMAL(12,4) NOT NULL,
    previous_stock DECIMAL(12,4),
    new_stock      DECIMAL(12,4),
    reason         TEXT,
    reference      VARCHAR(100),
    quotation_id   UUID REFERENCES quotations(id),
    invoice_id     UUID REFERENCES invoices(id),
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_material_movements_material  ON material_movements(material_id);
CREATE INDEX IF NOT EXISTS idx_material_movements_date      ON material_movements(created_at);
CREATE INDEX IF NOT EXISTS idx_material_movements_quotation ON material_movements(quotation_id);
CREATE INDEX IF NOT EXISTS idx_material_movements_invoice   ON material_movements(invoice_id);

CREATE TABLE IF NOT EXISTS material_price_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    old_price   DECIMAL(12,2),
    new_price   DECIMAL(12,2),
    old_cost    DECIMAL(12,2),
    new_cost    DECIMAL(12,2),
    changed_at  TIMESTAMPTZ DEFAULT NOW(),
    changed_by  UUID,
    reason      TEXT
);

CREATE INDEX IF NOT EXISTS idx_material_price_history ON material_price_history(material_id, changed_at);

-- ─────────────────────────────────────────────────────────
-- K. RECURSOS HUMANOS
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS employees (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code              VARCHAR(20) UNIQUE,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    document_type     VARCHAR(10) DEFAULT 'dni',
    document_number   VARCHAR(20) UNIQUE,
    position          VARCHAR(100),
    department        VARCHAR(50),
    hire_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    termination_date  DATE,
    salary            DECIMAL(12,2) DEFAULT 0,
    hourly_rate       DECIMAL(10,2) DEFAULT 0,
    phone             VARCHAR(20),
    email             VARCHAR(255),
    address           TEXT,
    emergency_contact VARCHAR(255),
    bank_name         VARCHAR(100),
    bank_account      VARCHAR(50),
    is_active         BOOLEAN DEFAULT TRUE,
    notes             TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_employees_active     ON employees(is_active);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department);

CREATE TABLE IF NOT EXISTS payroll_concepts (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code           VARCHAR(20) UNIQUE NOT NULL,
    name           VARCHAR(100) NOT NULL,
    type           VARCHAR(20) NOT NULL,
    category       VARCHAR(50) NOT NULL,
    is_percentage  BOOLEAN DEFAULT FALSE,
    default_value  DECIMAL(12,2) DEFAULT 0,
    affects_taxes  BOOLEAN DEFAULT TRUE,
    is_active      BOOLEAN DEFAULT TRUE,
    description    TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payroll_periods (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_type     VARCHAR(20) NOT NULL,
    period_number   INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    payment_date    DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'abierto',
    total_earnings  DECIMAL(12,2) DEFAULT 0,
    total_deductions DECIMAL(12,2) DEFAULT 0,
    total_net       DECIMAL(12,2) DEFAULT 0,
    notes           TEXT,
    closed_at       TIMESTAMPTZ,
    closed_by       UUID,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(period_type, period_number, year)
);

CREATE TABLE IF NOT EXISTS payroll (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id       UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    period_id         UUID NOT NULL REFERENCES payroll_periods(id) ON DELETE CASCADE,
    base_salary       DECIMAL(12,2) NOT NULL DEFAULT 0,
    days_worked       INTEGER DEFAULT 0,
    days_absent       INTEGER DEFAULT 0,
    days_vacation     INTEGER DEFAULT 0,
    days_incapacity   INTEGER DEFAULT 0,
    regular_hours     DECIMAL(6,2) DEFAULT 0,
    overtime_hours_25 DECIMAL(6,2) DEFAULT 0,
    overtime_hours_35 DECIMAL(6,2) DEFAULT 0,
    overtime_hours_100 DECIMAL(6,2) DEFAULT 0,
    total_earnings    DECIMAL(12,2) DEFAULT 0,
    total_deductions  DECIMAL(12,2) DEFAULT 0,
    net_pay           DECIMAL(12,2) DEFAULT 0,
    status            VARCHAR(20) NOT NULL DEFAULT 'borrador',
    payment_date      TIMESTAMPTZ,
    payment_method    VARCHAR(30),
    payment_reference VARCHAR(100),
    account_id        UUID REFERENCES accounts(id),
    cash_movement_id  UUID REFERENCES cash_movements(id),
    notes             TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    approved_by       UUID,
    approved_at       TIMESTAMPTZ,
    UNIQUE(employee_id, period_id)
);

CREATE INDEX IF NOT EXISTS idx_payroll_employee        ON payroll(employee_id);
CREATE INDEX IF NOT EXISTS idx_payroll_period           ON payroll(period_id);
CREATE INDEX IF NOT EXISTS idx_payroll_status           ON payroll(status);
CREATE INDEX IF NOT EXISTS idx_payroll_employee_period  ON payroll(employee_id, period_id);

CREATE TABLE IF NOT EXISTS payroll_details (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payroll_id    UUID NOT NULL REFERENCES payroll(id) ON DELETE CASCADE,
    concept_id    UUID NOT NULL REFERENCES payroll_concepts(id),
    concept_code  VARCHAR(20) NOT NULL,
    concept_name  VARCHAR(100) NOT NULL,
    type          VARCHAR(20) NOT NULL,
    quantity      DECIMAL(10,2) DEFAULT 1,
    unit_value    DECIMAL(12,2) DEFAULT 0,
    amount        DECIMAL(12,2) NOT NULL,
    notes         TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payroll_details_payroll ON payroll_details(payroll_id);

CREATE TABLE IF NOT EXISTS employee_incapacities (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id         UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    type                VARCHAR(30) NOT NULL,
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    days_total          INTEGER NOT NULL,
    certificate_number  VARCHAR(50),
    medical_entity      VARCHAR(100),
    diagnosis           TEXT,
    payment_percentage  DECIMAL(5,2) DEFAULT 100,
    employer_days       INTEGER DEFAULT 0,
    status              VARCHAR(20) DEFAULT 'activa',
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incapacities_employee ON employee_incapacities(employee_id);
CREATE INDEX IF NOT EXISTS idx_incapacities_dates    ON employee_incapacities(start_date, end_date);

CREATE TABLE IF NOT EXISTS employee_loans (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id       UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    loan_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount      DECIMAL(12,2) NOT NULL,
    installments      INTEGER NOT NULL DEFAULT 1,
    installment_amount DECIMAL(12,2) NOT NULL,
    paid_amount       DECIMAL(12,2) DEFAULT 0,
    paid_installments INTEGER DEFAULT 0,
    remaining_amount  DECIMAL(12,2) NOT NULL,
    reason            TEXT,
    status            VARCHAR(20) DEFAULT 'activo',
    cash_movement_id  UUID REFERENCES cash_movements(id),
    account_id        UUID REFERENCES accounts(id),
    notes             TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_loans_employee ON employee_loans(employee_id);
CREATE INDEX IF NOT EXISTS idx_loans_status   ON employee_loans(status);

CREATE TABLE IF NOT EXISTS loan_payments (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id            UUID NOT NULL REFERENCES employee_loans(id) ON DELETE CASCADE,
    payroll_id         UUID REFERENCES payroll(id),
    payment_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    amount             DECIMAL(12,2) NOT NULL,
    installment_number INTEGER,
    payment_method     VARCHAR(20) DEFAULT 'nomina',
    notes              TEXT,
    created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_loan_payments_loan      ON loan_payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_payroll   ON loan_payments(payroll_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_loan_date ON loan_payments(loan_id, payment_date DESC);

CREATE TABLE IF NOT EXISTS employee_tasks (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id           UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    title                 VARCHAR(200) NOT NULL,
    description           TEXT,
    assigned_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date              DATE,
    completed_date        DATE,
    priority              VARCHAR(20) DEFAULT 'normal',
    status                VARCHAR(20) DEFAULT 'pendiente',
    category              VARCHAR(50),
    production_order_id   UUID,
    notes                 TEXT,
    completion_notes      TEXT,
    assigned_by           UUID,
    estimated_time        INTEGER,
    actual_time           INTEGER,
    activity_id           UUID REFERENCES activities(id) ON DELETE SET NULL,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_employee_tasks_employee ON employee_tasks(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_date     ON employee_tasks(assigned_date);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_status   ON employee_tasks(status);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_due_date ON employee_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_priority ON employee_tasks(priority);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_activity ON employee_tasks(activity_id);

-- ─────────────────────────────────────────────────────────
-- L. TIME TRACKING
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS employee_time_entries (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id       UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    entry_date        DATE NOT NULL,
    scheduled_start   VARCHAR(10),
    scheduled_end     VARCHAR(10),
    scheduled_minutes INTEGER DEFAULT 0,
    check_in          TIMESTAMPTZ,
    check_out         TIMESTAMPTZ,
    break_minutes     INTEGER DEFAULT 0,
    worked_minutes    INTEGER DEFAULT 0,
    overtime_minutes  INTEGER DEFAULT 0,
    deficit_minutes   INTEGER DEFAULT 0,
    status            VARCHAR(20) DEFAULT 'registrado',
    source            VARCHAR(20) DEFAULT 'manual',
    notes             TEXT,
    approval_notes    TEXT,
    approved_by       UUID REFERENCES employees(id),
    approved_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (employee_id, entry_date)
);

CREATE INDEX IF NOT EXISTS idx_time_entries_employee ON employee_time_entries(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_date     ON employee_time_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_time_entries_status   ON employee_time_entries(status);

CREATE TABLE IF NOT EXISTS employee_time_sheets (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id       UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    period_id         UUID REFERENCES payroll_periods(id),
    week_start        DATE NOT NULL,
    week_end          DATE NOT NULL,
    scheduled_minutes INTEGER DEFAULT 2660,
    worked_minutes    INTEGER DEFAULT 0,
    overtime_minutes  INTEGER DEFAULT 0,
    deficit_minutes   INTEGER DEFAULT 0,
    status            VARCHAR(20) DEFAULT 'abierto',
    notes             TEXT,
    locked_by         UUID REFERENCES employees(id),
    locked_at         TIMESTAMPTZ,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (employee_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_time_sheets_employee ON employee_time_sheets(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_sheets_period   ON employee_time_sheets(period_id);
CREATE INDEX IF NOT EXISTS idx_time_sheets_dates    ON employee_time_sheets(week_start, week_end);

CREATE TABLE IF NOT EXISTS employee_time_adjustments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id     UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    timesheet_id    UUID REFERENCES employee_time_sheets(id) ON DELETE SET NULL,
    entry_id        UUID REFERENCES employee_time_entries(id) ON DELETE SET NULL,
    period_id       UUID REFERENCES payroll_periods(id),
    adjustment_date DATE NOT NULL,
    minutes         INTEGER NOT NULL,
    type            VARCHAR(30) NOT NULL,
    reason          TEXT,
    status          VARCHAR(20) DEFAULT 'pendiente',
    notes           TEXT,
    approved_by     UUID REFERENCES employees(id),
    approved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_time_adjustments_employee  ON employee_time_adjustments(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_adjustments_timesheet ON employee_time_adjustments(timesheet_id);
CREATE INDEX IF NOT EXISTS idx_time_adjustments_date      ON employee_time_adjustments(adjustment_date);

CREATE TABLE IF NOT EXISTS employee_task_time_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES employee_tasks(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    start_time  TIMESTAMPTZ NOT NULL,
    end_time    TIMESTAMPTZ,
    minutes     INTEGER DEFAULT 0,
    status      VARCHAR(20) DEFAULT 'registrado',
    notes       TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_time_logs_task     ON employee_task_time_logs(task_id);
CREATE INDEX IF NOT EXISTS idx_task_time_logs_employee ON employee_task_time_logs(employee_id);

-- ─────────────────────────────────────────────────────────
-- M. ACTIVIDADES & NOTIFICACIONES
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS activities (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title            VARCHAR(255) NOT NULL,
    description      TEXT,
    activity_type    VARCHAR(50) NOT NULL DEFAULT 'general',
    start_date       TIMESTAMPTZ NOT NULL,
    end_date         TIMESTAMPTZ,
    due_date         DATE,
    status           VARCHAR(50) NOT NULL DEFAULT 'pending',
    priority         VARCHAR(20) NOT NULL DEFAULT 'medium',
    customer_id      UUID REFERENCES customers(id) ON DELETE SET NULL,
    invoice_id       UUID REFERENCES invoices(id) ON DELETE SET NULL,
    quotation_id     UUID REFERENCES quotations(id) ON DELETE SET NULL,
    reminder_enabled BOOLEAN DEFAULT FALSE,
    reminder_date    TIMESTAMPTZ,
    reminder_sent    BOOLEAN DEFAULT FALSE,
    amount           DECIMAL(12,2),
    color            VARCHAR(20) DEFAULT '#2196F3',
    icon             VARCHAR(50),
    notes            TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW(),
    created_by       UUID,
    CONSTRAINT valid_activity_type CHECK (activity_type IN ('payment','delivery','project_start','project_end','collection','meeting','reminder','general','stock_alert','maintenance')),
    CONSTRAINT valid_status        CHECK (status IN ('pending','in_progress','completed','cancelled','overdue')),
    CONSTRAINT valid_priority      CHECK (priority IN ('low','medium','high','urgent'))
);

CREATE INDEX IF NOT EXISTS idx_activities_start_date ON activities(start_date);
CREATE INDEX IF NOT EXISTS idx_activities_due_date   ON activities(due_date);
CREATE INDEX IF NOT EXISTS idx_activities_status     ON activities(status);
CREATE INDEX IF NOT EXISTS idx_activities_type       ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_customer   ON activities(customer_id);
CREATE INDEX IF NOT EXISTS idx_activities_reminder   ON activities(reminder_enabled, reminder_date) WHERE reminder_enabled = true;

CREATE TABLE IF NOT EXISTS notifications (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_type VARCHAR(50) NOT NULL,
    title             VARCHAR(255) NOT NULL,
    message           TEXT NOT NULL,
    is_read           BOOLEAN DEFAULT FALSE,
    is_dismissed      BOOLEAN DEFAULT FALSE,
    severity          VARCHAR(20) NOT NULL DEFAULT 'info',
    activity_id       UUID REFERENCES activities(id) ON DELETE CASCADE,
    customer_id       UUID REFERENCES customers(id) ON DELETE SET NULL,
    invoice_id        UUID REFERENCES invoices(id) ON DELETE SET NULL,
    material_id       UUID REFERENCES materials(id) ON DELETE SET NULL,
    action_url        VARCHAR(255),
    icon              VARCHAR(50),
    data              JSONB,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    read_at           TIMESTAMPTZ,
    expires_at        TIMESTAMPTZ,
    CONSTRAINT valid_notification_type CHECK (notification_type IN ('low_stock','overdue_invoice','upcoming_delivery','activity_reminder','payment_due','collection_due','general','project_update')),
    CONSTRAINT valid_severity          CHECK (severity IN ('info','warning','error','success'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read    ON notifications(is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_type       ON notifications(notification_type);

-- ─────────────────────────────────────────────────────────
-- N. ANALÍTICA
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS monthly_expenses (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    year              INTEGER NOT NULL,
    month             INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    electricity_cost  DECIMAL(12,2) DEFAULT 0,
    gas_cost          DECIMAL(12,2) DEFAULT 0,
    water_cost        DECIMAL(12,2) DEFAULT 0,
    internet_cost     DECIMAL(12,2) DEFAULT 0,
    rent_cost         DECIMAL(12,2) DEFAULT 0,
    maintenance_cost  DECIMAL(12,2) DEFAULT 0,
    salaries_cost     DECIMAL(12,2) DEFAULT 0,
    benefits_cost     DECIMAL(12,2) DEFAULT 0,
    supplies_cost     DECIMAL(12,2) DEFAULT 0,
    transport_cost    DECIMAL(12,2) DEFAULT 0,
    insurance_cost    DECIMAL(12,2) DEFAULT 0,
    taxes_cost        DECIMAL(12,2) DEFAULT 0,
    other_cost        DECIMAL(12,2) DEFAULT 0,
    other_description TEXT,
    total_fixed       DECIMAL(12,2) GENERATED ALWAYS AS (
        electricity_cost + gas_cost + water_cost + internet_cost +
        rent_cost + maintenance_cost + salaries_cost + benefits_cost +
        supplies_cost + transport_cost + insurance_cost + taxes_cost + other_cost
    ) STORED,
    notes             TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(year, month)
);

CREATE INDEX IF NOT EXISTS idx_monthly_expenses_period ON monthly_expenses(year, month);

-- ─────────────────────────────────────────────────────────
-- O. AUDITORÍA
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sync_log (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    record_id  UUID NOT NULL,
    action     VARCHAR(20) NOT NULL,
    old_data   JSONB,
    new_data   JSONB,
    synced_at  TIMESTAMPTZ DEFAULT NOW(),
    device_id  VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_sync_log_table ON sync_log(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_date  ON sync_log(synced_at);

-- ─────────────────────────────────────────────────────────
-- P. VISTA DE COMPATIBILIDAD
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW material_prices AS
SELECT id, name, category, NULL::VARCHAR(50) AS type,
       default_thickness AS thickness, price_per_kg, density,
       unit, is_active, created_at, updated_at
FROM materials;


-- =========================================================
-- IV. VISTAS REGULARES
-- =========================================================

CREATE OR REPLACE VIEW v_low_stock_products AS
SELECT id, code, name, stock, min_stock, unit, (min_stock - stock) AS units_needed
FROM products WHERE stock <= min_stock AND is_active = TRUE;

CREATE OR REPLACE VIEW v_customers_with_debt AS
SELECT id, name, trade_name, document_number, current_balance, credit_limit,
       (credit_limit - current_balance) AS available_credit
FROM customers WHERE current_balance > 0 AND is_active = TRUE ORDER BY current_balance DESC;

CREATE OR REPLACE VIEW v_pending_quotations AS
SELECT q.*, c.name AS customer_full_name, c.phone AS customer_phone,
       c.email AS customer_email, (q.valid_until < CURRENT_DATE) AS is_expired
FROM quotations q LEFT JOIN customers c ON q.customer_id = c.id
WHERE q.status IN ('Borrador','Enviada') ORDER BY q.valid_until ASC;

CREATE OR REPLACE VIEW v_overdue_invoices AS
SELECT i.*, c.name AS customer_full_name, c.phone AS customer_phone,
       (CURRENT_DATE - i.due_date) AS days_overdue
FROM invoices i LEFT JOIN customers c ON i.customer_id = c.id
WHERE i.due_date < CURRENT_DATE AND i.status NOT IN ('paid','cancelled') ORDER BY i.due_date ASC;

CREATE OR REPLACE VIEW v_monthly_sales_summary AS
SELECT DATE_TRUNC('month', issue_date) AS month, COUNT(*) AS total_invoices,
       SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS paid_count,
       SUM(total) AS total_amount, SUM(paid_amount) AS paid_amount,
       SUM(total - paid_amount) AS pending_amount
FROM invoices WHERE type = 'invoice' AND status != 'cancelled'
GROUP BY DATE_TRUNC('month', issue_date) ORDER BY month DESC;

CREATE OR REPLACE VIEW quotations_with_stock AS
SELECT q.*,
       (SELECT COUNT(*) FROM quotation_items qi
        LEFT JOIN products p ON p.id = qi.material_id
        WHERE qi.quotation_id = q.id AND (p.stock IS NULL OR p.stock < qi.quantity)) AS items_without_stock,
       (SELECT COUNT(*) FROM quotation_items WHERE quotation_id = q.id) AS total_items
FROM quotations q;

CREATE OR REPLACE VIEW v_material_inventory_kpis AS
SELECT m.id, m.name, m.code, m.category, m.stock, m.min_stock, m.unit,
       m.price_per_kg AS unit_price,
       COALESCE(m.cost_price, m.price_per_kg * 0.65) AS cost_price,
       ROUND((m.stock * COALESCE(m.cost_price, m.price_per_kg * 0.65))::NUMERIC, 2) AS inventory_value,
       COALESCE(consumption.qty_30d, 0) AS consumed_30_days,
       COALESCE(consumption.qty_90d, 0) AS consumed_90_days,
       ROUND((COALESCE(consumption.qty_90d, 0) / 90.0)::NUMERIC, 2) AS avg_daily_consumption,
       CASE WHEN COALESCE(consumption.qty_90d, 0) > 0
            THEN ROUND((m.stock / (consumption.qty_90d / 90.0))::NUMERIC, 0)
            ELSE 999 END AS days_of_coverage,
       CASE WHEN m.stock = 0 THEN 'SIN_STOCK'
            WHEN m.stock < m.min_stock THEN 'BAJO_STOCK'
            WHEN m.stock <= m.min_stock * 2 THEN 'NORMAL'
            ELSE 'EXCESO' END AS stock_status,
       movements.last_incoming, movements.last_outgoing,
       EXTRACT(DAY FROM NOW() - GREATEST(
           COALESCE(movements.last_incoming, '2020-01-01'),
           COALESCE(movements.last_outgoing, '2020-01-01')
       ))::INTEGER AS days_without_movement,
       CASE WHEN COALESCE(consumption.qty_90d, 0) / 90.0 * 365 > m.stock * 4 THEN 'FAST'
            WHEN COALESCE(consumption.qty_90d, 0) > 0 THEN 'SLOW'
            ELSE 'NON_MOVING' END AS fsn_category
FROM materials m
LEFT JOIN (
    SELECT material_id,
           SUM(CASE WHEN created_at >= NOW() - INTERVAL '30 days' AND type = 'outgoing' THEN quantity ELSE 0 END) AS qty_30d,
           SUM(CASE WHEN type = 'outgoing' THEN quantity ELSE 0 END) AS qty_90d
    FROM material_movements WHERE created_at >= NOW() - INTERVAL '90 days' GROUP BY material_id
) consumption ON m.id = consumption.material_id
LEFT JOIN (
    SELECT material_id,
           MAX(CASE WHEN type = 'incoming' THEN created_at END) AS last_incoming,
           MAX(CASE WHEN type = 'outgoing' THEN created_at END) AS last_outgoing
    FROM material_movements GROUP BY material_id
) movements ON m.id = movements.material_id
WHERE m.is_active = true;

CREATE OR REPLACE VIEW v_inventory_summary AS
SELECT COUNT(*) AS total_products,
       SUM(CASE WHEN stock = 0 THEN 1 ELSE 0 END) AS out_of_stock_count,
       SUM(CASE WHEN stock > 0 AND stock < min_stock THEN 1 ELSE 0 END) AS low_stock_count,
       SUM(CASE WHEN stock >= min_stock THEN 1 ELSE 0 END) AS in_stock_count,
       ROUND(SUM(inventory_value)::NUMERIC, 2) AS total_inventory_value,
       ROUND(AVG(days_of_coverage)::NUMERIC, 0) AS avg_days_coverage,
       SUM(CASE WHEN fsn_category = 'FAST' THEN 1 ELSE 0 END) AS fast_moving_count,
       SUM(CASE WHEN fsn_category = 'SLOW' THEN 1 ELSE 0 END) AS slow_moving_count,
       SUM(CASE WHEN fsn_category = 'NON_MOVING' THEN 1 ELSE 0 END) AS non_moving_count
FROM v_material_inventory_kpis;

CREATE OR REPLACE VIEW v_receivables_aging_summary AS
SELECT
    CASE WHEN due_date >= CURRENT_DATE THEN '0_vigente'
         WHEN CURRENT_DATE - due_date BETWEEN  1 AND 30 THEN '1_1_30_dias'
         WHEN CURRENT_DATE - due_date BETWEEN 31 AND 60 THEN '2_31_60_dias'
         WHEN CURRENT_DATE - due_date BETWEEN 61 AND 90 THEN '3_61_90_dias'
         ELSE '4_mas_90_dias' END AS aging_bucket,
    CASE WHEN due_date >= CURRENT_DATE THEN 'Vigente'
         WHEN CURRENT_DATE - due_date BETWEEN  1 AND 30 THEN '1-30 días'
         WHEN CURRENT_DATE - due_date BETWEEN 31 AND 60 THEN '31-60 días'
         WHEN CURRENT_DATE - due_date BETWEEN 61 AND 90 THEN '61-90 días'
         ELSE 'Más de 90 días' END AS aging_label,
    COUNT(*) AS num_invoices, COUNT(DISTINCT customer_id) AS num_customers,
    ROUND(SUM(total - paid_amount)::NUMERIC, 2) AS pending_amount,
    ROUND(AVG(total - paid_amount)::NUMERIC, 2) AS avg_pending,
    ROUND(AVG(GREATEST(CURRENT_DATE - due_date, 0))::NUMERIC, 0) AS avg_days_overdue
FROM invoices WHERE status NOT IN ('paid','cancelled') AND (total - paid_amount) > 0
GROUP BY aging_bucket, aging_label ORDER BY aging_bucket;

CREATE OR REPLACE VIEW v_top_debtors AS
SELECT c.id AS customer_id, c.name AS customer_name, c.document_number, c.phone,
       COUNT(i.id) AS pending_invoices,
       ROUND(SUM(i.total - i.paid_amount)::NUMERIC, 2) AS total_debt,
       MIN(i.due_date) AS oldest_due_date,
       MAX(CURRENT_DATE - i.due_date) AS max_days_overdue,
       ROUND(AVG(CURRENT_DATE - i.due_date)::NUMERIC, 0) AS avg_days_overdue,
       CASE WHEN MAX(CURRENT_DATE - i.due_date) > 90 THEN 'CRITICO'
            WHEN MAX(CURRENT_DATE - i.due_date) > 60 THEN 'ALTO'
            WHEN MAX(CURRENT_DATE - i.due_date) > 30 THEN 'MEDIO'
            ELSE 'BAJO' END AS risk_level
FROM customers c JOIN invoices i ON c.id = i.customer_id
WHERE i.status NOT IN ('paid','cancelled') AND (i.total - i.paid_amount) > 0 AND i.due_date < CURRENT_DATE
GROUP BY c.id, c.name, c.document_number, c.phone ORDER BY total_debt DESC;

CREATE OR REPLACE VIEW v_customer_purchase_history AS
SELECT c.id AS customer_id, c.name AS customer_name, c.document_number, c.type AS customer_type,
       i.id AS invoice_id, i.full_number AS invoice_number, i.issue_date,
       i.total AS invoice_total, i.status AS invoice_status,
       ii.product_name, ii.product_code, ii.quantity, ii.unit_price, ii.total AS item_total
FROM customers c LEFT JOIN invoices i ON c.id = i.customer_id LEFT JOIN invoice_items ii ON i.id = ii.invoice_id
WHERE i.status != 'cancelled' ORDER BY c.id, i.issue_date DESC;

CREATE OR REPLACE VIEW v_customer_metrics AS
SELECT c.id, c.name, c.document_number, c.type, c.current_balance AS debt, c.credit_limit, c.created_at AS customer_since,
       COUNT(DISTINCT i.id) AS total_purchases, COALESCE(SUM(i.total), 0) AS total_spent,
       COALESCE(AVG(i.total), 0) AS average_ticket, MAX(i.issue_date) AS last_purchase_date,
       MIN(i.issue_date) AS first_purchase_date,
       EXTRACT(DAY FROM NOW() - MAX(i.issue_date))::INTEGER AS days_since_last_purchase
FROM customers c LEFT JOIN invoices i ON c.id = i.customer_id AND i.status != 'cancelled'
GROUP BY c.id, c.name, c.document_number, c.type, c.current_balance, c.credit_limit, c.created_at;

CREATE OR REPLACE VIEW v_top_selling_products AS
SELECT COALESCE(ii.product_id::TEXT, ii.material_id::TEXT, ii.product_code) AS product_key,
       ii.product_name, ii.product_code, SUM(ii.quantity) AS total_quantity,
       COUNT(DISTINCT ii.invoice_id) AS times_sold, SUM(ii.total) AS total_revenue, AVG(ii.unit_price) AS avg_price
FROM invoice_items ii JOIN invoices i ON ii.invoice_id = i.id WHERE i.status != 'cancelled'
GROUP BY product_key, ii.product_name, ii.product_code ORDER BY total_revenue DESC;

CREATE OR REPLACE VIEW v_material_consumption_monthly AS
SELECT DATE_TRUNC('month', mm.created_at) AS month, m.id AS material_id, m.name AS material_name,
       m.code AS material_code, m.category,
       SUM(CASE WHEN mm.type = 'outgoing' THEN mm.quantity ELSE 0 END) AS consumed,
       SUM(CASE WHEN mm.type = 'incoming' THEN mm.quantity ELSE 0 END) AS received,
       COUNT(*) AS movements
FROM material_movements mm JOIN materials m ON mm.material_id = m.id
GROUP BY DATE_TRUNC('month', mm.created_at), m.id, m.name, m.code, m.category ORDER BY month DESC, consumed DESC;

CREATE OR REPLACE VIEW v_sales_by_period AS
SELECT DATE_TRUNC('day', issue_date) AS day, DATE_TRUNC('week', issue_date) AS week,
       DATE_TRUNC('month', issue_date) AS month, DATE_TRUNC('year', issue_date) AS year,
       COUNT(*) AS num_invoices, SUM(subtotal) AS subtotal, SUM(tax_amount) AS tax,
       SUM(total) AS total, SUM(paid_amount) AS collected, SUM(total - paid_amount) AS pending, AVG(total) AS avg_ticket
FROM invoices WHERE status != 'cancelled' GROUP BY day, week, month, year ORDER BY day DESC;

CREATE OR REPLACE VIEW v_accounts_receivable_aging AS
SELECT c.id AS customer_id, c.name AS customer_name, c.document_number,
       i.id AS invoice_id, i.full_number, i.issue_date, i.due_date,
       i.total, i.paid_amount, (i.total - i.paid_amount) AS pending_amount,
       CASE WHEN i.due_date >= CURRENT_DATE THEN 'current'
            WHEN CURRENT_DATE - i.due_date <= 30 THEN '1-30 days'
            WHEN CURRENT_DATE - i.due_date <= 60 THEN '31-60 days'
            WHEN CURRENT_DATE - i.due_date <= 90 THEN '61-90 days'
            ELSE 'over 90 days' END AS aging_bucket,
       (CURRENT_DATE - i.due_date) AS days_overdue
FROM invoices i JOIN customers c ON i.customer_id = c.id
WHERE i.status NOT IN ('paid','cancelled') AND (i.total - i.paid_amount) > 0 ORDER BY days_overdue DESC;

CREATE OR REPLACE VIEW v_debts_with_interest AS
SELECT i.id AS invoice_id, i.full_number AS invoice_number,
       i.total AS original_total, i.paid_amount,
       (i.total - COALESCE(i.paid_amount, 0)) AS pending_amount, i.due_date,
       GREATEST(EXTRACT(DAY FROM NOW() - i.due_date), 0)::INTEGER AS days_overdue,
       c.id AS customer_id, COALESCE(c.trade_name, c.name) AS customer_name,
       c.phone AS contact_phone, c.email AS contact_email,
       CASE WHEN NOW() > i.due_date
            THEN (i.total - COALESCE(i.paid_amount, 0)) * 0.02 * (EXTRACT(DAY FROM NOW() - i.due_date) / 30)
            ELSE 0 END AS calculated_interest,
       (i.total - COALESCE(i.paid_amount, 0)) +
       CASE WHEN NOW() > i.due_date
            THEN (i.total - COALESCE(i.paid_amount, 0)) * 0.02 * (EXTRACT(DAY FROM NOW() - i.due_date) / 30)
            ELSE 0 END AS total_with_interest,
       CASE WHEN NOW() <= i.due_date THEN 'vigente'
            WHEN EXTRACT(DAY FROM NOW() - i.due_date) <= 30 THEN 'vencido'
            WHEN EXTRACT(DAY FROM NOW() - i.due_date) <= 60 THEN 'moroso'
            ELSE 'critico' END AS mora_status,
       EXISTS(SELECT 1 FROM invoice_interests ii WHERE ii.invoice_id = i.id) AS interest_applied
FROM invoices i JOIN customers c ON i.customer_id = c.id
WHERE i.status IN ('draft','issued','partial','overdue') AND (i.total - COALESCE(i.paid_amount, 0)) > 0
ORDER BY days_overdue DESC;

CREATE OR REPLACE VIEW v_material_profit_analysis AS
SELECT m.id AS material_id, m.code AS material_code, m.name AS material_name,
       m.category, m.unit, m.stock AS current_stock, m.cost_price AS purchase_price,
       CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END AS sale_price,
       CASE WHEN m.cost_price > 0 THEN
            ROUND(((CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END - m.cost_price) / m.cost_price * 100)::numeric, 2)
       ELSE 0 END AS configured_margin_percent,
       CASE WHEN m.unit = 'KG' THEN m.price_per_kg - m.cost_price ELSE m.unit_price - m.cost_price END AS profit_per_unit,
       m.stock * m.cost_price AS stock_cost_value,
       m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END) AS stock_sale_value,
       COALESCE(sales.avg_sale_price, 0) AS avg_actual_sale_price,
       COALESCE(sales.total_qty_sold, 0) AS total_qty_sold,
       COALESCE(sales.total_revenue, 0) AS total_revenue,
       CASE WHEN m.cost_price > 0 AND COALESCE(sales.avg_sale_price, 0) > 0 THEN
            ROUND(((sales.avg_sale_price - m.cost_price) / m.cost_price * 100)::numeric, 2) ELSE NULL END AS actual_margin_percent,
       m.is_active, m.updated_at
FROM materials m
LEFT JOIN (
    SELECT ii.material_id, AVG(ii.unit_price) AS avg_sale_price,
           SUM(ii.quantity) AS total_qty_sold, SUM(ii.total) AS total_revenue
    FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
    WHERE ii.material_id IS NOT NULL AND i.status::text NOT IN ('cancelled') GROUP BY ii.material_id
) sales ON sales.material_id = m.id
WHERE m.is_active = true ORDER BY m.category, m.name;

CREATE OR REPLACE VIEW v_product_profit_analysis AS
SELECT p.id AS product_id, p.code AS product_code, p.name AS product_name,
       p.is_recipe, p.unit, p.stock AS current_stock,
       p.cost_price AS fabrication_cost, p.total_cost AS recipe_total_cost, p.total_weight,
       p.unit_price AS sale_price,
       CASE WHEN p.cost_price > 0 THEN ROUND(((p.unit_price - p.cost_price) / p.cost_price * 100)::numeric, 2) ELSE 0 END AS margin_percent,
       p.unit_price - p.cost_price AS profit_per_unit,
       CASE WHEN p.unit_price > 0 THEN ROUND(((p.unit_price - p.cost_price) / p.unit_price * 100)::numeric, 2) ELSE 0 END AS gross_margin_percent,
       COALESCE(sales.total_qty_sold, 0) AS total_qty_sold,
       COALESCE(sales.total_revenue, 0) AS total_revenue,
       COALESCE(sales.avg_sale_price, 0) AS avg_actual_sale_price,
       CASE WHEN p.cost_price > 0 AND COALESCE(sales.avg_sale_price, 0) > 0 THEN
            ROUND(((sales.avg_sale_price - p.cost_price) / p.cost_price * 100)::numeric, 2) ELSE NULL END AS actual_margin_percent,
       COALESCE(comp.component_count, 0) AS component_count, p.is_active, p.updated_at
FROM products p
LEFT JOIN (
    SELECT ii.product_id, AVG(ii.unit_price) AS avg_sale_price,
           SUM(ii.quantity) AS total_qty_sold, SUM(ii.total) AS total_revenue
    FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
    WHERE ii.product_id IS NOT NULL AND i.status::text NOT IN ('cancelled') GROUP BY ii.product_id
) sales ON sales.product_id = p.id
LEFT JOIN (SELECT product_id, COUNT(*) AS component_count FROM product_components GROUP BY product_id) comp ON comp.product_id = p.id
WHERE p.is_active = true ORDER BY p.is_recipe DESC, p.name;

CREATE OR REPLACE VIEW v_invoice_profit_analysis AS
SELECT i.id AS invoice_id, i.series || '-' || i.number AS invoice_number,
       i.customer_name, i.issue_date, i.status, i.total AS invoice_total,
       COALESCE(items.total_cost, 0) AS total_cost,
       i.total - COALESCE(items.total_cost, 0) AS gross_profit,
       CASE WHEN i.total > 0 THEN ROUND(((i.total - COALESCE(items.total_cost, 0)) / i.total * 100)::numeric, 2) ELSE 0 END AS gross_margin_percent,
       CASE WHEN COALESCE(items.total_cost, 0) > 0 THEN ROUND(((i.total - items.total_cost) / items.total_cost * 100)::numeric, 2) ELSE 0 END AS markup_percent,
       items.item_count, i.created_at
FROM invoices i
LEFT JOIN (
    SELECT invoice_id,
       SUM(CASE WHEN cost_price > 0 THEN cost_price * quantity ELSE subtotal * 0.65 END) AS total_cost,
       COUNT(*) AS item_count
    FROM invoice_items GROUP BY invoice_id
) items ON items.invoice_id = i.id
WHERE i.status::text NOT IN ('cancelled') ORDER BY i.issue_date DESC;

CREATE OR REPLACE VIEW v_quotation_profit_analysis AS
SELECT q.id AS quotation_id, q.number AS quotation_number, q.customer_name,
       q.date AS issue_date, q.status, q.total AS quotation_total,
       COALESCE(items.total_cost, 0) AS total_cost,
       q.total - COALESCE(items.total_cost, 0) AS projected_profit,
       CASE WHEN q.total > 0 THEN ROUND(((q.total - COALESCE(items.total_cost, 0)) / q.total * 100)::numeric, 2) ELSE 0 END AS projected_margin_percent,
       items.item_count, q.created_at
FROM quotations q
LEFT JOIN (
    SELECT quotation_id,
           SUM(CASE WHEN cost_price > 0 THEN cost_price * quantity ELSE total_price * 0.65 END) AS total_cost,
           COUNT(*) AS item_count
    FROM quotation_items GROUP BY quotation_id
) items ON items.quotation_id = q.id ORDER BY q.date DESC;

CREATE OR REPLACE VIEW employee_time_summary AS
SELECT e.id AS employee_id, e.first_name || ' ' || e.last_name AS employee_name,
       date_trunc('week', ete.entry_date)::DATE AS week_start,
       (date_trunc('week', ete.entry_date) + INTERVAL '6 days')::DATE AS week_end,
       COUNT(ete.id) AS days_worked,
       COALESCE(SUM(ete.worked_minutes), 0) AS total_worked_minutes,
       COALESCE(SUM(ete.overtime_minutes), 0) AS total_overtime_minutes,
       COALESCE(SUM(ete.deficit_minutes), 0) AS total_deficit_minutes,
       COALESCE(SUM(ete.break_minutes), 0) AS total_break_minutes,
       COALESCE(SUM(ete.scheduled_minutes), 0) AS total_scheduled_minutes
FROM employees e LEFT JOIN employee_time_entries ete ON ete.employee_id = e.id
WHERE ete.entry_date IS NOT NULL
GROUP BY e.id, e.first_name, e.last_name, date_trunc('week', ete.entry_date) ORDER BY week_start DESC, employee_name;

CREATE OR REPLACE VIEW v_today_activities AS
SELECT a.*, c.name AS customer_name FROM activities a LEFT JOIN customers c ON a.customer_id = c.id
WHERE DATE(a.start_date) = CURRENT_DATE OR DATE(a.due_date) = CURRENT_DATE ORDER BY a.start_date;

CREATE OR REPLACE VIEW v_week_activities AS
SELECT a.*, c.name AS customer_name FROM activities a LEFT JOIN customers c ON a.customer_id = c.id
WHERE a.start_date >= DATE_TRUNC('week', CURRENT_DATE)
  AND a.start_date < DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '7 days' ORDER BY a.start_date;

CREATE OR REPLACE VIEW v_upcoming_reminders AS
SELECT a.*, c.name AS customer_name FROM activities a LEFT JOIN customers c ON a.customer_id = c.id
WHERE a.reminder_enabled = true AND a.reminder_date <= NOW() + INTERVAL '1 day'
  AND a.reminder_sent = false AND a.status NOT IN ('completed','cancelled') ORDER BY a.reminder_date;

CREATE OR REPLACE VIEW v_unread_notifications AS
SELECT n.*, c.name AS customer_name, m.name AS material_name
FROM notifications n LEFT JOIN customers c ON n.customer_id = c.id LEFT JOIN materials m ON n.material_id = m.id
WHERE n.is_read = false AND n.is_dismissed = false AND (n.expires_at IS NULL OR n.expires_at > NOW())
ORDER BY CASE n.severity WHEN 'error' THEN 1 WHEN 'warning' THEN 2 WHEN 'success' THEN 3 ELSE 4 END, n.created_at DESC;

CREATE OR REPLACE VIEW v_activities_summary AS
SELECT COUNT(*) FILTER (WHERE status = 'pending') AS pending_count,
       COUNT(*) FILTER (WHERE status = 'overdue') AS overdue_count,
       COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_count,
       COUNT(*) FILTER (WHERE DATE(due_date) = CURRENT_DATE) AS due_today_count,
       COUNT(*) FILTER (WHERE activity_type = 'payment') AS payments_count,
       COUNT(*) FILTER (WHERE activity_type = 'delivery') AS deliveries_count,
       COUNT(*) FILTER (WHERE activity_type = 'collection') AS collections_count
FROM activities WHERE status NOT IN ('completed','cancelled');

CREATE OR REPLACE VIEW v_customer_product_analysis AS
SELECT c.id AS customer_id, c.name AS customer_name, ii.product_name, ii.product_code,
       COUNT(*) AS purchase_count, SUM(ii.quantity) AS total_quantity, SUM(ii.total) AS total_spent,
       MIN(i.issue_date) AS first_purchase, MAX(i.issue_date) AS last_purchase,
       AVG(ii.quantity) AS avg_quantity_per_purchase
FROM customers c JOIN invoices i ON c.id = i.customer_id JOIN invoice_items ii ON i.id = ii.invoice_id
WHERE i.status != 'cancelled' GROUP BY c.id, c.name, ii.product_name, ii.product_code ORDER BY c.name, purchase_count DESC;

CREATE OR REPLACE VIEW v_margin_summary_by_category AS
SELECT 'material' AS item_type, m.category, COUNT(*) AS item_count,
       ROUND(AVG(CASE WHEN m.cost_price > 0 THEN
           ((CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END) - m.cost_price) / m.cost_price * 100
       ELSE 0 END)::numeric, 2) AS avg_margin_percent,
       SUM(m.stock * m.cost_price) AS total_stock_cost,
       SUM(m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END)) AS total_stock_value,
       SUM(m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END)) - SUM(m.stock * m.cost_price) AS potential_profit
FROM materials m WHERE m.is_active = true GROUP BY m.category
UNION ALL
SELECT 'product', COALESCE(c.name, 'Sin categoría'), COUNT(*),
       ROUND(AVG(CASE WHEN p.cost_price > 0 THEN (p.unit_price - p.cost_price) / p.cost_price * 100 ELSE 0 END)::numeric, 2),
       SUM(p.stock * p.cost_price), SUM(p.stock * p.unit_price),
       SUM(p.stock * p.unit_price) - SUM(p.stock * p.cost_price)
FROM products p LEFT JOIN categories c ON c.id = p.category_id
WHERE p.is_active = true GROUP BY COALESCE(c.name, 'Sin categoría') ORDER BY item_type, category;


-- =========================================================
-- V. VISTAS MATERIALIZADAS
-- =========================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_receivables_kpis AS
WITH current_ar AS (
    SELECT COALESCE(SUM(total - paid_amount), 0) AS total_ar, COUNT(*) AS open_invoices,
           COALESCE(AVG(total - paid_amount), 0) AS avg_ar
    FROM invoices WHERE status IN ('pendiente','parcial','vencida')
),
dso_calc AS (
    SELECT CASE WHEN COALESCE(SUM(total), 0) > 0
                THEN (COALESCE(SUM(total - paid_amount), 0) / COALESCE(SUM(total), 1)) * 30 ELSE 0 END AS dso_days
    FROM invoices WHERE status != 'anulada' AND issue_date >= CURRENT_DATE - INTERVAL '90 days'
),
cei_calc AS (
    SELECT CASE WHEN COALESCE(SUM(total), 0) > 0
                THEN (COALESCE(SUM(paid_amount), 0) / COALESCE(SUM(total), 1)) * 100 ELSE 0 END AS cei_pct
    FROM invoices WHERE status != 'anulada' AND issue_date >= CURRENT_DATE - INTERVAL '90 days'
),
monthly_data AS (
    SELECT DATE_TRUNC('month', issue_date) AS month, SUM(total) AS total_billed, SUM(paid_amount) AS total_collected
    FROM invoices WHERE status != 'anulada' GROUP BY DATE_TRUNC('month', issue_date)
)
SELECT ca.total_ar, ca.open_invoices, ca.avg_ar, dc.dso_days, cc.cei_pct,
       COALESCE((SELECT total_collected FROM monthly_data ORDER BY month DESC LIMIT 1), 0) AS last_month_collected,
       COALESCE((SELECT total_billed FROM monthly_data ORDER BY month DESC LIMIT 1), 0) AS last_month_billed,
       NOW() AS refreshed_at
FROM current_ar ca CROSS JOIN dso_calc dc CROSS JOIN cei_calc cc;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_receivables_kpis ON mv_receivables_kpis(refreshed_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_profit_loss_monthly AS
WITH monthly_sales AS (
    SELECT DATE_TRUNC('month', issue_date) AS period, COALESCE(SUM(subtotal), 0) AS revenue,
           COALESCE(SUM(tax_amount), 0) AS tax_collected, COALESCE(SUM(total), 0) AS total_sales, COUNT(*) AS invoice_count
    FROM invoices WHERE status NOT IN ('anulada') GROUP BY DATE_TRUNC('month', issue_date)
),
monthly_variable_expenses AS (
    SELECT DATE_TRUNC('month', date) AS period, COALESCE(SUM(amount), 0) AS variable_expenses
    FROM cash_movements WHERE type = 'expense' AND category NOT IN ('payroll','transfer_out') GROUP BY DATE_TRUNC('month', date)
)
SELECT ms.period, ms.revenue, ms.tax_collected, ms.total_sales, ms.invoice_count,
       COALESCE(me.total_fixed, 0) AS fixed_expenses, COALESCE(mve.variable_expenses, 0) AS variable_expenses,
       COALESCE(me.total_fixed, 0) + COALESCE(mve.variable_expenses, 0) AS total_expenses,
       ms.revenue - COALESCE(me.total_fixed, 0) - COALESCE(mve.variable_expenses, 0) AS net_profit,
       CASE WHEN ms.revenue > 0
            THEN ((ms.revenue - COALESCE(me.total_fixed, 0) - COALESCE(mve.variable_expenses, 0)) / ms.revenue) * 100
            ELSE 0 END AS profit_margin_pct,
       NOW() AS refreshed_at
FROM monthly_sales ms
LEFT JOIN monthly_expenses me ON me.year = EXTRACT(YEAR FROM ms.period)::INT AND me.month = EXTRACT(MONTH FROM ms.period)::INT
LEFT JOIN monthly_variable_expenses mve ON mve.period = ms.period ORDER BY ms.period DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_pnl_period ON mv_profit_loss_monthly(period);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_inventory_abc_analysis AS
WITH product_sales AS (
    SELECT p.id AS product_id, p.name, p.code, p.category_id, p.stock,
           p.unit_price AS sale_price, p.cost_price,
           COALESCE(SUM(ii.quantity), 0) AS total_sold, COALESCE(SUM(ii.subtotal), 0) AS total_revenue
    FROM products p
    LEFT JOIN invoice_items ii ON ii.product_id = p.id
    LEFT JOIN invoices i ON i.id = ii.invoice_id AND i.status NOT IN ('anulada') AND i.issue_date >= CURRENT_DATE - INTERVAL '12 months'
    WHERE p.is_active = true GROUP BY p.id, p.name, p.code, p.category_id, p.stock, p.unit_price, p.cost_price
),
ranked AS (
    SELECT *, SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
              SUM(total_revenue) OVER () AS grand_total,
              ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS rank
    FROM product_sales
)
SELECT product_id, name, code, category_id, stock, sale_price, cost_price,
       total_sold, total_revenue, rank,
       CASE WHEN grand_total > 0 AND (cumulative_revenue / grand_total) <= 0.80 THEN 'A'
            WHEN grand_total > 0 AND (cumulative_revenue / grand_total) <= 0.95 THEN 'B'
            ELSE 'C' END AS abc_category,
       CASE WHEN grand_total > 0 THEN (total_revenue / grand_total) * 100 ELSE 0 END AS revenue_pct,
       NOW() AS refreshed_at
FROM ranked;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_abc_product ON mv_inventory_abc_analysis(product_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_customer_payment_behavior AS
SELECT c.id AS customer_id, c.name AS customer_name, c.document_number,
       COUNT(i.id) AS total_invoices,
       COUNT(CASE WHEN i.status = 'pagada' THEN 1 END) AS paid_invoices,
       COUNT(CASE WHEN i.status = 'vencida' THEN 1 END) AS overdue_invoices,
       COUNT(CASE WHEN i.status IN ('pendiente','parcial') THEN 1 END) AS pending_invoices,
       COALESCE(SUM(i.total), 0) AS total_billed, COALESCE(SUM(i.paid_amount), 0) AS total_paid,
       COALESCE(SUM(i.total - i.paid_amount), 0) AS total_outstanding,
       CASE WHEN COUNT(i.id) > 0
            THEN (COUNT(CASE WHEN i.status = 'pagada' THEN 1 END)::DECIMAL / COUNT(i.id)) * 100 ELSE 0 END AS payment_rate_pct,
       COALESCE(AVG(CASE WHEN i.status = 'pagada' AND i.due_date IS NOT NULL
            THEN EXTRACT(DAY FROM (i.updated_at - i.due_date)) END), 0) AS avg_days_to_pay,
       MAX(i.issue_date) AS last_invoice_date, NOW() AS refreshed_at
FROM customers c LEFT JOIN invoices i ON i.customer_id = c.id AND i.status != 'anulada'
WHERE c.is_active = true GROUP BY c.id, c.name, c.document_number;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_payment_behavior_customer ON mv_customer_payment_behavior(customer_id);

-- Vistas de compatibilidad
CREATE OR REPLACE VIEW v_receivables_kpis          AS SELECT * FROM mv_receivables_kpis;
CREATE OR REPLACE VIEW v_profit_loss_monthly        AS SELECT * FROM mv_profit_loss_monthly;
CREATE OR REPLACE VIEW v_inventory_abc_analysis     AS SELECT * FROM mv_inventory_abc_analysis;
CREATE OR REPLACE VIEW v_customer_payment_behavior  AS SELECT * FROM mv_customer_payment_behavior;


-- =========================================================
-- VI. FUNCIONES
-- =========================================================

-- A. Utilidades
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_quotation_number() RETURNS TEXT AS $$
DECLARE year_part TEXT; seq_num INTEGER;
BEGIN
    year_part := TO_CHAR(CURRENT_DATE, 'YYYY');
    SELECT COALESCE(MAX(CAST(SUBSTRING(number FROM 10 FOR 4) AS INTEGER)), 0) + 1 INTO seq_num
    FROM quotations WHERE number LIKE 'COT-' || year_part || '-%';
    RETURN 'COT-' || year_part || '-' || LPAD(seq_num::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_invoice_number(p_series TEXT) RETURNS TEXT AS $$
BEGIN
    RETURN LPAD((COALESCE(MAX(CAST(NULLIF(number, '') AS INTEGER)), 0) + 1)::TEXT, 8, '0')
    FROM invoices WHERE series = p_series;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_purchase_number() RETURNS VARCHAR AS $$
DECLARE v_year VARCHAR; v_number INTEGER;
BEGIN
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');
    SELECT COALESCE(MAX(CAST(SUBSTRING(number FROM 9) AS INTEGER)), 0) + 1 INTO v_number
    FROM purchases WHERE number LIKE 'OC-' || v_year || '-%';
    RETURN 'OC-' || v_year || '-' || LPAD(v_number::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- B. Recalcular totales de cotización
CREATE OR REPLACE FUNCTION recalculate_quotation_totals(p_quotation_id UUID) RETURNS VOID AS $$
DECLARE
    v_materials_cost DECIMAL(12,2); v_total_weight DECIMAL(12,3);
    v_subtotal DECIMAL(12,2); v_profit_amount DECIMAL(12,2); v_total DECIMAL(12,2);
    v_profit_margin DECIMAL(5,2); v_labor_cost DECIMAL(12,2);
    v_energy_cost DECIMAL(12,2); v_gas_cost DECIMAL(12,2);
    v_supplies_cost DECIMAL(12,2); v_other_costs DECIMAL(12,2);
BEGIN
    SELECT COALESCE(SUM(total_price), 0), COALESCE(SUM(total_weight), 0)
    INTO v_materials_cost, v_total_weight FROM quotation_items WHERE quotation_id = p_quotation_id;
    SELECT profit_margin, labor_cost, energy_cost, gas_cost, supplies_cost, other_costs
    INTO v_profit_margin, v_labor_cost, v_energy_cost, v_gas_cost, v_supplies_cost, v_other_costs
    FROM quotations WHERE id = p_quotation_id;
    v_subtotal := v_materials_cost + v_labor_cost + v_energy_cost + v_gas_cost + v_supplies_cost + v_other_costs;
    v_profit_amount := v_subtotal * (v_profit_margin / 100);
    v_total := v_subtotal + v_profit_amount;
    UPDATE quotations SET materials_cost = v_materials_cost, total_weight = v_total_weight,
        subtotal = v_subtotal, profit_amount = v_profit_amount, total = v_total, updated_at = NOW()
    WHERE id = p_quotation_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_recalculate_quotation() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN PERFORM recalculate_quotation_totals(OLD.quotation_id); RETURN OLD;
    ELSE PERFORM recalculate_quotation_totals(NEW.quotation_id); RETURN NEW; END IF;
END;
$$ LANGUAGE plpgsql;

-- C. Inventario — Descuento bulk
CREATE OR REPLACE FUNCTION deduct_inventory_item(
    p_material_id UUID, p_product_id UUID, p_quantity DECIMAL,
    p_reference VARCHAR, p_reason VARCHAR,
    p_quotation_id UUID DEFAULT NULL, p_invoice_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_mat_stock DECIMAL; v_mat_name VARCHAR; v_mat_unit VARCHAR;
    v_prod_stock DECIMAL; v_is_recipe BOOLEAN; v_prod_name VARCHAR;
    v_components_count INT; v_results JSONB;
    v_fail_name VARCHAR; v_fail_stock DECIMAL; v_fail_required DECIMAL;
BEGIN
    IF p_quantity <= 0 THEN RETURN jsonb_build_object('success', false, 'error', 'Cantidad debe ser mayor a 0'); END IF;
    IF p_material_id IS NOT NULL THEN
        SELECT stock, name, unit INTO v_mat_stock, v_mat_name, v_mat_unit FROM materials WHERE id = p_material_id;
        IF v_mat_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Material no encontrado: ' || p_material_id); END IF;
        IF v_mat_stock < p_quantity THEN RETURN jsonb_build_object('success', false, 'error', 'Stock insuficiente de ' || v_mat_name); END IF;
        UPDATE materials SET stock = stock - p_quantity, updated_at = NOW() WHERE id = p_material_id;
        INSERT INTO material_movements (material_id, type, quantity, previous_stock, new_stock, reason, reference, quotation_id, invoice_id)
        VALUES (p_material_id, 'outgoing', p_quantity, v_mat_stock, v_mat_stock - p_quantity, p_reason, p_reference, p_quotation_id, p_invoice_id);
        RETURN jsonb_build_object('success', true, 'type', 'material', 'name', v_mat_name);
    END IF;
    IF p_product_id IS NOT NULL THEN
        SELECT is_recipe, stock, name INTO v_is_recipe, v_prod_stock, v_prod_name FROM products WHERE id = p_product_id;
        IF v_prod_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado'); END IF;
        IF v_is_recipe = true THEN
            SELECT COUNT(*) INTO v_components_count FROM product_components WHERE product_id = p_product_id;
            IF v_components_count = 0 THEN RETURN jsonb_build_object('success', false, 'error', 'Receta sin componentes'); END IF;
            SELECT m.name, m.stock, agg.total_required INTO v_fail_name, v_fail_stock, v_fail_required
            FROM (SELECT pc.material_id, SUM(pc.quantity * p_quantity) AS total_required FROM product_components pc WHERE pc.product_id = p_product_id GROUP BY pc.material_id) agg
            JOIN materials m ON m.id = agg.material_id WHERE m.stock < agg.total_required LIMIT 1;
            IF v_fail_name IS NOT NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Stock insuficiente de componente ' || v_fail_name); END IF;
            INSERT INTO material_movements (material_id, type, quantity, previous_stock, new_stock, reason, reference, quotation_id, invoice_id)
            SELECT pc.material_id, 'outgoing', pc.quantity * p_quantity, m.stock, m.stock - (pc.quantity * p_quantity),
                   'Receta: ' || v_prod_name || ' - ' || pc.name, p_reference, p_quotation_id, p_invoice_id
            FROM product_components pc JOIN materials m ON m.id = pc.material_id WHERE pc.product_id = p_product_id;
            UPDATE materials SET stock = materials.stock - agg.total_qty, updated_at = NOW()
            FROM (SELECT pc.material_id, SUM(pc.quantity * p_quantity) AS total_qty FROM product_components pc WHERE pc.product_id = p_product_id GROUP BY pc.material_id) agg
            WHERE materials.id = agg.material_id;
            RETURN jsonb_build_object('success', true, 'type', 'recipe', 'name', v_prod_name, 'components_deducted', v_components_count);
        ELSE
            IF v_prod_stock < p_quantity THEN RETURN jsonb_build_object('success', false, 'error', 'Stock insuficiente de ' || v_prod_name); END IF;
            UPDATE products SET stock = stock - p_quantity, updated_at = NOW() WHERE id = p_product_id;
            RETURN jsonb_build_object('success', true, 'type', 'product', 'name', v_prod_name);
        END IF;
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'No se proporcionó material_id ni product_id');
END;
$$ LANGUAGE plpgsql;

-- D-G. Funciones de cotización, factura, stock check, reversión
-- (Ver migraciones 030 + 036 para versiones extendidas con detalles completos)

-- H. Pagos
CREATE OR REPLACE FUNCTION register_payment(
    p_invoice_id UUID, p_amount DECIMAL, p_method VARCHAR DEFAULT 'cash',
    p_reference VARCHAR DEFAULT NULL, p_notes VARCHAR DEFAULT NULL
) RETURNS UUID AS $$
DECLARE v_payment_id UUID; v_invoice RECORD; v_new_paid DECIMAL; v_new_status VARCHAR;
BEGIN
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    IF v_invoice IS NULL THEN RAISE EXCEPTION 'Factura no encontrada'; END IF;
    IF v_invoice.status::TEXT = 'paid' THEN RAISE EXCEPTION 'La factura ya está pagada'; END IF;
    INSERT INTO payments (invoice_id, amount, method, reference, notes, payment_date)
    VALUES (p_invoice_id, p_amount, p_method::payment_method, p_reference, p_notes, CURRENT_DATE) RETURNING id INTO v_payment_id;
    v_new_paid := COALESCE(v_invoice.paid_amount, 0) + p_amount;
    v_new_status := CASE WHEN v_new_paid >= v_invoice.total THEN 'paid' ELSE 'partial' END;
    UPDATE invoices SET paid_amount = v_new_paid, status = v_new_status::invoice_status, payment_method = p_method::payment_method, updated_at = NOW() WHERE id = p_invoice_id;
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql;

-- I. Nómina
CREATE OR REPLACE FUNCTION calculate_payroll_totals(p_payroll_id UUID) RETURNS void AS $$
DECLARE v_base DECIMAL(12,2); v_extra DECIMAL(12,2); v_deductions DECIMAL(12,2);
BEGIN
    SELECT COALESCE(base_salary, 0) INTO v_base FROM payroll WHERE id = p_payroll_id;
    SELECT COALESCE(SUM(amount), 0) INTO v_extra FROM payroll_details WHERE payroll_id = p_payroll_id AND type = 'ingreso';
    SELECT COALESCE(SUM(amount), 0) INTO v_deductions FROM payroll_details WHERE payroll_id = p_payroll_id AND type = 'descuento';
    UPDATE payroll SET total_earnings = v_base + v_extra, total_deductions = v_deductions, net_pay = (v_base + v_extra) - v_deductions, updated_at = NOW() WHERE id = p_payroll_id;
END;
$$ LANGUAGE plpgsql;

-- J. Operaciones atómicas de balance
CREATE OR REPLACE FUNCTION atomic_transfer(
    p_from_account_id UUID, p_to_account_id UUID, p_amount DECIMAL(12,2),
    p_description TEXT, p_date DATE DEFAULT CURRENT_DATE, p_reference TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE v_from_balance DECIMAL(12,2); v_to_balance DECIMAL(12,2); v_transfer_id TEXT; v_out_id UUID; v_in_id UUID;
BEGIN
    IF p_amount <= 0 THEN RAISE EXCEPTION 'El monto debe ser mayor a 0'; END IF;
    IF p_from_account_id = p_to_account_id THEN RAISE EXCEPTION 'No se puede transferir a la misma cuenta'; END IF;
    PERFORM balance FROM accounts WHERE id = LEAST(p_from_account_id, p_to_account_id) FOR UPDATE;
    PERFORM balance FROM accounts WHERE id = GREATEST(p_from_account_id, p_to_account_id) FOR UPDATE;
    SELECT balance INTO v_from_balance FROM accounts WHERE id = p_from_account_id;
    IF v_from_balance < p_amount THEN RAISE EXCEPTION 'Saldo insuficiente'; END IF;
    v_transfer_id := extract(epoch from now())::TEXT;
    INSERT INTO cash_movements (account_id, to_account_id, type, category, amount, description, reference, date, linked_transfer_id)
    VALUES (p_from_account_id, p_to_account_id, 'transfer', 'transfer_out', p_amount, 'Traslado: ' || p_description, p_reference, p_date, v_transfer_id) RETURNING id INTO v_out_id;
    INSERT INTO cash_movements (account_id, to_account_id, type, category, amount, description, reference, date, linked_transfer_id)
    VALUES (p_to_account_id, p_from_account_id, 'transfer', 'transfer_in', p_amount, 'Traslado: ' || p_description, p_reference, p_date, v_transfer_id) RETURNING id INTO v_in_id;
    UPDATE accounts SET balance = balance - p_amount, updated_at = NOW() WHERE id = p_from_account_id;
    UPDATE accounts SET balance = balance + p_amount, updated_at = NOW() WHERE id = p_to_account_id;
    RETURN jsonb_build_object('success', true, 'out_movement_id', v_out_id, 'in_movement_id', v_in_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION atomic_movement_with_balance(
    p_account_id UUID, p_type VARCHAR(20), p_category VARCHAR(50), p_amount DECIMAL(12,2),
    p_description TEXT, p_reference TEXT DEFAULT NULL, p_person_name TEXT DEFAULT NULL, p_date DATE DEFAULT CURRENT_DATE
) RETURNS JSONB AS $$
DECLARE v_balance DECIMAL(12,2); v_new_balance DECIMAL(12,2); v_movement_id UUID;
BEGIN
    IF p_amount <= 0 THEN RAISE EXCEPTION 'El monto debe ser mayor a 0'; END IF;
    SELECT balance INTO v_balance FROM accounts WHERE id = p_account_id FOR UPDATE;
    IF v_balance IS NULL THEN RAISE EXCEPTION 'Cuenta no encontrada'; END IF;
    v_new_balance := CASE WHEN p_type = 'income' THEN v_balance + p_amount ELSE v_balance - p_amount END;
    INSERT INTO cash_movements (account_id, type, category, amount, description, reference, person_name, date)
    VALUES (p_account_id, p_type, p_category, p_amount, p_description, p_reference, p_person_name, p_date) RETURNING id INTO v_movement_id;
    UPDATE accounts SET balance = v_new_balance, updated_at = NOW() WHERE id = p_account_id;
    RETURN jsonb_build_object('success', true, 'movement_id', v_movement_id, 'new_balance', v_new_balance);
END;
$$ LANGUAGE plpgsql;

-- K. Materialized views refresh
CREATE OR REPLACE FUNCTION refresh_materialized_views() RETURNS JSONB AS $$
DECLARE v_start TIMESTAMP; v_results JSONB := '[]'::JSONB;
BEGIN
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_receivables_kpis;
    v_results := v_results || jsonb_build_array(jsonb_build_object('view','mv_receivables_kpis','ms',EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT));
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_profit_loss_monthly;
    v_results := v_results || jsonb_build_array(jsonb_build_object('view','mv_profit_loss_monthly','ms',EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT));
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_abc_analysis;
    v_results := v_results || jsonb_build_array(jsonb_build_object('view','mv_inventory_abc_analysis','ms',EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT));
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_payment_behavior;
    v_results := v_results || jsonb_build_array(jsonb_build_object('view','mv_customer_payment_behavior','ms',EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT));
    RETURN jsonb_build_object('success', true, 'refreshed_at', NOW(), 'views', v_results);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_dso_trend(p_months INT DEFAULT 12)
RETURNS TABLE(month DATE, dso_days DECIMAL(10,2), total_billed DECIMAL(12,2), total_outstanding DECIMAL(12,2), invoice_count INT) AS $$
BEGIN
    RETURN QUERY SELECT DATE_TRUNC('month', i.issue_date)::DATE,
        CASE WHEN SUM(i.total) > 0 THEN (SUM(i.total - i.paid_amount) / SUM(i.total)) * 30 ELSE 0 END,
        COALESCE(SUM(i.total), 0), COALESCE(SUM(i.total - i.paid_amount), 0), COUNT(i.id)::INT
    FROM invoices i WHERE i.status != 'anulada' AND i.issue_date >= DATE_TRUNC('month', CURRENT_DATE) - (p_months || ' months')::INTERVAL
    GROUP BY DATE_TRUNC('month', i.issue_date) ORDER BY month DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- L. Stock constraints trigger
CREATE OR REPLACE FUNCTION validate_stock_before_update() RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'products' AND NEW.stock < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para producto "%"', COALESCE(NEW.name, NEW.id::TEXT);
    END IF;
    IF TG_TABLE_NAME = 'materials' AND NEW.stock IS NOT NULL AND NEW.stock < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para material "%"', COALESCE(NEW.name, NEW.id::TEXT);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- M. Auto-fill cost_price
CREATE OR REPLACE FUNCTION auto_fill_item_cost_price() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cost_price IS NULL OR NEW.cost_price = 0 THEN
        IF NEW.material_id IS NOT NULL THEN SELECT cost_price INTO NEW.cost_price FROM materials WHERE id = NEW.material_id;
        ELSIF NEW.product_id IS NOT NULL THEN SELECT cost_price INTO NEW.cost_price FROM products WHERE id = NEW.product_id;
        END IF;
    END IF;
    NEW.cost_price := COALESCE(NEW.cost_price, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- N. Time tracking triggers
CREATE OR REPLACE FUNCTION calculate_worked_minutes() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.check_in IS NOT NULL AND NEW.check_out IS NOT NULL THEN
        NEW.worked_minutes := GREATEST(0, EXTRACT(EPOCH FROM (NEW.check_out - NEW.check_in))::INTEGER / 60 - COALESCE(NEW.break_minutes, 0));
        NEW.overtime_minutes := GREATEST(0, NEW.worked_minutes - COALESCE(NEW.scheduled_minutes, 480));
        NEW.deficit_minutes := GREATEST(0, COALESCE(NEW.scheduled_minutes, 480) - NEW.worked_minutes);
    END IF;
    NEW.updated_at := NOW(); RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_task_minutes() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL THEN
        NEW.minutes := GREATEST(0, EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))::INTEGER / 60);
    END IF;
    NEW.updated_at := NOW(); RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- =========================================================
-- VII. TRIGGERS
-- =========================================================

CREATE TRIGGER update_customers_updated_at   BEFORE UPDATE ON customers   FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at    BEFORE UPDATE ON products    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_quotations_updated_at  BEFORE UPDATE ON quotations  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at    BEFORE UPDATE ON invoices    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_accounts_updated_at    BEFORE UPDATE ON accounts    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_proveedores_updated_at BEFORE UPDATE ON proveedores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_update_activities_updated_at BEFORE UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_update_employee_tasks_updated_at BEFORE UPDATE ON employee_tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER recalculate_quotation_on_item_change AFTER INSERT OR UPDATE OR DELETE ON quotation_items FOR EACH ROW EXECUTE FUNCTION trigger_recalculate_quotation();
CREATE TRIGGER trigger_purchase_received AFTER UPDATE ON purchases FOR EACH ROW EXECUTE FUNCTION update_stock_on_purchase_received();
CREATE TRIGGER trigger_material_price_change AFTER UPDATE ON materials FOR EACH ROW EXECUTE FUNCTION log_material_price_change();

CREATE TRIGGER trg_validate_product_stock BEFORE UPDATE OF stock ON products FOR EACH ROW EXECUTE FUNCTION validate_stock_before_update();
CREATE TRIGGER trg_validate_material_stock BEFORE UPDATE OF stock ON materials FOR EACH ROW EXECUTE FUNCTION validate_stock_before_update();
CREATE TRIGGER trg_calculate_worked_minutes BEFORE INSERT OR UPDATE ON employee_time_entries FOR EACH ROW EXECUTE FUNCTION calculate_worked_minutes();
CREATE TRIGGER trg_calculate_task_minutes BEFORE INSERT OR UPDATE ON employee_task_time_logs FOR EACH ROW EXECUTE FUNCTION calculate_task_minutes();
CREATE TRIGGER trg_auto_fill_invoice_item_cost BEFORE INSERT ON invoice_items FOR EACH ROW EXECUTE FUNCTION auto_fill_item_cost_price();
CREATE TRIGGER trg_auto_fill_quotation_item_cost BEFORE INSERT ON quotation_items FOR EACH ROW EXECUTE FUNCTION auto_fill_item_cost_price();


-- =========================================================
-- VIII. ROW LEVEL SECURITY
-- =========================================================

DO $$
DECLARE tbl TEXT;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'accounts','activities','cash_movements','categories','chart_of_accounts',
        'company_settings','customers','employee_incapacities','employee_loans',
        'employee_tasks','employees','invoice_interests','invoice_items','invoices',
        'loan_payments','material_movements','material_price_history',
        'materials','monthly_expenses','notifications','operational_costs',
        'payroll','payroll_concepts','payroll_details','payroll_periods','payments',
        'product_components','products','proveedores','purchase_items','purchases',
        'quotation_items','quotations','stock_movements','sync_log',
        'employee_time_entries','employee_time_sheets','employee_time_adjustments',
        'employee_task_time_logs'
    ]) LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);
            EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', tbl);
            EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (true)', 'authenticated_select_' || tbl, tbl);
            EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (true)', 'authenticated_insert_' || tbl, tbl);
            EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (true) WITH CHECK (true)', 'authenticated_update_' || tbl, tbl);
            EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (true)', 'authenticated_delete_' || tbl, tbl);
        END IF;
    END LOOP;
END $$;


-- =========================================================
-- IX. PERMISOS
-- =========================================================

DO $$
DECLARE tbl TEXT;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'accounts','activities','cash_movements','categories','chart_of_accounts',
        'company_settings','customers','employee_incapacities','employee_loans',
        'employee_tasks','employees','invoice_interests','invoice_items','invoices',
        'loan_payments','material_movements','material_price_history',
        'materials','monthly_expenses','notifications','operational_costs',
        'payroll','payroll_concepts','payroll_details','payroll_periods','payments',
        'product_components','products','proveedores','purchase_items','purchases',
        'quotation_items','quotations','stock_movements','sync_log',
        'employee_time_entries','employee_time_sheets','employee_time_adjustments',
        'employee_task_time_logs'
    ]) LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('REVOKE ALL ON public.%I FROM anon', tbl);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', tbl);
        END IF;
    END LOOP;
END $$;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

GRANT SELECT ON mv_receivables_kpis TO authenticated;
GRANT SELECT ON mv_profit_loss_monthly TO authenticated;
GRANT SELECT ON mv_inventory_abc_analysis TO authenticated;
GRANT SELECT ON mv_customer_payment_behavior TO authenticated;


-- =========================================================
-- X. COMENTARIOS
-- =========================================================
COMMENT ON TABLE customers IS 'Clientes (personas o empresas)';
COMMENT ON TABLE products IS 'Productos terminados y recetas de fabricación';
COMMENT ON TABLE materials IS 'Inventario unificado de materia prima';
COMMENT ON TABLE product_components IS 'Componentes de una receta';
COMMENT ON TABLE quotations IS 'Cotizaciones de productos y servicios';
COMMENT ON TABLE invoices IS 'Facturas / comprobantes de pago';
COMMENT ON TABLE accounts IS 'Cuentas de caja y banco';
COMMENT ON TABLE cash_movements IS 'Movimientos de efectivo';
COMMENT ON TABLE proveedores IS 'Tabla unificada de proveedores';
COMMENT ON TABLE employees IS 'Empleados de la empresa';
COMMENT ON TABLE payroll IS 'Nómina principal por empleado y período';
COMMENT ON TABLE employee_loans IS 'Préstamos otorgados a empleados';
COMMENT ON TABLE activities IS 'Actividades / organizador / calendario';
COMMENT ON TABLE notifications IS 'Notificaciones del sistema';
COMMENT ON FUNCTION deduct_inventory_item IS 'Descontar material/producto del inventario (bulk para recetas)';
COMMENT ON FUNCTION approve_quotation_with_materials IS 'Aprobar cotización → crear factura y descontar inventario (bulk)';
COMMENT ON FUNCTION atomic_transfer IS 'Transferencia atómica entre cuentas con SELECT FOR UPDATE';
COMMENT ON FUNCTION atomic_movement_with_balance IS 'Crear movimiento + actualizar balance atómicamente';
COMMENT ON FUNCTION refresh_materialized_views IS 'Refrescar todas las vistas materializadas';

-- =========================================================
-- FIN DEL ESQUEMA CONSOLIDADO
-- =========================================================
