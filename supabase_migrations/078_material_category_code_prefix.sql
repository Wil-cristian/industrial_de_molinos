-- Migration 078: Add code_prefix to material_categories for auto-code generation
-- Format: XX-NN[-SUBCAT]-#### where NN = code_prefix of category

ALTER TABLE material_categories ADD COLUMN IF NOT EXISTS code_prefix VARCHAR(5);

-- Populate from sort_order (zero-padded 2 digits)
UPDATE material_categories SET code_prefix = LPAD(sort_order::TEXT, 2, '0')
WHERE code_prefix IS NULL;

-- Fix duplicate sort_order for Bandas y Poleas
UPDATE material_categories SET sort_order = 16, code_prefix = '16'
WHERE slug = 'banda_polea' AND sort_order = 12;
