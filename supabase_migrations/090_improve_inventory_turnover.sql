-- ============================================================
-- 090: Mejorar v_inventory_turnover con compras y ventas
-- Incluye: invoice_items (ventas), stock_movements (entradas/salidas),
--          purchase_order_items (compras via escaneo IVA)
-- ============================================================

DROP VIEW IF EXISTS v_inventory_turnover;

CREATE VIEW v_inventory_turnover AS
SELECT 
    p.id AS product_id,
    p.code AS product_code,
    p.name AS product_name,
    c.name AS category,
    p.stock AS current_stock,
    p.unit_price,
    p.cost_price,
    p.stock * COALESCE(NULLIF(p.cost_price, 0), p.unit_price) AS stock_value,
    -- Ventas: desde invoice_items (facturas) en últimos 90 días
    COALESCE(sales.qty_sold_90d, 0) AS qty_sold_90_days,
    COALESCE(sales.revenue_90d, 0) AS revenue_90_days,
    -- Compras: desde purchase_order_items (órdenes de compra recibidas) en últimos 90 días
    COALESCE(purchases.qty_purchased_90d, 0) AS qty_purchased_90_days,
    -- Movimientos de stock: entradas y salidas directas
    COALESCE(movements.qty_in_90d, 0) AS qty_in_90_days,
    COALESCE(movements.qty_out_90d, 0) AS qty_out_90_days,
    -- Total movimiento = ventas + salidas de stock
    COALESCE(sales.qty_sold_90d, 0) + COALESCE(movements.qty_out_90d, 0) AS total_outflow_90d,
    -- Total entradas = compras + entradas de stock
    COALESCE(purchases.qty_purchased_90d, 0) + COALESCE(movements.qty_in_90d, 0) AS total_inflow_90d,
    -- Rotación anualizada basada en salidas totales (ventas + salidas stock)
    CASE WHEN p.stock > 0 AND (COALESCE(sales.qty_sold_90d, 0) + COALESCE(movements.qty_out_90d, 0)) > 0
         THEN ROUND((((COALESCE(sales.qty_sold_90d, 0) + COALESCE(movements.qty_out_90d, 0)) / 90.0 * 365) / p.stock)::NUMERIC, 2)
         ELSE 0 END AS annual_turnover_rate,
    -- Días de inventario basado en salidas totales
    CASE WHEN (COALESCE(sales.qty_sold_90d, 0) + COALESCE(movements.qty_out_90d, 0)) > 0
         THEN ROUND((p.stock / ((COALESCE(sales.qty_sold_90d, 0) + COALESCE(movements.qty_out_90d, 0)) / 90.0))::NUMERIC, 0)
         ELSE 999 END AS days_of_inventory,
    -- Estado del inventario
    CASE 
        WHEN p.stock <= 0 THEN 'SIN_STOCK'
        WHEN p.stock <= p.min_stock THEN 'STOCK_BAJO'
        WHEN (COALESCE(sales.qty_sold_90d, 0) + COALESCE(movements.qty_out_90d, 0)) = 0 THEN 'SIN_MOVIMIENTO'
        WHEN p.stock / NULLIF((COALESCE(sales.qty_sold_90d, 0) + COALESCE(movements.qty_out_90d, 0)) / 90.0, 0) > 180 THEN 'SOBREINVENTARIO'
        ELSE 'NORMAL'
    END AS inventory_status
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
-- Ventas desde facturas
LEFT JOIN LATERAL (
    SELECT 
        COALESCE(SUM(ii.quantity), 0) AS qty_sold_90d,
        COALESCE(SUM(ii.total), 0) AS revenue_90d
    FROM invoice_items ii
    JOIN invoices i ON i.id = ii.invoice_id
    WHERE ii.product_id = p.id
    AND i.status NOT IN ('cancelled')
    AND i.issue_date >= NOW() - INTERVAL '90 days'
) sales ON TRUE
-- Movimientos directos de stock (entradas/salidas manuales y ajustes)
LEFT JOIN LATERAL (
    SELECT 
        COALESCE(SUM(CASE WHEN sm.type = 'incoming' THEN sm.quantity ELSE 0 END), 0) AS qty_in_90d,
        COALESCE(SUM(CASE WHEN sm.type = 'outgoing' THEN ABS(sm.quantity) ELSE 0 END), 0) AS qty_out_90d
    FROM stock_movements sm
    WHERE sm.product_id = p.id
    AND sm.created_at >= NOW() - INTERVAL '90 days'
) movements ON TRUE
-- Compras desde órdenes de compra recibidas (escaneo IVA)
LEFT JOIN LATERAL (
    SELECT 
        COALESCE(SUM(poi.quantity_received), 0) AS qty_purchased_90d
    FROM purchase_order_items poi
    JOIN purchase_orders po ON po.id = poi.order_id
    WHERE poi.material_id::text = p.id::text  -- en caso de que el producto tenga material asociado
    AND po.status IN ('recibida', 'parcial')
    AND po.created_at >= NOW() - INTERVAL '90 days'
) purchases ON TRUE
WHERE p.is_active = TRUE;
