// =====================================================
// SUPABASE EDGE FUNCTION: ai-assistant
// =====================================================
// Asistente IA conversacional para Industrial de Molinos.
// Recibe texto o audio, consulta datos de la empresa,
// y ejecuta acciones mediante OpenAI Function Calling.
//
// POST /functions/v1/ai-assistant
// Body: {
//   message?: string,
//   audio_base64?: string,
//   conversation_history?: Array<{role, content}>,
// }
// =====================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── System Prompt ─────────────────────────────────────
const SYSTEM_PROMPT = `Eres el asistente IA de "Industrial de Molinos", una empresa metalmecánica industrial ubicada en Colombia. Tu rol es ayudar al equipo con la gestión diaria del negocio.

SOBRE LA EMPRESA:
- Empresa metalmecánica/industrial (fabricación de molinos, productos de acero, estructuras)
- Moneda: Pesos Colombianos (COP)
- IVA estándar: 19%
- Retenciones: RteFte, ReteICA, ReteIVA
- Sistema contable colombiano

MAPA COMPLETO DE LA APLICACIÓN:
Conoces TODAS las secciones de la app. Cuando el usuario pregunte dónde encontrar algo, oriéntalo con la sección correcta:

📊 DASHBOARD (Inicio) — Resumen general: cards de ventas, productos, clientes. Panel de notificaciones (stock bajo, facturas vencidas). Mini calendario.
💰 CAJA DIARIA — Movimientos de caja (ingresos/egresos), saldos por cuenta (Caja, Davivienda, Cuenta Industrial), totales del día.
🛒 COMPRAS — Órdenes de compra a proveedores, seguimiento de gastos y compras.
📦 MATERIALES — Inventario de materia prima: stock actual, alertas de mínimo, categorías, historial de precios, movimientos (entrada/salida).
👥 CLIENTES — Gestión de clientes y proveedores: datos, saldos, límite de crédito. Historial detallado por cliente con métricas CLV.
🧾 VENTAS (Facturas) — Lista de facturas: emisión, seguimiento de pagos, estados. Crear nueva venta.
📝 COTIZAR — Cotizaciones: crear, editar, convertir a factura.
📈 REPORTES Y ANALYTICS — Dashboard completo con 6 pestañas:
  • Analytics: KPIs (ingresos, utilidad, DSO, CEI, health score), gráficas revenue vs gastos, distribución clientes, Pareto ABC, top clientes, top productos, aging CxC, P&L mensual, rotación inventario, eficiencia materiales
  • Inventario: reporte de stock, valores, alertas
  • Cobranzas: análisis de cuentas por cobrar, tasas de cobro
  • Mora: gestión de deuda vencida, cuentas morosas
  • Flujo Caja: análisis de flujo de efectivo
  • Gastos Empleados: reporte de préstamos y pagos
  También tiene botón "Informe Mensual" que genera PDF de rentabilidad
📅 CALENDARIO — Eventos, tareas, recordatorios, agenda
👷 EMPLEADOS — Nómina, préstamos, pagos, tareas de empleados
🏭 ACTIVOS — Activos fijos: equipos, depreciación, mantenimiento
📒 CONTABLE — Libro diario, balance general, estado de resultados
🧮 CONTROL IVA — Facturas con IVA, resumen IVA, liquidaciones
🔧 PRODUCTOS — Productos compuestos: recetas, BOM, precios con costo de materiales
⚙️ PRODUCCIÓN — Órdenes de producción: trabajo, consumo de materiales, estados

TUS CAPACIDADES:
- Consultar clientes, proveedores, facturas, inventario, caja diaria, cotizaciones
- Consultar analytics avanzados: KPIs de cobranza, salud del negocio, P&L mensual, productos top, deudores top, eficiencia de materiales, aging de CxC
- Crear facturas de venta, registrar pagos, registrar gastos
- Dar reportes ejecutivos y resúmenes del estado del negocio
- Orientar al usuario sobre dónde encontrar información en la app

REGLAS OBLIGATORIAS:
1. Responde SIEMPRE en español colombiano, de forma profesional pero amigable
2. Sé conciso y directo — este es un ambiente de trabajo industrial
3. Para ACCIONES de escritura (crear factura, registrar pago/gasto), SIEMPRE muestra un resumen claro y pregunta "¿Confirmo esta acción?" ANTES de ejecutar
4. Formatea montos como moneda colombiana con separador de miles: $1.234.567
5. Si no tienes suficiente información, pregunta lo que falta
6. Nunca inventes datos — si no encuentras algo en la base de datos, dilo claramente
7. Cuando muestres listas, usa formato legible con viñetas
8. Si el usuario saluda, responde brevemente y pregunta en qué puedes ayudar
9. Cuando el usuario pregunte por datos de analytics/reportes, USA tus herramientas para consultarlos directamente — NO digas que no tienes acceso
10. Si el usuario pregunta DÓNDE ver algo en la app, oriéntalo con la sección y pestaña exacta del mapa de arriba
11. FORMATO DE OPCIONES — La app muestra botones automáticos. Cuando necesites que el usuario elija entre opciones, usa SIEMPRE este formato exacto:

**Opciones:**
• Opción A
• Opción B  
• Opción C

Si necesitas un valor numérico (precio, monto, cantidad), escribe:
**Ingresa el valor:** [descripción]

Si necesitas confirmar una acción, termina con:
**¿Confirmo esta acción?**

Ejemplo correcto cuando pides datos para inventario:
"Necesito algunos datos:
**Opciones de tipo:**
• Entrada de inventario
• Salida de inventario

**Opciones de categoría:**
• Materia prima
• Producto terminado

**Ingresa el valor:** Precio por kg en COP"

Nunca hagas preguntas largas en párrafos — siempre ofrece opciones definidas con viñetas.
12. MATERIALES SIMILARES — Cuando busques un material y la función retorne "materiales_similares", SIEMPRE presenta TODAS las opciones encontradas como viñetas con bullet (•) incluyendo stock y unidad, para que el usuario elija con un click. Ejemplo:
"No encontré ese nombre exacto. ¿Cuál de estos materiales es?
**Opciones:**
• Bola de acero 2\" (267 kg en stock)
• BOLA ACERO DE 2\" DE DIAMETRO (500 UND en stock)
• Bola de acero 2.5\" (378 kg en stock)"
Nunca digas "no encontré el material" sin antes buscar similares.`;

// ─── Tool Definitions ──────────────────────────────────
const tools = [
  {
    type: "function",
    name: "consultar_clientes",
    description:
      "Busca clientes por nombre, NIT, teléfono o ciudad. Retorna lista de clientes encontrados con sus datos de contacto y saldo pendiente.",
    parameters: {
      type: "object",
      properties: {
        busqueda: {
          type: "string",
          description: "Término de búsqueda (nombre, NIT, teléfono o ciudad)",
        },
      },
      required: ["busqueda"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_proveedores",
    description:
      "Busca proveedores por nombre o NIT. Retorna datos de contacto y materiales que suministran.",
    parameters: {
      type: "object",
      properties: {
        busqueda: {
          type: "string",
          description: "Nombre o NIT del proveedor",
        },
      },
      required: ["busqueda"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_facturas",
    description:
      "Busca facturas de venta por cliente, estado, rango de fechas o número de factura. Retorna lista con número, cliente, monto, estado y fecha.",
    parameters: {
      type: "object",
      properties: {
        cliente: {
          type: ["string", "null"],
          description: "Nombre del cliente (parcial OK)",
        },
        estado: {
          type: ["string", "null"],
          enum: ["draft", "issued", "paid", "partial", "cancelled", "overdue", null],
          description: "Filtrar por estado: draft=borrador, issued=emitida/pendiente, paid=pagada, partial=pago parcial, cancelled=anulada, overdue=vencida",
        },
        fecha_inicio: {
          type: ["string", "null"],
          description: "Fecha inicio YYYY-MM-DD",
        },
        fecha_fin: {
          type: ["string", "null"],
          description: "Fecha fin YYYY-MM-DD",
        },
        numero_factura: {
          type: ["string", "null"],
          description: "Número exacto de factura",
        },
      },
      required: [
        "cliente",
        "estado",
        "fecha_inicio",
        "fecha_fin",
        "numero_factura",
      ],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_inventario",
    description:
      "Consulta stock actual de materiales o productos. Puede buscar por nombre o categoría. Retorna nombre, cantidad en stock, unidad y precio promedio.",
    parameters: {
      type: "object",
      properties: {
        busqueda: {
          type: ["string", "null"],
          description: "Nombre del material o producto",
        },
        categoria: {
          type: ["string", "null"],
          description: "Categoría: aceros, tornilleria, pinturas, electricos, etc.",
        },
        solo_bajo_stock: {
          type: ["boolean", "null"],
          description: "true para mostrar solo items con stock bajo mínimo",
        },
      },
      required: ["busqueda", "categoria", "solo_bajo_stock"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_caja_diaria",
    description:
      "Obtiene el resumen de caja del día actual o de una fecha específica. Retorna ingresos, egresos, saldo, y lista de movimientos.",
    parameters: {
      type: "object",
      properties: {
        fecha: {
          type: ["string", "null"],
          description:
            "Fecha YYYY-MM-DD. null = hoy. Puede ser 'semana' o 'mes' para resumen del período.",
        },
      },
      required: ["fecha"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_cuentas_por_cobrar",
    description:
      "Lista facturas pendientes de pago (cuentas por cobrar). Puede filtrar por cliente. Retorna facturas con montos, días de vencimiento y total adeudado.",
    parameters: {
      type: "object",
      properties: {
        cliente: {
          type: ["string", "null"],
          description: "Filtrar por nombre de cliente. null = todos",
        },
      },
      required: ["cliente"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_cotizaciones",
    description:
      "Busca cotizaciones por cliente, estado o fecha. Retorna número, cliente, items, total y estado.",
    parameters: {
      type: "object",
      properties: {
        cliente: {
          type: ["string", "null"],
          description: "Nombre del cliente",
        },
        estado: {
          type: ["string", "null"],
          enum: ["Borrador", "Enviada", "Aprobada", "Rechazada", "Vencida", "Anulada", null],
          description: "Estado de la cotización (primera letra mayúscula)",
        },
      },
      required: ["cliente", "estado"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "resumen_ejecutivo",
    description:
      "Genera un resumen ejecutivo del negocio: ventas del mes, gastos, utilidad, cuentas por cobrar totales, inventario crítico. Ideal para preguntas como '¿Cómo va el negocio?'",
    parameters: {
      type: "object",
      properties: {
        periodo: {
          type: ["string", "null"],
          description:
            "Período: 'hoy', 'semana', 'mes', 'año', o YYYY-MM. null = mes actual",
        },
      },
      required: ["periodo"],
      additionalProperties: false,
    },
    strict: true,
  },
  // === ACCIONES DE ESCRITURA ===
  {
    type: "function",
    name: "crear_factura",
    description:
      "Crea una nueva factura de venta. IMPORTANTE: Siempre confirmar los datos con el usuario antes de ejecutar esta función. Necesita cliente e items con descripción, cantidad y precio.",
    parameters: {
      type: "object",
      properties: {
        cliente_nombre: {
          type: "string",
          description: "Nombre exacto del cliente (debe existir en la BD)",
        },
        items: {
          type: "array",
          description: "Lista de items de la factura",
          items: {
            type: "object",
            properties: {
              descripcion: {
                type: "string",
                description: "Descripción del producto o servicio",
              },
              cantidad: { type: "number", description: "Cantidad" },
              precio_unitario: {
                type: "number",
                description: "Precio unitario en COP sin IVA",
              },
              iva_porcentaje: {
                type: "number",
                description: "Porcentaje de IVA (generalmente 19)",
              },
            },
            required: [
              "descripcion",
              "cantidad",
              "precio_unitario",
              "iva_porcentaje",
            ],
            additionalProperties: false,
          },
        },
        notas: {
          type: ["string", "null"],
          description: "Notas o observaciones para la factura",
        },
      },
      required: ["cliente_nombre", "items", "notas"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "registrar_pago",
    description:
      "Registra un pago contra una factura pendiente. Requiere número de factura, monto y método de pago.",
    parameters: {
      type: "object",
      properties: {
        factura_numero: {
          type: "string",
          description: "Número de la factura (ej: FV-0234)",
        },
        monto: {
          type: "number",
          description: "Monto del pago en COP",
        },
        metodo_pago: {
          type: "string",
          enum: ["cash", "card", "transfer", "credit", "check"],
          description: "Método de pago: cash=efectivo, card=tarjeta, transfer=transferencia, credit=crédito, check=cheque",
        },
      },
      required: ["factura_numero", "monto", "metodo_pago"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "registrar_gasto",
    description:
      "Registra un gasto o egreso en la caja diaria. Requiere concepto, monto y categoría.",
    parameters: {
      type: "object",
      properties: {
        concepto: {
          type: "string",
          description: "Descripción del gasto",
        },
        monto: {
          type: "number",
          description: "Monto del gasto en COP",
        },
        categoria: {
          type: "string",
          description:
            "Categoría: materiales, servicios, nomina, transporte, herramientas, otros",
        },
        proveedor: {
          type: ["string", "null"],
          description: "Nombre del proveedor si aplica",
        },
      },
      required: ["concepto", "monto", "categoria", "proveedor"],
      additionalProperties: false,
    },
    strict: true,
  },
  // === ANALYTICS & REPORTES ===
  {
    type: "function",
    name: "consultar_salud_negocio",
    description:
      "Obtiene el snapshot de salud del negocio: health score, ingresos últimos 30 días, total CxC, inventario, facturas vencidas, DSO, CEI. Ideal para '¿Cómo va el negocio?' o 'Dame el estado general'.",
    parameters: {
      type: "object",
      properties: {
        detalle: {
          type: ["string", "null"],
          description: "null = snapshot completo. 'cobranzas' = KPIs de cobranza. 'inventario' = KPIs de inventario.",
        },
      },
      required: ["detalle"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_pyg_mensual",
    description:
      "Obtiene el estado de Pérdidas y Ganancias (P&L) mensual. Retorna ingresos, gastos fijos, gastos variables y utilidad bruta por mes. Ideal para '¿Cuánto ganamos este mes?' o 'Muéstrame la rentabilidad'.",
    parameters: {
      type: "object",
      properties: {
        meses: {
          type: ["number", "null"],
          description: "Cantidad de meses a consultar (default 6, máximo 12)",
        },
      },
      required: ["meses"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_top_productos",
    description:
      "Lista los productos más vendidos con ingresos totales, cantidad vendida y precio promedio. Incluye clasificación ABC (Pareto 80/20).",
    parameters: {
      type: "object",
      properties: {
        limite: {
          type: ["number", "null"],
          description: "Cantidad de productos a mostrar (default 10)",
        },
        incluir_abc: {
          type: ["boolean", "null"],
          description: "true para incluir clasificación ABC Pareto",
        },
      },
      required: ["limite", "incluir_abc"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_deudores",
    description:
      "Lista los principales deudores con monto adeudado, días de mora, nivel de riesgo y antigüedad. También muestra el aging de CxC por buckets.",
    parameters: {
      type: "object",
      properties: {
        tipo: {
          type: "string",
          enum: ["top_deudores", "aging_summary"],
          description: "top_deudores = lista de clientes morosos. aging_summary = resumen por antigüedad (corriente, 1-30, 31-60, 61-90, 90+ días).",
        },
      },
      required: ["tipo"],
      additionalProperties: false,
    },
    strict: true,
  },
  {
    type: "function",
    name: "consultar_eficiencia_materiales",
    description:
      "Analiza la eficiencia del inventario de materiales: días de stock restante, tasa de consumo diaria, valor en stock, estado de reorden. Ideal para '¿Cuánto nos queda de acero?' o 'Eficiencia de materia prima'.",
    parameters: {
      type: "object",
      properties: {
        material: {
          type: ["string", "null"],
          description: "Nombre del material a consultar. null = todos los materiales.",
        },
        solo_criticos: {
          type: ["boolean", "null"],
          description: "true para mostrar solo materiales con stock crítico (menos de 15 días).",
        },
      },
      required: ["material", "solo_criticos"],
      additionalProperties: false,
    },
    strict: true,
  },
];

// ─── Function Implementations ──────────────────────────

async function executeFunction(
  name: string,
  args: Record<string, unknown>,
  supabase: ReturnType<typeof createClient>
): Promise<string> {
  try {
    switch (name) {
      case "consultar_clientes":
        return await consultarClientes(supabase, args);
      case "consultar_proveedores":
        return await consultarProveedores(supabase, args);
      case "consultar_facturas":
        return await consultarFacturas(supabase, args);
      case "consultar_inventario":
        return await consultarInventario(supabase, args);
      case "consultar_caja_diaria":
        return await consultarCajaDiaria(supabase, args);
      case "consultar_cuentas_por_cobrar":
        return await consultarCuentasPorCobrar(supabase, args);
      case "consultar_cotizaciones":
        return await consultarCotizaciones(supabase, args);
      case "resumen_ejecutivo":
        return await resumenEjecutivo(supabase, args);
      case "crear_factura":
        return await crearFactura(supabase, args);
      case "registrar_pago":
        return await registrarPago(supabase, args);
      case "registrar_gasto":
        return await registrarGasto(supabase, args);
      case "consultar_salud_negocio":
        return await consultarSaludNegocio(supabase, args);
      case "consultar_pyg_mensual":
        return await consultarPyGMensual(supabase, args);
      case "consultar_top_productos":
        return await consultarTopProductos(supabase, args);
      case "consultar_deudores":
        return await consultarDeudores(supabase, args);
      case "consultar_eficiencia_materiales":
        return await consultarEficienciaMateriales(supabase, args);
      default:
        return JSON.stringify({ error: `Función desconocida: ${name}` });
    }
  } catch (err) {
    console.error(`Error ejecutando ${name}:`, err);
    return JSON.stringify({
      error: `Error al ejecutar ${name}: ${(err as Error).message}`,
    });
  }
}

// ─── Query Functions ───────────────────────────────────

async function consultarClientes(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  const busqueda = (args.busqueda as string).toLowerCase();
  const { data, error } = await sb
    .from("customers")
    .select("id, name, document_number, phone, email, address")
    .or(
      `name.ilike.%${busqueda}%,document_number.ilike.%${busqueda}%,phone.ilike.%${busqueda}%`
    )
    .limit(10);

  if (error) return JSON.stringify({ error: error.message });
  if (!data || data.length === 0)
    return JSON.stringify({
      mensaje: `No se encontraron clientes con "${args.busqueda}"`,
    });

  return JSON.stringify({ clientes: data, total: data.length });
}

async function consultarProveedores(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  const busqueda = (args.busqueda as string).toLowerCase();
  const { data, error } = await sb
    .from("suppliers")
    .select("id, name, document_number, phone, email, contact_person")
    .or(
      `name.ilike.%${busqueda}%,document_number.ilike.%${busqueda}%`
    )
    .limit(10);

  if (error) return JSON.stringify({ error: error.message });
  if (!data || data.length === 0)
    return JSON.stringify({
      mensaje: `No se encontraron proveedores con "${args.busqueda}"`,
    });

  return JSON.stringify({ proveedores: data, total: data.length });
}

async function consultarFacturas(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  // Build filter conditions
  const filters: Record<string, unknown> = {};
  if (args.cliente) filters.cliente = args.cliente;
  if (args.estado) filters.estado = args.estado;
  if (args.fecha_inicio) filters.fecha_inicio = args.fecha_inicio;
  if (args.fecha_fin) filters.fecha_fin = args.fecha_fin;
  if (args.numero_factura) filters.numero_factura = args.numero_factura;

  // First: get accurate totals (no limit)
  let countQuery = sb
    .from("invoices")
    .select("total, paid_amount");

  if (args.cliente)
    countQuery = countQuery.ilike("customer_name", `%${args.cliente}%`);
  if (args.estado) countQuery = countQuery.eq("status", args.estado);
  if (args.fecha_inicio)
    countQuery = countQuery.gte("issue_date", args.fecha_inicio as string);
  if (args.fecha_fin)
    countQuery = countQuery.lte("issue_date", args.fecha_fin as string);
  if (args.numero_factura)
    countQuery = countQuery.eq("full_number", args.numero_factura as string);

  const { data: allData } = await countQuery;

  // Second: get detail list (limited for display)
  let query = sb
    .from("invoices")
    .select(
      "id, full_number, customer_name, total, status, issue_date, due_date, paid_amount"
    )
    .order("issue_date", { ascending: false })
    .limit(20);

  if (args.cliente)
    query = query.ilike("customer_name", `%${args.cliente}%`);
  if (args.estado) query = query.eq("status", args.estado);
  if (args.fecha_inicio)
    query = query.gte("issue_date", args.fecha_inicio as string);
  if (args.fecha_fin)
    query = query.lte("issue_date", args.fecha_fin as string);
  if (args.numero_factura)
    query = query.eq("full_number", args.numero_factura as string);

  const { data, error } = await query;
  if (error) return JSON.stringify({ error: error.message });
  if (!data || data.length === 0)
    return JSON.stringify({ mensaje: "No se encontraron facturas con esos criterios" });

  const totalMonto = (allData || []).reduce(
    (sum: number, f: Record<string, unknown>) => sum + ((f.total as number) || 0),
    0
  );
  const totalRegistros = (allData || []).length;

  return JSON.stringify({
    facturas: data,
    total_registros: totalRegistros,
    suma_total: totalMonto,
    mostrando: data.length,
    nota: totalRegistros > 20 ? `Mostrando 20 de ${totalRegistros} facturas` : undefined,
  });
}

async function consultarInventario(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  // If searching by specific term, try exact first then fuzzy
  if (args.busqueda && !args.categoria && !args.solo_bajo_stock) {
    // Try exact ILIKE first
    const { data: exactData } = await sb
      .from("materials")
      .select("id, name, category, stock, min_stock, unit, cost_price")
      .ilike("name", `%${args.busqueda}%`)
      .order("name")
      .limit(20);

    if (exactData && exactData.length > 0) {
      return JSON.stringify({ materiales: exactData, total: exactData.length });
    }

    // No exact match — use fuzzy search (pg_trgm + normalization)
    const { data: fuzzyData, error: fuzzyError } = await sb
      .rpc("buscar_material_fuzzy", { termino_busqueda: args.busqueda as string });

    if (fuzzyError) return JSON.stringify({ error: fuzzyError.message });

    if (fuzzyData && fuzzyData.length > 0) {
      // Return as suggestions for user to pick
      return JSON.stringify({
        mensaje: `No encontré "${args.busqueda}" exactamente, pero encontré materiales similares:`,
        materiales_similares: fuzzyData.map((m: Record<string, unknown>) => ({
          nombre: m.nombre,
          stock: m.stock,
          unidad: m.unidad,
          similitud: m.similitud,
        })),
        total: fuzzyData.length,
        instruccion: "Presenta estas opciones al usuario con viñetas (•) para que elija el material correcto.",
      });
    }

    return JSON.stringify({ mensaje: `No se encontraron materiales parecidos a "${args.busqueda}"` });
  }

  // General query (category filter, low stock, etc.)
  let query = sb
    .from("materials")
    .select("id, name, category, stock, min_stock, unit, cost_price")
    .order("name");

  if (args.busqueda)
    query = query.ilike("name", `%${args.busqueda}%`);
  if (args.categoria)
    query = query.ilike("category", `%${args.categoria}%`);
  if (args.solo_bajo_stock)
    query = query.filter("stock", "lt", "min_stock");

  query = query.limit(20);
  const { data, error } = await query;
  if (error) return JSON.stringify({ error: error.message });
  if (!data || data.length === 0)
    return JSON.stringify({ mensaje: "No se encontraron materiales con esos criterios" });

  return JSON.stringify({ materiales: data, total: data.length });
}

async function consultarCajaDiaria(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  const fecha = (args.fecha as string) || new Date().toISOString().split("T")[0];

  if (fecha === "semana" || fecha === "mes") {
    const now = new Date();
    let desde: string;
    if (fecha === "semana") {
      const d = new Date(now);
      d.setDate(d.getDate() - 7);
      desde = d.toISOString().split("T")[0];
    } else {
      desde = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-01`;
    }
    const hasta = now.toISOString().split("T")[0];

    const { data, error } = await sb
      .from("cash_movements")
      .select("id, type, amount, description, category, date")
      .gte("date", desde)
      .lte("date", hasta + "T23:59:59")
      .order("date", { ascending: false });

    if (error) return JSON.stringify({ error: error.message });

    const ingresos = (data || [])
      .filter((m: Record<string, unknown>) => m.type === "income")
      .reduce((s: number, m: Record<string, unknown>) => s + ((m.amount as number) || 0), 0);
    const egresos = (data || [])
      .filter((m: Record<string, unknown>) => m.type === "expense")
      .reduce((s: number, m: Record<string, unknown>) => s + ((m.amount as number) || 0), 0);

    return JSON.stringify({
      periodo: `${desde} a ${hasta}`,
      total_ingresos: ingresos,
      total_egresos: egresos,
      saldo: ingresos - egresos,
      total_movimientos: (data || []).length,
    });
  }

  // Día específico
  const { data, error } = await sb
    .from("cash_movements")
    .select("id, type, amount, description, category, date")
    .gte("date", fecha + "T00:00:00")
    .lte("date", fecha + "T23:59:59")
    .order("date", { ascending: false });

  if (error) return JSON.stringify({ error: error.message });

  const ingresos = (data || [])
    .filter((m: Record<string, unknown>) => m.type === "income")
    .reduce((s: number, m: Record<string, unknown>) => s + ((m.amount as number) || 0), 0);
  const egresos = (data || [])
    .filter((m: Record<string, unknown>) => m.type === "expense")
    .reduce((s: number, m: Record<string, unknown>) => s + ((m.amount as number) || 0), 0);

  return JSON.stringify({
    fecha,
    total_ingresos: ingresos,
    total_egresos: egresos,
    saldo: ingresos - egresos,
    movimientos: (data || []).slice(0, 10),
    total_movimientos: (data || []).length,
  });
}

async function consultarCuentasPorCobrar(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  // Query ALL pending invoices for accurate totals (no limit)
  let allQuery = sb
    .from("invoices")
    .select("total, paid_amount")
    .in("status", ["issued", "partial", "overdue"]);

  if (args.cliente)
    allQuery = allQuery.ilike("customer_name", `%${args.cliente}%`);

  const { data: allData, error: allError } = await allQuery;
  if (allError) return JSON.stringify({ error: allError.message });
  if (!allData || allData.length === 0)
    return JSON.stringify({
      mensaje: args.cliente
        ? `No hay cuentas por cobrar para "${args.cliente}"`
        : "No hay cuentas por cobrar pendientes",
    });

  const totalDeuda = allData.reduce(
    (s: number, f: Record<string, unknown>) =>
      s + ((f.total as number) || 0) - ((f.paid_amount as number) || 0),
    0
  );
  const totalFacturado = allData.reduce(
    (s: number, f: Record<string, unknown>) => s + ((f.total as number) || 0),
    0
  );

  // Get detail list (limited to 20 for display)
  let detailQuery = sb
    .from("invoices")
    .select(
      "id, full_number, customer_name, total, paid_amount, status, issue_date, due_date"
    )
    .in("status", ["issued", "partial", "overdue"])
    .order("due_date", { ascending: true })
    .limit(20);

  if (args.cliente)
    detailQuery = detailQuery.ilike("customer_name", `%${args.cliente}%`);

  const { data } = await detailQuery;

  return JSON.stringify({
    cuentas_por_cobrar: data || [],
    total_pendiente: totalDeuda,
    total_facturado: totalFacturado,
    cantidad_facturas: allData.length,
    mostrando: (data || []).length,
    nota: allData.length > 20 ? `Mostrando 20 de ${allData.length} facturas pendientes` : undefined,
  });
}

async function consultarCotizaciones(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  let query = sb
    .from("quotations")
    .select("id, number, customer_name, total, status, created_at, valid_until")
    .order("created_at", { ascending: false })
    .limit(15);

  if (args.cliente)
    query = query.ilike("customer_name", `%${args.cliente}%`);
  if (args.estado) query = query.eq("status", args.estado);

  const { data, error } = await query;
  if (error) return JSON.stringify({ error: error.message });
  if (!data || data.length === 0)
    return JSON.stringify({ mensaje: "No se encontraron cotizaciones" });

  return JSON.stringify({ cotizaciones: data, total: data.length });
}

async function resumenEjecutivo(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  const now = new Date();
  let desde: string;
  let hasta: string = now.toISOString().split("T")[0];
  const periodo = (args.periodo as string) || "mes";

  switch (periodo) {
    case "hoy":
      desde = hasta;
      break;
    case "semana": {
      const d = new Date(now);
      d.setDate(d.getDate() - 7);
      desde = d.toISOString().split("T")[0];
      break;
    }
    case "año": {
      desde = `${now.getFullYear()}-01-01`;
      break;
    }
    default: // mes
      desde = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-01`;
  }

  // Ventas del período
  const { data: facturas } = await sb
    .from("invoices")
    .select("total, paid_amount, status")
    .gte("issue_date", desde)
    .lte("issue_date", hasta);

  const totalVentas = (facturas || []).reduce(
    (s: number, f: Record<string, unknown>) => s + ((f.total as number) || 0),
    0
  );
  const totalCobrado = (facturas || []).reduce(
    (s: number, f: Record<string, unknown>) => s + ((f.paid_amount as number) || 0),
    0
  );

  // CxC total
  const { data: pendientes } = await sb
    .from("invoices")
    .select("total, paid_amount")
    .in("status", ["issued", "partial", "overdue"]);

  const totalCxC = (pendientes || []).reduce(
    (s: number, f: Record<string, unknown>) =>
      s + ((f.total as number) || 0) - ((f.paid_amount as number) || 0),
    0
  );

  // Gastos del período
  const { data: gastos } = await sb
    .from("cash_movements")
    .select("amount, type")
    .eq("type", "expense")
    .gte("date", desde)
    .lte("date", hasta + "T23:59:59");

  const totalGastos = (gastos || []).reduce(
    (s: number, g: Record<string, unknown>) => s + ((g.amount as number) || 0),
    0
  );

  // Materiales bajo stock
  const { data: bajoStock } = await sb
    .from("materials")
    .select("name, stock, min_stock")
    .filter("stock", "lt", "min_stock")
    .limit(5);

  return JSON.stringify({
    periodo: `${desde} a ${hasta}`,
    ventas_totales: totalVentas,
    cobrado: totalCobrado,
    cuentas_por_cobrar: totalCxC,
    gastos_totales: totalGastos,
    utilidad_bruta: totalVentas - totalGastos,
    facturas_emitidas: (facturas || []).length,
    materiales_bajo_stock: bajoStock || [],
  });
}

// ─── Write Functions ───────────────────────────────────

async function crearFactura(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  // 1. Buscar cliente
  const { data: clientes } = await sb
    .from("customers")
    .select("id, name, document_number")
    .ilike("name", `%${args.cliente_nombre}%`)
    .limit(1);

  if (!clientes || clientes.length === 0) {
    return JSON.stringify({
      error: `No se encontró el cliente "${args.cliente_nombre}". Verifica el nombre.`,
    });
  }

  const cliente = clientes[0];
  const items = args.items as Array<Record<string, unknown>>;

  // 2. Calcular totales
  let subtotal = 0;
  let totalIva = 0;
  const itemsProcessed = items.map((item) => {
    const sub = (item.cantidad as number) * (item.precio_unitario as number);
    const iva = sub * ((item.iva_porcentaje as number) / 100);
    subtotal += sub;
    totalIva += iva;
    return {
      description: item.descripcion,
      quantity: item.cantidad,
      unit_price: item.precio_unitario,
      tax_rate: item.iva_porcentaje,
      tax_amount: iva,
      subtotal: sub,
      total: sub + iva,
    };
  });

  const total = subtotal + totalIva;

  // 3. Generar número de factura
  const { data: lastInvoice } = await sb
    .from("invoices")
    .select("full_number")
    .like("full_number", "FV-%")
    .order("created_at", { ascending: false })
    .limit(1);

  let nextNum = 1;
  if (lastInvoice && lastInvoice.length > 0) {
    const match = (lastInvoice[0].full_number as string).match(/\d+/);
    if (match) nextNum = parseInt(match[0]) + 1;
  }
  const invoiceSeries = "FV";
  const invoiceNum = String(nextNum).padStart(4, "0");

  // 4. Insertar factura
  const { data: invoice, error } = await sb
    .from("invoices")
    .insert({
      type: "invoice",
      series: invoiceSeries,
      number: invoiceNum,
      customer_id: cliente.id,
      customer_name: cliente.name,
      subtotal,
      tax_amount: totalIva,
      total: total,
      paid_amount: 0,
      status: "issued",
      issue_date: new Date().toISOString().split("T")[0],
      notes: args.notas || null,
    })
    .select()
    .single();

  if (error) return JSON.stringify({ error: `Error creando factura: ${error.message}` });

  // 5. Insertar items
  for (const item of itemsProcessed) {
    await sb.from("invoice_items").insert({
      invoice_id: invoice.id,
      ...item,
    });
  }

  return JSON.stringify({
    exito: true,
    factura_numero: `${invoiceSeries}-${invoiceNum}`,
    cliente: cliente.name,
    subtotal,
    iva: totalIva,
    total,
    items_count: items.length,
    mensaje: `Factura ${invoiceSeries}-${invoiceNum} creada exitosamente por $${total.toLocaleString("es-CO")}`,
  });
}

async function registrarPago(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  // Buscar factura
  const { data: facturas } = await sb
    .from("invoices")
    .select("id, full_number, customer_name, total, paid_amount, status")
    .eq("full_number", args.factura_numero as string)
    .limit(1);

  if (!facturas || facturas.length === 0) {
    return JSON.stringify({
      error: `No se encontró la factura "${args.factura_numero}"`,
    });
  }

  const factura = facturas[0];
  const saldoPendiente =
    (factura.total as number) - (factura.paid_amount as number);
  const monto = args.monto as number;

  if (monto > saldoPendiente) {
    return JSON.stringify({
      error: `El monto ($${monto.toLocaleString("es-CO")}) excede el saldo pendiente ($${saldoPendiente.toLocaleString("es-CO")})`,
    });
  }

  const nuevoPagado = (factura.paid_amount as number) + monto;
  const nuevoEstado = nuevoPagado >= (factura.total as number) ? "paid" : "partial";

  const { error } = await sb
    .from("invoices")
    .update({ paid_amount: nuevoPagado, status: nuevoEstado })
    .eq("id", factura.id);

  if (error) return JSON.stringify({ error: `Error registrando pago: ${error.message}` });

  // Obtener cuenta Caja para el movimiento
  const { data: cuentaCaja } = await sb
    .from("accounts")
    .select("id")
    .eq("name", "Caja")
    .limit(1);

  const accountId = cuentaCaja?.[0]?.id;

  // Registrar movimiento de caja
  if (accountId) {
    await sb.from("cash_movements").insert({
      account_id: accountId,
      type: "income",
      amount: monto,
      description: `Pago factura ${args.factura_numero} - ${factura.customer_name}`,
      category: "ventas",
      date: new Date().toISOString(),
    });
  }

  return JSON.stringify({
    exito: true,
    factura: args.factura_numero,
    monto_pagado: monto,
    nuevo_estado: nuevoEstado,
    saldo_restante: (factura.total as number) - nuevoPagado,
    mensaje: `Pago de $${monto.toLocaleString("es-CO")} registrado en ${args.factura_numero}. Estado: ${nuevoEstado === "paid" ? "pagada" : "pago parcial"}`,
  });
}

async function registrarGasto(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  // Obtener cuenta Caja para el movimiento
  const { data: cuentaCaja } = await sb
    .from("accounts")
    .select("id")
    .eq("name", "Caja")
    .limit(1);

  const accountId = cuentaCaja?.[0]?.id;
  if (!accountId) {
    return JSON.stringify({ error: "No se encontró la cuenta Caja" });
  }

  const desc = args.proveedor
    ? `${args.concepto} | Proveedor: ${args.proveedor}`
    : (args.concepto as string);

  const { data, error } = await sb
    .from("cash_movements")
    .insert({
      account_id: accountId,
      type: "expense",
      amount: args.monto,
      description: desc,
      category: args.categoria,
      date: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) return JSON.stringify({ error: `Error registrando gasto: ${error.message}` });

  return JSON.stringify({
    exito: true,
    id: data.id,
    concepto: args.concepto,
    monto: args.monto,
    categoria: args.categoria,
    mensaje: `Gasto registrado: "${args.concepto}" por $${(args.monto as number).toLocaleString("es-CO")}`,
  });
}

// ─── Analytics Functions ───────────────────────────────

async function consultarSaludNegocio(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  const detalle = args.detalle as string | null;

  // Snapshot general de salud del negocio
  const { data: snapshot, error: snapError } = await sb
    .from("v_business_health_snapshot")
    .select("*")
    .limit(1)
    .single();

  if (snapError) return JSON.stringify({ error: snapError.message });

  if (detalle === "cobranzas") {
    // KPIs de cobranza adicionales
    const { data: kpis } = await sb
      .from("v_receivables_kpis")
      .select("*")
      .limit(1)
      .single();

    return JSON.stringify({
      salud_negocio: {
        health_score: snapshot.health_score,
        total_por_cobrar: snapshot.total_receivables,
        facturas_vencidas: snapshot.overdue_count,
        monto_vencido: snapshot.overdue_amount,
      },
      kpis_cobranza: kpis || {},
      seccion_app: "Reportes y Analytics → pestaña Cobranzas y Mora",
    });
  }

  if (detalle === "inventario") {
    return JSON.stringify({
      inventario: {
        valor_total_inventario: snapshot.total_inventory_value,
        valor_materiales: snapshot.material_inventory_value,
        valor_productos: snapshot.product_inventory_value,
        materiales_bajo_stock: snapshot.low_stock_materials,
        materiales_agotados: snapshot.out_of_stock_materials,
        productos_bajo_stock: snapshot.low_stock_products,
        inventario_vs_ingresos_pct: snapshot.inventory_to_revenue_pct,
      },
      seccion_app: "Reportes y Analytics → pestaña Inventario",
    });
  }

  // Snapshot completo
  return JSON.stringify({
    salud_negocio: {
      health_score: snapshot.health_score,
      ingresos_30_dias: snapshot.revenue_last_30d,
      cobrado_30_dias: snapshot.collected_last_30d,
      facturas_30_dias: snapshot.invoices_30d,
      ticket_promedio: snapshot.avg_invoice_value,
      total_ingresos_historico: snapshot.total_revenue,
      total_cobrado_historico: snapshot.total_collected,
      total_facturas: snapshot.total_invoices,
    },
    cuentas_por_cobrar: {
      total: snapshot.total_receivables,
      vencidas: snapshot.overdue_amount,
      cantidad_vencidas: snapshot.overdue_count,
      cxc_vs_ingresos_pct: snapshot.receivables_to_revenue_pct,
    },
    inventario: {
      valor_total: snapshot.total_inventory_value,
      materiales_bajo_stock: snapshot.low_stock_materials,
      materiales_agotados: snapshot.out_of_stock_materials,
    },
    credito: {
      limite_total: snapshot.total_credit_limit,
      credito_usado: snapshot.total_credit_used,
      utilizacion_pct: snapshot.credit_utilization_pct,
    },
    seccion_app: "Reportes y Analytics → pestaña Analytics",
  });
}

async function consultarPyGMensual(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  const meses = Math.min((args.meses as number) || 6, 12);

  const { data, error } = await sb
    .from("v_profit_loss_monthly")
    .select("year, month, revenue, fixed_expenses, variable_expenses, gross_profit")
    .order("year", { ascending: false })
    .order("month", { ascending: false })
    .limit(meses);

  if (error) return JSON.stringify({ error: error.message });
  if (!data || data.length === 0)
    return JSON.stringify({ mensaje: "No hay datos de P&L disponibles" });

  const totalRevenue = data.reduce((s: number, r: Record<string, unknown>) => s + ((r.revenue as number) || 0), 0);
  const totalProfit = data.reduce((s: number, r: Record<string, unknown>) => s + ((r.gross_profit as number) || 0), 0);

  return JSON.stringify({
    pyg_mensual: data.reverse(),
    resumen: {
      periodo_meses: data.length,
      ingresos_totales: totalRevenue,
      utilidad_total: totalProfit,
      margen_promedio_pct: totalRevenue > 0 ? ((totalProfit / totalRevenue) * 100).toFixed(1) : 0,
    },
    seccion_app: "Reportes y Analytics → pestaña Analytics → tabla P&L mensual",
  });
}

async function consultarTopProductos(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  const limite = (args.limite as number) || 10;

  const { data: topProducts, error } = await sb
    .from("v_top_selling_products")
    .select("product_name, product_code, total_revenue, total_quantity, times_sold, avg_price")
    .order("total_revenue", { ascending: false })
    .limit(limite);

  if (error) return JSON.stringify({ error: error.message });

  const result: Record<string, unknown> = {
    top_productos: topProducts || [],
    total_mostrados: (topProducts || []).length,
  };

  if (args.incluir_abc) {
    const { data: abc } = await sb
      .from("v_inventory_abc_analysis")
      .select("product_name, abc_category, total_revenue, cumulative_percentage, recommendation")
      .order("rank")
      .limit(20);

    result.clasificacion_abc = abc || [];
    result.nota_abc = "A = 80% ingresos (prioridad alta), B = 15% (media), C = 5% (baja)";
  }

  result.seccion_app = "Reportes y Analytics → pestaña Analytics → Análisis ABC Pareto y Top Productos";
  return JSON.stringify(result);
}

async function consultarDeudores(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  if (args.tipo === "aging_summary") {
    const { data, error } = await sb
      .from("v_receivables_aging_summary")
      .select("aging_label, num_invoices, num_customers, pending_amount, avg_days_overdue, avg_pending")
      .order("aging_bucket");

    if (error) return JSON.stringify({ error: error.message });

    const totalPending = (data || []).reduce(
      (s: number, r: Record<string, unknown>) => s + ((r.pending_amount as number) || 0), 0
    );

    return JSON.stringify({
      aging_cuentas_por_cobrar: data || [],
      total_pendiente: totalPending,
      seccion_app: "Reportes y Analytics → pestaña Cobranzas → Aging CxC",
    });
  }

  // top_deudores
  const { data, error } = await sb
    .from("v_top_debtors")
    .select("customer_name, document_number, phone, total_debt, pending_invoices, avg_days_overdue, max_days_overdue, risk_level, oldest_due_date")
    .order("total_debt", { ascending: false })
    .limit(15);

  if (error) return JSON.stringify({ error: error.message });

  const totalDeuda = (data || []).reduce(
    (s: number, r: Record<string, unknown>) => s + ((r.total_debt as number) || 0), 0
  );

  return JSON.stringify({
    top_deudores: data || [],
    total_deuda: totalDeuda,
    cantidad_deudores: (data || []).length,
    seccion_app: "Reportes y Analytics → pestaña Mora → Top Deudores",
  });
}

async function consultarEficienciaMateriales(
  sb: ReturnType<typeof createClient>,
  args: Record<string, unknown>
): Promise<string> {
  let query = sb
    .from("v_material_efficiency")
    .select("material_name, material_code, category, current_stock, unit, unit_cost, stock_value, daily_consumption_rate, days_of_stock_remaining, consumed_90_days, received_90_days, reorder_status")
    .order("days_of_stock_remaining", { ascending: true });

  if (args.material)
    query = query.ilike("material_name", `%${args.material}%`);

  if (args.solo_criticos)
    query = query.lt("days_of_stock_remaining", 15);

  const { data, error } = await query.limit(20);
  if (error) return JSON.stringify({ error: error.message });
  if (!data || data.length === 0)
    return JSON.stringify({ mensaje: "No hay datos de eficiencia de materiales" });

  const valorTotal = data.reduce(
    (s: number, r: Record<string, unknown>) => s + ((r.stock_value as number) || 0), 0
  );

  return JSON.stringify({
    eficiencia_materiales: data,
    valor_total_stock: valorTotal,
    total_materiales: data.length,
    seccion_app: "Reportes y Analytics → pestaña Analytics → Eficiencia Materiales. También en Materiales para gestión directa.",
  });
}

// ─── Audio Transcription ───────────────────────────────

async function transcribeAudio(audioBase64: string): Promise<string> {
  // Decodificar base64 a bytes
  const binaryStr = atob(audioBase64);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }

  // Crear FormData con el archivo de audio
  const formData = new FormData();
  formData.append("file", new Blob([bytes], { type: "audio/wav" }), "audio.wav");
  formData.append("model", "whisper-1");
  formData.append("language", "es");

  const response = await fetch(
    "https://api.openai.com/v1/audio/transcriptions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: formData,
    }
  );

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Whisper API error: ${err}`);
  }

  const result = await response.json();
  return result.text;
}

// ─── Main OpenAI Chat Call ─────────────────────────────

async function callOpenAI(
  messages: Array<Record<string, unknown>>,
  maxIterations = 5
): Promise<string> {
  let currentMessages = [...messages];
  let iterations = 0;

  while (iterations < maxIterations) {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        messages: currentMessages,
        tools: tools.map((t) => ({ type: "function", function: { name: t.name, description: t.description, parameters: t.parameters, strict: t.strict } })),
        tool_choice: "auto",
        temperature: 0.3,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      throw new Error(`OpenAI API error: ${response.status} ${err}`);
    }

    const data = await response.json();
    const choice = data.choices[0];
    const message = choice.message;

    // Si no hay tool calls, retornar la respuesta de texto
    if (!message.tool_calls || message.tool_calls.length === 0) {
      return message.content || "No pude generar una respuesta.";
    }

    // Hay tool calls — ejecutarlas
    currentMessages.push(message);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    for (const toolCall of message.tool_calls) {
      const fnName = toolCall.function.name;
      const fnArgs = JSON.parse(toolCall.function.arguments);
      console.log(`Ejecutando función: ${fnName}`, fnArgs);

      const result = await executeFunction(fnName, fnArgs, supabase);

      currentMessages.push({
        role: "tool",
        tool_call_id: toolCall.id,
        content: result,
      });
    }

    iterations++;
  }

  return "Se alcanzó el límite de iteraciones. Intenta simplificar tu pregunta.";
}

// ─── Main Handler ──────────────────────────────────────

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!OPENAI_API_KEY) {
      throw new Error("OPENAI_API_KEY no configurada");
    }

    const body = await req.json();
    const {
      message,
      audio_base64,
      conversation_history = [],
    } = body;

    let userMessage = message || "";

    // 1. Si hay audio, transcribir
    if (audio_base64 && !userMessage) {
      userMessage = await transcribeAudio(audio_base64);
    }

    if (!userMessage || userMessage.trim() === "") {
      return new Response(
        JSON.stringify({ error: "No se proporcionó mensaje ni audio" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Construir mensajes para OpenAI
    const messages: Array<Record<string, unknown>> = [
      { role: "system", content: SYSTEM_PROMPT },
      ...conversation_history.slice(-20), // Últimos 20 mensajes de contexto
      { role: "user", content: userMessage },
    ];

    // 3. Llamar OpenAI con function calling
    const responseText = await callOpenAI(messages);

    // 4. Retornar respuesta
    return new Response(
      JSON.stringify({
        response: responseText,
        transcription: audio_base64 ? userMessage : undefined,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Error en ai-assistant:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
