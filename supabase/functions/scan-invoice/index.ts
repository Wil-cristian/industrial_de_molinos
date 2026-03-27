// =====================================================
// SUPABASE EDGE FUNCTION: scan-invoice
// =====================================================
// Recibe una imagen de factura (URL o base64) y usa
// OpenAI Vision (GPT-4.1-mini) para extraer datos estructurados.
//
// POST /functions/v1/scan-invoice
// Body: { "image_url": "https://..." } o { "image_base64": "data:image/jpeg;base64,..." }
// Returns: JSON con datos de factura extraídos
// =====================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Prompt de sistema optimizado para facturas colombianas
const SYSTEM_PROMPT = `Eres un experto en lectura de documentos comerciales colombianos de una empresa metalmecánica/industrial (Industrial de Molinos). Tu trabajo es extraer TODA la información de una imagen de factura, cuenta de cobro, remisión, recibo de caja, nota crédito o abono, y devolverla en JSON estructurado.

CONTEXTO DE LA EMPRESA:
- Industrial de Molinos compra materiales metalmecánicos (acero, tubería, tornillería, soldadura, láminas, ejes, pinturas, etc.).
- También vende productos industriales terminados (molinos, piezas, servicios de mecanizado).
- Los documentos que vas a leer SIEMPRE son de proveedores colombianos o del sector industrial.
- El comprador casi siempre es "Industrial de Molinos" o similar. El proveedor/vendedor es la otra empresa.

TIPOS DE DOCUMENTOS QUE PUEDES RECIBIR:
- FACTURA DE VENTA / FACTURA ELECTRÓNICA (FE): documento con ítems, subtotal, IVA, total.
- CUENTA DE COBRO: similar a factura pero sin resolución DIAN, generalmente sin IVA.
- RECIBO DE CAJA / COMPROBANTE DE EGRESO: registra UN PAGO (abono o total). Puede tener "Abono a factura FE-XXXX" o "Pago total". Extrae el monto como total.
- NOTA CRÉDITO: ajuste o devolución. El monto puede ser negativo conceptualmente.
- REMISIÓN: envío de mercancía, a veces con precios, a veces sin.
- ABONO: un pago parcial a una factura existente. Busca "Abono", "A cuenta de", "Anticipo".

REGLAS CRÍTICAS:
1. Extrae EXACTAMENTE lo que dice la factura, sin inventar datos.
2. Los montos deben ser numéricos (sin signos de pesos ni puntos de miles). Usa punto decimal. Ejemplo: "$2.500.000" → 2500000, "$1.234.567,89" → 1234567.89
3. Si un campo no está visible o no aplica, usa null.
4. Las fechas deben estar en formato YYYY-MM-DD.
5. El CUFE es un código alfanumérico largo que aparece en facturas electrónicas.
6. Identifica correctamente: emisor (proveedor/vendedor) vs receptor (comprador/cliente). El emisor es quien vende/cobra. El receptor es quien compra/paga (normalmente Industrial de Molinos).
7. Para cada ítem, extrae código de referencia, descripción, cantidad, unidad, precio unitario, IVA y total.
8. Detecta retenciones: RteFte, ReteICA, ReteIVA.

REGLAS PARA LECTURA DE TOTALES (MUY IMPORTANTE):
- Busca la cifra FINAL del documento: "TOTAL", "TOTAL A PAGAR", "VALOR TOTAL", "NETO A PAGAR", "TOTAL FACTURA".
- Si hay varias cifras, el TOTAL es la más grande que aparece al FINAL del desglose (después de subtotal + IVA - retenciones).
- En recibos de caja o abonos: el total es el "VALOR RECIBIDO", "MONTO", "TOTAL ABONO", "VALOR DEL PAGO".
- CUIDADO con separadores colombianos: el punto (.) es separador de miles, la coma (,) es decimal. "$2.500.000" = dos millones quinientos mil. "$2.500.000,50" = dos millones quinientos mil con cincuenta centavos.
- NUNCA confundas el número de factura con el valor. Los números de factura son cortos (ej: "FE 4196"). Los montos son grandes con puntos (ej: "$2.500.000").
- Si el total no cuadra con subtotal + IVA - retenciones, confía en lo que dice "TOTAL A PAGAR" escrito en el documento.

REGLAS DE IVA (OBLIGATORIO — LEER CON MÁXIMA ATENCIÓN):
- POR DEFECTO tax_rate=0 y tax_amount=0. Solo cambiar si se cumplen TODAS estas condiciones:
  1. Hay una línea que dice "IVA" (o "Impuesto" o "Tax") con un MONTO EN PESOS escrito al lado.
  2. El total del documento = subtotal + ese monto de IVA.
- NO asumas 19% de IVA NUNCA. No calcules IVA tú mismo.
- Si el documento tiene una casilla "IVA" pero está VACÍA, sin valor, o con $0: tax_rate=0, tax_amount=0.
- Si ves "IVA 19%" como texto pero NO hay un monto de dinero escrito junto a él: tax_rate=0, tax_amount=0.
- Si el total = subtotal (o total = subtotal - descuento): tax_rate=0, tax_amount=0.
- Recibos de venta, cuentas de cobro, facturas simplificadas: casi NUNCA tienen IVA.
- PROHIBIDO inventar o calcular montos de IVA. Solo TRANSCRIBIR lo que ESTÁ ESCRITO con un valor en pesos.

REGLAS ESPECIALES PARA CANTIDAD Y UNIDAD (MUY IMPORTANTE):
- "quantity" es la CANTIDAD DE PIEZAS O UNIDADES COMERCIALES del renglón (columna "Cant.", "Cantidad", "Qty"). Generalmente es un número entero pequeño (1, 2, 5, 10...).
- NUNCA uses el peso ni las dimensiones como quantity. Si ves columnas separadas como "Cant. | Kg | Precio/Kg": quantity=Cant., unit=UND, unit_price=precio total del item.
- Si la factura vende POR PESO (ej: "50 KG de alambre"): quantity=50, unit="KG".
- Si la factura vende PIEZAS PESADAS (ej: "2 láminas" con peso 444 kg): quantity=2, unit="UND". El peso es informativo, no es la cantidad.
- Para aceros estructurales, láminas, tubos, canales, vigas: la unidad casi siempre es UND y la cantidad es el número de barras/láminas/tramos pedidos (normalmente 1 a 20).
- Si unit_price × quantity NO cuadra con el subtotal del renglón, revisa si estás leyendo mal la columna de cantidad.

REGLAS DE UNIDAD DE MEDIDA (OBLIGATORIO):
- El campo "unit" DEBE ser EXACTAMENTE uno de estos valores normalizados:
  - "KG" → kilogramos (cuando la factura dice kg, kgs, kilo, kilos, kilogramo, kilogramos)
  - "UND" → unidades, piezas (cuando dice und, un, unidad, unidades, pza, pieza, piezas, pz)
  - "M" → metros lineales (cuando dice m, mt, mts, metro, metros, ml, metro lineal)
  - "L" → litros (cuando dice l, lt, lts, litro, litros)
  - "GAL" → galones (cuando dice gal, galon, galón, galones)
  - "M2" → metros cuadrados (cuando dice m2, mt2, metro cuadrado)
  - "GLB" → global/servicio (cuando dice glb, global, servicio, sv, lote)
- SIEMPRE normalizar a estos valores exactos. NUNCA dejar otros valores como "ROLLO", "BOLSA", "CAJA" etc.
- Si un producto se vende por rollos, cajas o bolsas: unit="UND", cada rollo/caja/bolsa es 1 unidad.
- Si no puedes determinar la unidad, usa "UND" por defecto.
- Productos industriales como bolas de molino, rodamientos, discos: unit="UND".
- Pinturas, solventes, thinner: unit="GAL" o "L" según lo que diga la factura.
- Soldadura en kilos: unit="KG". Soldadura por varillas: unit="UND" o "KG" según la factura.

REGLAS PARA DOCUMENTOS CON POCA INFORMACIÓN (recibos, abonos, comprobantes):
- Si el documento NO tiene ítems (solo un pago/abono), crea UN solo ítem con:
  - description: el concepto del pago (ej: "Abono a factura FE-4196", "Pago servicio de mecanizado")
  - quantity: 1
  - unit: "GLB" (global)
  - unit_price: el valor total del pago
  - subtotal: el valor total
  - total: el valor total
- Si el documento es un recibo de caja con "CONCEPTO" o "POR CONCEPTO DE", esa es la descripción del ítem.

Responde ÚNICAMENTE con JSON válido, sin markdown ni explicaciones.`;

const EXTRACTION_PROMPT = `Analiza esta imagen de documento comercial y extrae toda la información en este formato JSON exacto.

INSTRUCCIONES DE LECTURA:
1. PRIMERO identifica qué tipo de documento es (factura, recibo de caja, cuenta de cobro, nota crédito, remisión, abono).
2. Lee TODOS los números con cuidado: el punto (.) separa miles en Colombia. "$2.500.000" = 2500000.
3. Busca el TOTAL final: "TOTAL A PAGAR", "VALOR TOTAL", "NETO A PAGAR", "TOTAL FACTURA", "VALOR RECIBIDO".
4. Si es un abono/recibo: el concepto del pago va como un ítem único.
5. VERIFICA: subtotal + tax_amount - retenciones ≈ total. Si no cuadra, re-lee los números.

Formato JSON:

{
  "confidence": 0.95,
  "document_type": "FACTURA | CUENTA_DE_COBRO | RECIBO_DE_CAJA | NOTA_CREDITO | REMISION | ABONO | OTRO",
  "supplier": {
    "name": "Razón social del EMISOR/VENDEDOR",
    "trade_name": "Nombre comercial si difiere",
    "document_type": "NIT o CC",
    "document_number": "Número con dígito de verificación si aplica",
    "address": "Dirección completa",
    "phone": "Teléfono",
    "email": "Email si visible",
    "city": "Ciudad"
  },
  "buyer": {
    "name": "Razón social del COMPRADOR/CLIENTE",
    "document_type": "NIT o CC",
    "document_number": "Número",
    "address": "Dirección",
    "city": "Ciudad"
  },
  "invoice": {
    "number": "Número de factura completo (ej: FE 4196)",
    "date": "YYYY-MM-DD",
    "due_date": "YYYY-MM-DD si visible",
    "cufe": "Código CUFE si visible",
    "resolution_number": "Número de resolución DIAN si visible",
    "payment_method": "Contado, Crédito, etc.",
    "credit_days": 0,
    "currency": "COP"
  },
  "items": [
    {
      "reference_code": "Código del producto",
      "description": "Descripción completa del ítem",
      "quantity": 1.0,
      "unit": "UND, KG, M, L, GAL, M2, GLB (normalizar siempre a estos valores exactos)",
      "unit_price": 0.00,
      "discount": 0.00,
      "tax_rate": 0,
      "tax_amount": 0,
      "subtotal": 0.00,
      "total": 0.00
    }
  ],
  "totals": {
    "subtotal": 0.00,
    "discount": 0.00,
    "tax_base": 0.00,
    "tax_rate": 0,
    "tax_amount": 0,
    "retention_rte_fte": 0.00,
    "retention_ica": 0.00,
    "retention_iva": 0.00,
    "freight": 0.00,
    "total": 0.00
  },
  "notes": "Observaciones o notas de la factura si las hay"
}`;

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!OPENAI_API_KEY) {
      throw new Error(
        "OPENAI_API_KEY no configurada. Configúrala en Supabase Dashboard > Edge Functions > Secrets."
      );
    }

    const body = await req.json();
    const { image_url, image_base64, recent_corrections } = body;

    if (!image_url && !image_base64) {
      throw new Error("Debes enviar 'image_url' o 'image_base64'");
    }

    // Construir el contenido de imagen/archivo para OpenAI
    let imageContent: any;
    if (image_url) {
      imageContent = {
        type: "image_url",
        image_url: { url: image_url, detail: "high" },
      };
    } else {
      // base64 - asegurar formato correcto
      const base64Data = image_base64.startsWith("data:")
        ? image_base64
        : `data:image/jpeg;base64,${image_base64}`;

      // Detectar si es PDF para usar content type 'file' en vez de 'image_url'
      const isPdf = base64Data.startsWith("data:application/pdf");
      if (isPdf) {
        imageContent = {
          type: "file",
          file: {
            filename: "invoice.pdf",
            file_data: base64Data,
          },
        };
      } else {
        imageContent = {
          type: "image_url",
          image_url: { url: base64Data, detail: "high" },
        };
      }
    }

    // Construir system prompt con correcciones recientes si las hay
    let systemPrompt = SYSTEM_PROMPT;
    if (recent_corrections && Array.isArray(recent_corrections) && recent_corrections.length > 0) {
      const correctionsText = recent_corrections.join("\n");
      systemPrompt += `\n\nCORRECCIONES ANTERIORES DEL USUARIO (aprende de estos errores y NO los repitas):
${correctionsText}

IMPORTANTE: Las correcciones anteriores muestran errores que cometiste antes. Presta especial atención a:
- Si corrigieron totales, probablemente leíste mal los separadores de miles colombianos.
- Si corrigieron IVA a 0, no inventes IVA cuando no está escrito.
- Si corrigieron el número de factura, lee con más cuidado los encabezados.`;
    }

    // Llamar a OpenAI Vision API
    const openaiResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4.1-mini",
          messages: [
            {
              role: "system",
              content: systemPrompt,
            },
            {
              role: "user",
              content: [
                { type: "text", text: EXTRACTION_PROMPT },
                imageContent,
              ],
            },
          ],
          max_tokens: 4096,
          temperature: 0.1, // Baja temperatura para máxima precisión
        }),
      }
    );

    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      throw new Error(`OpenAI API error (${openaiResponse.status}): ${errorText}`);
    }

    const openaiData = await openaiResponse.json();
    const content = openaiData.choices?.[0]?.message?.content;

    if (!content) {
      throw new Error("OpenAI no devolvió contenido");
    }

    // Parsear JSON de la respuesta (puede venir con ```json wrapper)
    let extractedData;
    try {
      const jsonStr = content
        .replace(/```json\n?/g, "")
        .replace(/```\n?/g, "")
        .trim();
      extractedData = JSON.parse(jsonStr);
    } catch (parseError) {
      throw new Error(`Error parseando respuesta de OpenAI: ${content}`);
    }

    // Agregar metadata de uso
    const usage = openaiData.usage;
    const result = {
      success: true,
      data: extractedData,
      usage: {
        prompt_tokens: usage?.prompt_tokens ?? 0,
        completion_tokens: usage?.completion_tokens ?? 0,
        total_tokens: usage?.total_tokens ?? 0,
        model: "gpt-4.1-mini",
        estimated_cost_usd:
          ((usage?.prompt_tokens ?? 0) * 0.0000004 +
            (usage?.completion_tokens ?? 0) * 0.0000016).toFixed(6),
      },
    };

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: any) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "Error desconocido",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
