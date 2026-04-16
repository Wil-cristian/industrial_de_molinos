-- =====================================================
-- MIGRACIÓN 037: Inventario Dimensional
-- Tracking de materiales por largo/área además de peso
-- Para tubos, láminas, perfiles que se cortan por tramos
-- =====================================================

-- =====================================================
-- 1. AGREGAR COLUMNAS DIMENSIONALES A materials
-- =====================================================

-- Dimensiones físicas del material completo (como se compra)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS outer_diameter   DECIMAL(10,2);  -- mm (tubos, ejes)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS wall_thickness   DECIMAL(10,2);  -- mm (espesor pared tubo)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS thickness        DECIMAL(10,2);  -- mm (láminas, placas)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS total_length     DECIMAL(10,2);  -- mm (largo total de la pieza)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS width            DECIMAL(10,2);  -- mm (ancho, para láminas)

-- Stock dimensional (además del stock en KG/UND que ya existe)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS stock_length     DECIMAL(12,2) DEFAULT 0;  -- metros lineales disponibles
ALTER TABLE materials ADD COLUMN IF NOT EXISTS min_stock_length DECIMAL(12,2) DEFAULT 0;  -- alerta de stock mínimo en metros
ALTER TABLE materials ADD COLUMN IF NOT EXISTS stock_area       DECIMAL(12,4) DEFAULT 0;  -- m² disponibles (láminas)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS min_stock_area   DECIMAL(12,4) DEFAULT 0;  -- alerta de stock mínimo en m²

-- Peso por metro lineal (calculado automáticamente para tubos/ejes/perfiles)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS weight_per_meter DECIMAL(10,4) DEFAULT 0;  -- kg/m

-- Tracking mode: define cómo se rastrea este material
-- 'weight'  = solo por peso (default, comportamiento actual)
-- 'length'  = por largo (tubos, ejes, perfiles)
-- 'area'    = por área (láminas, placas)
ALTER TABLE materials ADD COLUMN IF NOT EXISTS tracking_mode VARCHAR(10) DEFAULT 'weight';

-- CHECK constraints
ALTER TABLE materials ADD CONSTRAINT chk_materials_stock_length_non_negative 
    CHECK (stock_length >= 0 OR stock_length IS NULL);
ALTER TABLE materials ADD CONSTRAINT chk_materials_stock_area_non_negative 
    CHECK (stock_area >= 0 OR stock_area IS NULL);
ALTER TABLE materials ADD CONSTRAINT chk_materials_tracking_mode 
    CHECK (tracking_mode IN ('weight', 'length', 'area'));

-- =====================================================
-- 2. TABLA DE PIEZAS/RETAZOS (Remnants)
-- Cuando un tubo se corta y sobra un pedazo
-- =====================================================

CREATE TABLE IF NOT EXISTS material_remnants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    material_id     UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    label           VARCHAR(100),              -- Ej: "Retazo Tubo 42\" x 1/4\""
    length_mm       DECIMAL(10,2) NOT NULL,    -- Largo del retazo en mm
    width_mm        DECIMAL(10,2),             -- Ancho (para láminas)
    weight_kg       DECIMAL(10,4),             -- Peso calculado del retazo
    is_available    BOOLEAN DEFAULT TRUE,       -- Si está disponible para usar
    location        VARCHAR(100),              -- Dónde está guardado
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    used_at         TIMESTAMPTZ,               -- Cuándo se usó
    used_in         VARCHAR(200),              -- En qué cotización/trabajo se usó
    quotation_id    UUID REFERENCES quotations(id)  -- Cotización que lo generó
);

CREATE INDEX IF NOT EXISTS idx_remnants_material  ON material_remnants(material_id);
CREATE INDEX IF NOT EXISTS idx_remnants_available ON material_remnants(is_available);

-- RLS
ALTER TABLE material_remnants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_remnants" ON material_remnants FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON material_remnants TO anon, authenticated;

-- =====================================================
-- 3. AGREGAR COLUMNAS A material_movements
-- Para registrar cortes dimensionales
-- =====================================================

ALTER TABLE material_movements ADD COLUMN IF NOT EXISTS length_cut     DECIMAL(10,2);  -- metros cortados
ALTER TABLE material_movements ADD COLUMN IF NOT EXISTS area_cut       DECIMAL(10,4);  -- m² cortados
ALTER TABLE material_movements ADD COLUMN IF NOT EXISTS remnant_id     UUID REFERENCES material_remnants(id);
ALTER TABLE material_movements ADD COLUMN IF NOT EXISTS dimensions     JSONB DEFAULT '{}';  -- info dimensional completa

-- =====================================================
-- 4. FUNCIÓN: Calcular peso por metro lineal
-- Fórmula para tubos huecos: π × (D² - d²) / 4 × densidad
-- donde D = diámetro exterior, d = diámetro interior
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_weight_per_meter(
    p_material_id UUID
) RETURNS DECIMAL AS $$
DECLARE
    v_mat RECORD;
    v_weight_per_meter DECIMAL(10,4);
    v_inner_diameter DECIMAL;
    v_cross_section_m2 DECIMAL;
BEGIN
    SELECT * INTO v_mat FROM materials WHERE id = p_material_id;
    
    IF v_mat IS NULL THEN
        RETURN 0;
    END IF;
    
    CASE v_mat.category
        -- TUBO: cilindro hueco
        WHEN 'tubo' THEN
            IF v_mat.outer_diameter IS NOT NULL AND v_mat.wall_thickness IS NOT NULL THEN
                v_inner_diameter := v_mat.outer_diameter - (2 * v_mat.wall_thickness);
                -- Área de sección transversal en m² (diámetros en mm → convertir)
                v_cross_section_m2 := PI() * (
                    POWER(v_mat.outer_diameter / 1000.0, 2) - POWER(v_inner_diameter / 1000.0, 2)
                ) / 4.0;
                v_weight_per_meter := v_cross_section_m2 * v_mat.density; -- kg/m
            END IF;
            
        -- EJE: cilindro sólido
        WHEN 'eje' THEN
            IF v_mat.outer_diameter IS NOT NULL THEN
                v_cross_section_m2 := PI() * POWER(v_mat.outer_diameter / 1000.0, 2) / 4.0;
                v_weight_per_meter := v_cross_section_m2 * v_mat.density;
            END IF;
            
        -- LÁMINA/PLACA: peso por metro lineal = ancho × espesor × densidad
        WHEN 'lamina' THEN
            IF v_mat.thickness IS NOT NULL AND v_mat.width IS NOT NULL THEN
                -- Para láminas, peso por m² = espesor(m) × densidad
                -- Pero si queremos kg/m lineal = ancho(m) × espesor(m) × densidad
                v_weight_per_meter := (v_mat.width / 1000.0) * (v_mat.thickness / 1000.0) * v_mat.density;
            ELSIF v_mat.thickness IS NOT NULL THEN
                -- Solo espesor: peso por m² (sin ancho definido)
                v_weight_per_meter := (v_mat.thickness / 1000.0) * v_mat.density;  -- kg/m² en este caso
            END IF;
            
        -- PERFIL ANGULAR: peso estándar por metro (se ingresa manualmente o se calcula)
        WHEN 'perfil', 'angulo' THEN
            -- Para perfiles, generalmente se usa peso/metro de tabla del fabricante
            -- Si tiene espesor y ancho (los 2 lados del ángulo), se puede aproximar
            IF v_mat.thickness IS NOT NULL AND v_mat.width IS NOT NULL THEN
                -- Perfil L: 2 × ancho × espesor × densidad (aproximado)
                v_weight_per_meter := 2.0 * (v_mat.width / 1000.0) * (v_mat.thickness / 1000.0) * v_mat.density;
            END IF;
            
        ELSE
            -- Para otros materiales, mantener el valor existente
            v_weight_per_meter := COALESCE(v_mat.weight_per_meter, 0);
    END CASE;
    
    -- Actualizar en la tabla
    IF v_weight_per_meter IS NOT NULL AND v_weight_per_meter > 0 THEN
        UPDATE materials 
        SET weight_per_meter = ROUND(v_weight_per_meter, 4),
            updated_at = NOW()
        WHERE id = p_material_id;
    END IF;
    
    RETURN COALESCE(v_weight_per_meter, 0);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. FUNCIÓN: Cortar material por longitud
-- Descuenta metros Y kilos automáticamente
-- =====================================================

CREATE OR REPLACE FUNCTION cut_material_by_length(
    p_material_id UUID,
    p_length_meters DECIMAL,      -- metros a cortar
    p_reason TEXT DEFAULT NULL,
    p_reference TEXT DEFAULT NULL,
    p_quotation_id UUID DEFAULT NULL,
    p_create_remnant BOOLEAN DEFAULT FALSE,  -- crear retazo del sobrante
    p_remnant_length_mm DECIMAL DEFAULT NULL -- largo del retazo en mm
) RETURNS JSONB AS $$
DECLARE
    v_mat RECORD;
    v_weight_cut DECIMAL(10,4);
    v_movement_id UUID;
    v_remnant_id UUID;
    v_result JSONB;
BEGIN
    -- Obtener material
    SELECT * INTO v_mat FROM materials WHERE id = p_material_id;
    
    IF v_mat IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Material no encontrado');
    END IF;
    
    -- Validar que el material se trackea por longitud
    IF v_mat.tracking_mode NOT IN ('length', 'area') THEN
        RETURN jsonb_build_object('success', false, 'error', 
            'Este material se rastrea por peso, no por longitud. Use deducción estándar.');
    END IF;
    
    -- Validar stock de longitud disponible
    IF v_mat.stock_length < p_length_meters THEN
        RETURN jsonb_build_object('success', false, 'error', 
            format('Stock insuficiente: disponible %.2f m, solicitado %.2f m', 
                   v_mat.stock_length, p_length_meters));
    END IF;
    
    -- Calcular peso del tramo cortado
    v_weight_cut := COALESCE(v_mat.weight_per_meter, 0) * p_length_meters;
    
    -- Registrar movimiento
    INSERT INTO material_movements (
        material_id, type, quantity, 
        previous_stock, new_stock,
        length_cut, 
        dimensions,
        reason, reference, quotation_id
    ) VALUES (
        p_material_id, 'outgoing', v_weight_cut,
        v_mat.stock, v_mat.stock - v_weight_cut,
        p_length_meters,
        jsonb_build_object(
            'outer_diameter_mm', v_mat.outer_diameter,
            'wall_thickness_mm', v_mat.wall_thickness,
            'thickness_mm', v_mat.thickness,
            'length_cut_m', p_length_meters,
            'weight_cut_kg', v_weight_cut,
            'weight_per_meter', v_mat.weight_per_meter
        ),
        COALESCE(p_reason, 'Corte de material'),
        p_reference,
        p_quotation_id
    ) RETURNING id INTO v_movement_id;
    
    -- Actualizar stock (peso Y longitud)
    UPDATE materials SET
        stock = stock - v_weight_cut,
        stock_length = stock_length - p_length_meters,
        updated_at = NOW()
    WHERE id = p_material_id;
    
    -- Crear retazo si se solicita
    IF p_create_remnant AND p_remnant_length_mm IS NOT NULL AND p_remnant_length_mm > 0 THEN
        INSERT INTO material_remnants (
            material_id, label, length_mm, weight_kg,
            location, notes, quotation_id
        ) VALUES (
            p_material_id,
            format('Retazo %s - %.0f mm', v_mat.name, p_remnant_length_mm),
            p_remnant_length_mm,
            COALESCE(v_mat.weight_per_meter, 0) * (p_remnant_length_mm / 1000.0),
            v_mat.location,
            format('Generado al cortar %.2f m para: %s', p_length_meters, COALESCE(p_reference, 'uso directo')),
            p_quotation_id
        ) RETURNING id INTO v_remnant_id;
        
        -- Vincular retazo al movimiento
        UPDATE material_movements SET remnant_id = v_remnant_id WHERE id = v_movement_id;
    END IF;
    
    v_result := jsonb_build_object(
        'success', true,
        'material_id', p_material_id,
        'material_name', v_mat.name,
        'length_cut_m', p_length_meters,
        'weight_cut_kg', ROUND(v_weight_cut, 4),
        'remaining_length_m', v_mat.stock_length - p_length_meters,
        'remaining_weight_kg', v_mat.stock - v_weight_cut,
        'movement_id', v_movement_id,
        'remnant_id', v_remnant_id
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. FUNCIÓN: Cortar lámina por área
-- Descuenta m² Y kilos automáticamente
-- =====================================================

CREATE OR REPLACE FUNCTION cut_material_by_area(
    p_material_id UUID,
    p_length_meters DECIMAL,     -- largo del corte en metros
    p_width_meters DECIMAL,      -- ancho del corte en metros
    p_reason TEXT DEFAULT NULL,
    p_reference TEXT DEFAULT NULL,
    p_quotation_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_mat RECORD;
    v_area_cut DECIMAL(10,4);
    v_weight_cut DECIMAL(10,4);
    v_movement_id UUID;
BEGIN
    SELECT * INTO v_mat FROM materials WHERE id = p_material_id;
    
    IF v_mat IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Material no encontrado');
    END IF;
    
    IF v_mat.tracking_mode != 'area' THEN
        RETURN jsonb_build_object('success', false, 'error', 
            'Este material no se rastrea por área');
    END IF;
    
    v_area_cut := p_length_meters * p_width_meters;
    
    IF v_mat.stock_area < v_area_cut THEN
        RETURN jsonb_build_object('success', false, 'error', 
            format('Área insuficiente: disponible %.4f m², solicitado %.4f m²', 
                   v_mat.stock_area, v_area_cut));
    END IF;
    
    -- Peso = área(m²) × espesor(m) × densidad(kg/m³)
    v_weight_cut := v_area_cut * COALESCE(v_mat.thickness, 0) / 1000.0 * v_mat.density;
    
    INSERT INTO material_movements (
        material_id, type, quantity,
        previous_stock, new_stock,
        area_cut, dimensions,
        reason, reference, quotation_id
    ) VALUES (
        p_material_id, 'outgoing', v_weight_cut,
        v_mat.stock, v_mat.stock - v_weight_cut,
        v_area_cut,
        jsonb_build_object(
            'length_m', p_length_meters,
            'width_m', p_width_meters,
            'area_m2', v_area_cut,
            'thickness_mm', v_mat.thickness,
            'weight_kg', v_weight_cut
        ),
        COALESCE(p_reason, 'Corte de lámina'),
        p_reference,
        p_quotation_id
    ) RETURNING id INTO v_movement_id;
    
    UPDATE materials SET
        stock = stock - v_weight_cut,
        stock_area = stock_area - v_area_cut,
        updated_at = NOW()
    WHERE id = p_material_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'material_id', p_material_id,
        'material_name', v_mat.name,
        'area_cut_m2', v_area_cut,
        'weight_cut_kg', ROUND(v_weight_cut, 4),
        'remaining_area_m2', v_mat.stock_area - v_area_cut,
        'remaining_weight_kg', v_mat.stock - v_weight_cut,
        'movement_id', v_movement_id
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. FUNCIÓN: Usar retazo existente
-- =====================================================

CREATE OR REPLACE FUNCTION use_remnant(
    p_remnant_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_reference TEXT DEFAULT NULL,
    p_quotation_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_remnant RECORD;
BEGIN
    SELECT * INTO v_remnant FROM material_remnants WHERE id = p_remnant_id;
    
    IF v_remnant IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Retazo no encontrado');
    END IF;
    
    IF NOT v_remnant.is_available THEN
        RETURN jsonb_build_object('success', false, 'error', 'Retazo ya fue utilizado');
    END IF;
    
    -- Marcar como usado
    UPDATE material_remnants SET
        is_available = false,
        used_at = NOW(),
        used_in = COALESCE(p_reference, p_reason),
        quotation_id = COALESCE(p_quotation_id, v_remnant.quotation_id)
    WHERE id = p_remnant_id;
    
    -- NO descontar stock (el retazo ya fue descontado cuando se cortó el tubo original)
    
    RETURN jsonb_build_object(
        'success', true,
        'remnant_id', p_remnant_id,
        'material_id', v_remnant.material_id,
        'length_mm', v_remnant.length_mm,
        'weight_kg', v_remnant.weight_kg
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. TRIGGER: Auto-calcular weight_per_meter al insertar/actualizar
-- =====================================================

CREATE OR REPLACE FUNCTION trg_calculate_weight_per_meter()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo recalcular si cambiaron las dimensiones o la categoría
    IF TG_OP = 'INSERT' OR 
       NEW.outer_diameter IS DISTINCT FROM OLD.outer_diameter OR
       NEW.wall_thickness IS DISTINCT FROM OLD.wall_thickness OR
       NEW.thickness IS DISTINCT FROM OLD.thickness OR
       NEW.width IS DISTINCT FROM OLD.width OR
       NEW.density IS DISTINCT FROM OLD.density OR
       NEW.category IS DISTINCT FROM OLD.category THEN
        
        -- Auto-detectar tracking_mode basado en categoría si no fue establecido explícitamente
        IF NEW.tracking_mode = 'weight' AND NEW.category IN ('tubo', 'eje', 'perfil', 'angulo') THEN
            NEW.tracking_mode := 'length';
        ELSIF NEW.tracking_mode = 'weight' AND NEW.category = 'lamina' THEN
            NEW.tracking_mode := 'area';
        END IF;
        
        -- Calcular weight_per_meter
        CASE NEW.category
            WHEN 'tubo' THEN
                IF NEW.outer_diameter IS NOT NULL AND NEW.wall_thickness IS NOT NULL THEN
                    DECLARE
                        v_inner DECIMAL := NEW.outer_diameter - (2 * NEW.wall_thickness);
                    BEGIN
                        NEW.weight_per_meter := ROUND(
                            PI() * (POWER(NEW.outer_diameter/1000.0, 2) - POWER(v_inner/1000.0, 2)) / 4.0 * NEW.density
                        , 4);
                    END;
                END IF;
            WHEN 'eje' THEN
                IF NEW.outer_diameter IS NOT NULL THEN
                    NEW.weight_per_meter := ROUND(
                        PI() * POWER(NEW.outer_diameter/1000.0, 2) / 4.0 * NEW.density
                    , 4);
                END IF;
            WHEN 'lamina' THEN
                IF NEW.thickness IS NOT NULL THEN
                    -- kg/m² (peso por metro cuadrado)
                    NEW.weight_per_meter := ROUND(
                        (NEW.thickness / 1000.0) * NEW.density
                    , 4);
                END IF;
            WHEN 'perfil', 'angulo' THEN
                IF NEW.thickness IS NOT NULL AND NEW.width IS NOT NULL THEN
                    NEW.weight_per_meter := ROUND(
                        2.0 * (NEW.width/1000.0) * (NEW.thickness/1000.0) * NEW.density
                    , 4);
                END IF;
            ELSE
                NULL;
        END CASE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_materials_calc_weight ON materials;
CREATE TRIGGER trg_materials_calc_weight
    BEFORE INSERT OR UPDATE ON materials
    FOR EACH ROW
    EXECUTE FUNCTION trg_calculate_weight_per_meter();

-- =====================================================
-- 9. ACTUALIZAR FUNCIÓN DE DEDUCCIÓN PARA INCLUIR DIMENSIONAL
-- Modificar approve_quotation_with_materials para manejar cortes
-- =====================================================

-- Agregar columna a quotation_items para especificar longitud del corte
ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS cut_length DECIMAL(10,3);  -- metros a cortar
ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS cut_width  DECIMAL(10,3);  -- metros (para láminas)
ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS tracking_mode VARCHAR(10); -- heredado del material

-- =====================================================
-- 10. FUNCIÓN: Deducir inventario con soporte dimensional
-- Reemplaza deduct_inventory_item para manejar cortes por largo
-- =====================================================

CREATE OR REPLACE FUNCTION deduct_inventory_item(
    p_material_id UUID,
    p_product_id UUID,
    p_quantity INTEGER,
    p_reference TEXT DEFAULT NULL,
    p_item_name TEXT DEFAULT NULL,
    p_quotation_id UUID DEFAULT NULL,
    p_invoice_id UUID DEFAULT NULL,
    p_cut_length DECIMAL DEFAULT NULL,  -- NUEVO: metros a cortar
    p_cut_width DECIMAL DEFAULT NULL    -- NUEVO: ancho del corte (láminas)
) RETURNS JSONB AS $$
DECLARE
    v_mat RECORD;
    v_prod RECORD;
    v_result JSONB := '{}'::JSONB;
    v_weight_deducted DECIMAL;
    v_length_deducted DECIMAL;
    v_area_deducted DECIMAL;
BEGIN
    -- ========== MATERIAL DIRECTO ==========
    IF p_material_id IS NOT NULL THEN
        SELECT * INTO v_mat FROM materials WHERE id = p_material_id;
        
        IF v_mat IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Material no encontrado: ' || p_material_id);
        END IF;
        
        -- Decidir tipo de deducción según tracking_mode
        IF v_mat.tracking_mode = 'length' AND p_cut_length IS NOT NULL AND p_cut_length > 0 THEN
            -- DEDUCCIÓN POR LONGITUD
            v_length_deducted := p_cut_length * p_quantity;
            v_weight_deducted := COALESCE(v_mat.weight_per_meter, 0) * v_length_deducted;
            
            IF v_mat.stock_length < v_length_deducted THEN
                RETURN jsonb_build_object('success', false, 'error', 
                    format('Stock insuficiente de "%s": disponible %.2f m, solicitado %.2f m',
                           v_mat.name, v_mat.stock_length, v_length_deducted));
            END IF;
            
            INSERT INTO material_movements (
                material_id, type, quantity,
                previous_stock, new_stock,
                length_cut, dimensions,
                reason, reference, quotation_id, invoice_id
            ) VALUES (
                p_material_id, 'outgoing', v_weight_deducted,
                v_mat.stock, v_mat.stock - v_weight_deducted,
                v_length_deducted,
                jsonb_build_object(
                    'cut_length_m', p_cut_length,
                    'qty', p_quantity,
                    'total_length_m', v_length_deducted,
                    'weight_per_meter', v_mat.weight_per_meter,
                    'total_weight_kg', v_weight_deducted
                ),
                COALESCE(p_item_name, 'Corte: ' || v_mat.name),
                p_reference, p_quotation_id, p_invoice_id
            );
            
            UPDATE materials SET
                stock = stock - v_weight_deducted,
                stock_length = stock_length - v_length_deducted,
                updated_at = NOW()
            WHERE id = p_material_id;
            
            v_result := jsonb_build_object(
                'success', true,
                'material', v_mat.name,
                'type', 'length_cut',
                'length_m', v_length_deducted,
                'weight_kg', ROUND(v_weight_deducted, 4),
                'remaining_length_m', v_mat.stock_length - v_length_deducted,
                'remaining_weight_kg', v_mat.stock - v_weight_deducted
            );
            
        ELSIF v_mat.tracking_mode = 'area' AND p_cut_length IS NOT NULL AND p_cut_width IS NOT NULL THEN
            -- DEDUCCIÓN POR ÁREA
            v_area_deducted := p_cut_length * p_cut_width * p_quantity;
            v_weight_deducted := v_area_deducted * COALESCE(v_mat.thickness, 0) / 1000.0 * v_mat.density;
            
            IF v_mat.stock_area < v_area_deducted THEN
                RETURN jsonb_build_object('success', false, 'error',
                    format('Área insuficiente de "%s": disponible %.4f m², solicitado %.4f m²',
                           v_mat.name, v_mat.stock_area, v_area_deducted));
            END IF;
            
            INSERT INTO material_movements (
                material_id, type, quantity,
                previous_stock, new_stock,
                area_cut, dimensions,
                reason, reference, quotation_id, invoice_id
            ) VALUES (
                p_material_id, 'outgoing', v_weight_deducted,
                v_mat.stock, v_mat.stock - v_weight_deducted,
                v_area_deducted,
                jsonb_build_object(
                    'cut_length_m', p_cut_length,
                    'cut_width_m', p_cut_width,
                    'area_m2', v_area_deducted,
                    'weight_kg', v_weight_deducted
                ),
                COALESCE(p_item_name, 'Corte lámina: ' || v_mat.name),
                p_reference, p_quotation_id, p_invoice_id
            );
            
            UPDATE materials SET
                stock = stock - v_weight_deducted,
                stock_area = stock_area - v_area_deducted,
                updated_at = NOW()
            WHERE id = p_material_id;
            
            v_result := jsonb_build_object(
                'success', true,
                'material', v_mat.name,
                'type', 'area_cut',
                'area_m2', v_area_deducted,
                'weight_kg', ROUND(v_weight_deducted, 4)
            );
            
        ELSE
            -- DEDUCCIÓN ESTÁNDAR POR PESO/UNIDAD (comportamiento original)
            IF v_mat.stock < p_quantity THEN
                RETURN jsonb_build_object('success', false, 'error',
                    format('Stock insuficiente de "%s": disponible %.2f %s, solicitado %s',
                           v_mat.name, v_mat.stock, v_mat.unit, p_quantity));
            END IF;
            
            INSERT INTO material_movements (
                material_id, type, quantity,
                previous_stock, new_stock,
                reason, reference, quotation_id, invoice_id
            ) VALUES (
                p_material_id, 'outgoing', p_quantity,
                v_mat.stock, v_mat.stock - p_quantity,
                COALESCE(p_item_name, v_mat.name),
                p_reference, p_quotation_id, p_invoice_id
            );
            
            UPDATE materials SET
                stock = stock - p_quantity,
                updated_at = NOW()
            WHERE id = p_material_id;
            
            v_result := jsonb_build_object(
                'success', true,
                'material', v_mat.name,
                'type', 'standard',
                'quantity', p_quantity,
                'unit', v_mat.unit
            );
        END IF;
        
        RETURN v_result;
    END IF;
    
    -- ========== PRODUCTO/RECETA ==========
    IF p_product_id IS NOT NULL THEN
        SELECT * INTO v_prod FROM products WHERE id = p_product_id;
        
        IF v_prod IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado');
        END IF;
        
        IF v_prod.is_recipe = true THEN
            -- Receta: deducir componentes (bulk)
            -- Validar stock de todos los componentes
            DECLARE
                v_insufficient RECORD;
            BEGIN
                SELECT m.name AS mat_name, m.stock AS available, agg.total_required
                INTO v_insufficient
                FROM (
                    SELECT pc.material_id, SUM(pc.quantity * p_quantity) as total_required
                    FROM product_components pc
                    WHERE pc.product_id = p_product_id AND pc.material_id IS NOT NULL
                    GROUP BY pc.material_id
                ) agg
                JOIN materials m ON m.id = agg.material_id
                WHERE m.stock < agg.total_required
                LIMIT 1;
                
                IF v_insufficient IS NOT NULL THEN
                    RETURN jsonb_build_object('success', false, 'error',
                        format('Stock insuficiente de "%s": disponible %.2f, requerido %.2f',
                               v_insufficient.mat_name, v_insufficient.available, v_insufficient.total_required));
                END IF;
            END;
            
            -- Bulk insert movimientos
            INSERT INTO material_movements (
                material_id, type, quantity,
                previous_stock, new_stock,
                reason, reference, quotation_id, invoice_id
            )
            SELECT pc.material_id, 'outgoing', pc.quantity * p_quantity,
                   m.stock, m.stock - (pc.quantity * p_quantity),
                   'Receta: ' || v_prod.name || ' - ' || pc.name,
                   p_reference, p_quotation_id, p_invoice_id
            FROM product_components pc
            JOIN materials m ON m.id = pc.material_id
            WHERE pc.product_id = p_product_id AND pc.material_id IS NOT NULL;
            
            -- Bulk update stocks
            UPDATE materials SET
                stock = materials.stock - agg.total_qty,
                updated_at = NOW()
            FROM (
                SELECT pc.material_id, SUM(pc.quantity * p_quantity) as total_qty
                FROM product_components pc
                WHERE pc.product_id = p_product_id AND pc.material_id IS NOT NULL
                GROUP BY pc.material_id
            ) agg
            WHERE materials.id = agg.material_id;
            
            v_result := jsonb_build_object(
                'success', true,
                'product', v_prod.name,
                'type', 'recipe',
                'components_deducted', (
                    SELECT COUNT(*) FROM product_components 
                    WHERE product_id = p_product_id AND material_id IS NOT NULL
                )
            );
        ELSE
            -- Producto simple
            IF v_prod.stock < p_quantity THEN
                RETURN jsonb_build_object('success', false, 'error',
                    format('Stock insuficiente de "%s": disponible %.2f, solicitado %s',
                           v_prod.name, v_prod.stock, p_quantity));
            END IF;
            
            UPDATE products SET stock = stock - p_quantity, updated_at = NOW()
            WHERE id = p_product_id;
            
            v_result := jsonb_build_object(
                'success', true,
                'product', v_prod.name,
                'type', 'simple_product',
                'quantity', p_quantity
            );
        END IF;
        
        RETURN v_result;
    END IF;
    
    RETURN jsonb_build_object('success', false, 'error', 'Ni material_id ni product_id proporcionado');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 11. VISTA: Resumen de inventario dimensional
-- =====================================================

CREATE OR REPLACE VIEW v_dimensional_inventory AS
SELECT 
    m.id,
    m.code,
    m.name,
    m.category,
    m.tracking_mode,
    m.unit,
    m.stock AS stock_kg,
    m.stock_length AS stock_metros,
    m.stock_area AS stock_m2,
    m.outer_diameter,
    m.wall_thickness,
    m.thickness,
    m.total_length,
    m.width,
    m.weight_per_meter,
    m.price_per_kg,
    m.cost_price,
    m.min_stock,
    m.min_stock_length,
    m.min_stock_area,
    -- Alertas
    CASE 
        WHEN m.tracking_mode = 'length' AND m.stock_length <= m.min_stock_length THEN true
        WHEN m.tracking_mode = 'area' AND m.stock_area <= m.min_stock_area THEN true
        WHEN m.stock <= m.min_stock THEN true
        ELSE false
    END AS is_low_stock,
    -- Valor del inventario
    m.stock * m.cost_price AS inventory_value,
    -- Retazos disponibles
    (SELECT COUNT(*) FROM material_remnants r WHERE r.material_id = m.id AND r.is_available) AS remnants_count,
    (SELECT COALESCE(SUM(r.length_mm), 0) FROM material_remnants r WHERE r.material_id = m.id AND r.is_available) AS remnants_total_length_mm
FROM materials m
WHERE m.is_active = true
ORDER BY m.category, m.name;

-- =====================================================
-- 12. PERMISOS
-- =====================================================

GRANT EXECUTE ON FUNCTION calculate_weight_per_meter TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cut_material_by_length TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cut_material_by_area TO anon, authenticated;
GRANT EXECUTE ON FUNCTION use_remnant TO anon, authenticated;
GRANT SELECT ON v_dimensional_inventory TO anon, authenticated;

-- Reload schema
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- 13. COMENTARIOS
-- =====================================================

COMMENT ON COLUMN materials.tracking_mode IS 'Modo de rastreo: weight=por peso, length=por metros, area=por m²';
COMMENT ON COLUMN materials.stock_length IS 'Stock en metros lineales disponibles';
COMMENT ON COLUMN materials.stock_area IS 'Stock en metros cuadrados disponibles';
COMMENT ON COLUMN materials.weight_per_meter IS 'Peso por metro lineal (kg/m), calculado automáticamente';
COMMENT ON COLUMN materials.outer_diameter IS 'Diámetro exterior en mm (tubos, ejes)';
COMMENT ON COLUMN materials.wall_thickness IS 'Espesor de pared en mm (tubos)';
COMMENT ON COLUMN materials.thickness IS 'Espesor en mm (láminas, placas)';
COMMENT ON COLUMN materials.total_length IS 'Largo total de la pieza en mm (como se compra)';
COMMENT ON COLUMN materials.width IS 'Ancho en mm (láminas)';
COMMENT ON TABLE material_remnants IS 'Retazos/sobrantes de materiales cortados';
COMMENT ON FUNCTION cut_material_by_length IS 'Cortar material por longitud, descuenta metros y kg automáticamente';
COMMENT ON FUNCTION cut_material_by_area IS 'Cortar lámina por área, descuenta m² y kg automáticamente';

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
SELECT '✅ Migración 037 - Inventario Dimensional completada' AS resultado;
SELECT 'Nuevas columnas en materials: outer_diameter, wall_thickness, thickness, total_length, width, stock_length, stock_area, weight_per_meter, tracking_mode' AS detalle;
SELECT 'Nueva tabla: material_remnants (retazos)' AS detalle;
SELECT 'Nuevas funciones: cut_material_by_length, cut_material_by_area, use_remnant, calculate_weight_per_meter' AS detalle;
