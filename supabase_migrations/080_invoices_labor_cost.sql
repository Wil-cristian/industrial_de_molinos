-- Migration 080: Add labor_cost column to invoices
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS labor_cost NUMERIC DEFAULT 0;
