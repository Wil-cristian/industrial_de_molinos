// =====================================================
// SUPABASE EDGE FUNCTION: scan-expense
// =====================================================
// Recibe una imagen de recibo/factura de GASTO y usa
// OpenAI Vision (GPT-4.1-mini) para extraer datos y
// clasificar la categoría de gasto automáticamente.
//
// POST /functions/v1/scan-expense
// Body: { "image_base64": "data:image/jpeg;base64,..." }
// Returns: JSON con datos del gasto extraídos + categoría
// =====================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Eres un experto en lectura de documentos comerciales colombianos. Tu trabajo es analizar imágenes de recibos, facturas, cuentas de cobro o comprobantes de GASTOS de una empresa (Industrial de Molinos) y:
1. Extraer los datos clave del documento (monto, descripción, fecha, proveedor, referencia).
2. CLASIFICAR automáticamente el gasto en una de las categorías predefinidas.

CATEGORÍAS DE GASTO (debes elegir EXACTAMENTE una):
- "consumibles": Materias primas, insumos industriales, materiales de producción, repuestos, herramientas, productos químicos, lubricantes, soldadura, discos de corte, pinturas, elementos de ferretería.
- "servicios_publicos": Luz, agua, gas, internet, telefonía, alcantarillado, aseo.
- "papeleria": Papel, tinta, carpetas, útiles de oficina, impresiones, fotocopias.
- "nomina": Pagos de salario, primas, cesantías, vacaciones, liquidaciones, aportes seguridad social, parafiscales.
- "impuestos": ICA, predial, vehículos, DIAN, retenciones, declaraciones tributarias.
- "cuidado_personal": Elementos de protección personal (EPP), guantes, gafas, tapabocas, botas, overoles, dotación trabajadores.
- "transporte": Fletes, envíos, combustible, peajes, pasajes, alquiler de vehículos, mensajería.
- "gastos_reducibles": Restaurantes, cafetería, aseo general, decoración, suscripciones, publicidad, gastos menores varios.

REGLAS DE CLASIFICACIÓN:
- Si el documento tiene múltiples ítems de distintas categorías, elige la categoría del ítem de MAYOR VALOR.
- Si no queda claro, usa "gastos_reducibles" como categoría por defecto.
- Facturas de aceros, metales, tornillería, soldadura → "consumibles".
- Recibos de EPP/seguridad → "cuidado_personal".
- Facturas de transporte/flete → "transporte".

REGLAS DE LECTURA DE MONTOS:
- Colombia usa punto (.) como separador de miles y coma (,) como decimal.
- "$2.500.000" = 2500000. "$1.234,50" = 1234.50.
- Busca el TOTAL FINAL: "TOTAL A PAGAR", "VALOR TOTAL", "NETO A PAGAR", "TOTAL FACTURA", "VALOR RECIBIDO".
- Los montos en la respuesta deben ser numéricos (sin signos de pesos ni separadores de miles).

REGLAS DE IVA:
- Solo reporta IVA si EXPLÍCITAMENTE aparece un monto de IVA en pesos en el documento.
- NUNCA asumas ni calcules IVA por tu cuenta.
- Si no hay IVA visible: iva_amount = 0.

REGLAS GENERALES:
1. Extrae EXACTAMENTE lo que dice el documento, sin inventar datos.
2. Si un campo no está visible, usa null.
3. Fechas en formato YYYY-MM-DD.
4. Si es un recibo simple sin ítems detallados, la descripción es el concepto general del gasto.

Responde ÚNICAMENTE con JSON válido, sin markdown ni explicaciones.`;

const EXTRACTION_PROMPT = `Analiza esta imagen de recibo/factura de gasto y extrae la información en este formato JSON exacto:

{
  "confidence": 0.95,
  "category": "consumibles | servicios_publicos | papeleria | nomina | impuestos | cuidado_personal | transporte | gastos_reducibles",
  "category_reason": "Breve explicación de por qué elegiste esta categoría",
  "document_type": "FACTURA | CUENTA_DE_COBRO | RECIBO | COMPROBANTE | TIRILLA | OTRO",
  "supplier": {
    "name": "Nombre del establecimiento o proveedor",
    "document_number": "NIT o CC si visible",
    "city": "Ciudad si visible"
  },
  "expense": {
    "description": "Descripción clara y concisa del gasto (máx 100 caracteres)",
    "date": "YYYY-MM-DD",
    "reference": "Número de factura o recibo si visible",
    "subtotal": 0.00,
    "iva_amount": 0.00,
    "total": 0.00,
    "payment_method": "Efectivo | Transferencia | Tarjeta | No especificado"
  },
  "items": [
    {
      "description": "Descripción del ítem",
      "quantity": 1,
      "unit_price": 0.00,
      "total": 0.00
    }
  ],
  "notes": "Observaciones adicionales si las hay"
}`;

serve(async (req: Request) => {
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
    const { image_base64, image_url } = body;

    if (!image_base64 && !image_url) {
      throw new Error("Debes enviar 'image_base64' o 'image_url'");
    }

    // Construir contenido de imagen para OpenAI
    let imageContent: any;
    if (image_url) {
      imageContent = {
        type: "image_url",
        image_url: { url: image_url, detail: "high" },
      };
    } else {
      const base64Data = image_base64.startsWith("data:")
        ? image_base64
        : `data:image/jpeg;base64,${image_base64}`;

      const isPdf = base64Data.startsWith("data:application/pdf");
      if (isPdf) {
        imageContent = {
          type: "file",
          file: {
            filename: "expense.pdf",
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
            { role: "system", content: SYSTEM_PROMPT },
            {
              role: "user",
              content: [
                { type: "text", text: EXTRACTION_PROMPT },
                imageContent,
              ],
            },
          ],
          max_tokens: 2048,
          temperature: 0.1,
        }),
      }
    );

    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      throw new Error(
        `OpenAI API error (${openaiResponse.status}): ${errorText}`
      );
    }

    const openaiData = await openaiResponse.json();
    const content = openaiData.choices?.[0]?.message?.content;

    if (!content) {
      throw new Error("OpenAI no devolvió contenido");
    }

    // Parsear JSON
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

    // Validar que la categoría sea válida
    const validCategories = [
      "consumibles",
      "servicios_publicos",
      "papeleria",
      "nomina",
      "impuestos",
      "cuidado_personal",
      "transporte",
      "gastos_reducibles",
    ];
    if (!validCategories.includes(extractedData.category)) {
      extractedData.category = "gastos_reducibles";
      extractedData.category_reason =
        "Categoría no reconocida, asignada por defecto";
    }

    const usage = openaiData.usage;
    const result = {
      success: true,
      data: extractedData,
      usage: {
        prompt_tokens: usage?.prompt_tokens ?? 0,
        completion_tokens: usage?.completion_tokens ?? 0,
        total_tokens: usage?.total_tokens ?? 0,
        model: "gpt-4.1-mini",
        estimated_cost_usd: (
          (usage?.prompt_tokens ?? 0) * 0.0000004 +
          (usage?.completion_tokens ?? 0) * 0.0000016
        ).toFixed(6),
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
