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
const SYSTEM_PROMPT = `Eres un experto en lectura de facturas colombianas de una empresa metalmecánica/industrial. Tu trabajo es extraer TODA la información de una imagen de factura de compra y devolverla en JSON estructurado.

REGLAS CRÍTICAS:
1. Extrae EXACTAMENTE lo que dice la factura, sin inventar datos.
2. Los montos deben ser numéricos (sin signos de pesos ni puntos de miles). Usa punto decimal.
3. Si un campo no está visible o no aplica, usa null.
4. Las fechas deben estar en formato YYYY-MM-DD.
5. El CUFE es un código alfanumérico largo que aparece en facturas electrónicas.
6. Identifica correctamente: emisor (proveedor/vendedor) vs receptor (comprador/cliente).
7. Para cada ítem, extrae código de referencia, descripción, cantidad, unidad, precio unitario, IVA y total.
8. Detecta retenciones: RteFte, ReteICA, ReteIVA.

REGLAS ESPECIALES PARA CANTIDAD Y UNIDAD (MUY IMPORTANTE):
- "quantity" es la CANTIDAD DE PIEZAS O UNIDADES COMERCIALES del renglón (columna "Cant.", "Cantidad", "Qty"). Generalmente es un número entero pequeño (1, 2, 5, 10...).
- NUNCA uses el peso ni las dimensiones como quantity. Si ves columnas separadas como "Cant. | Kg | Precio/Kg": quantity=Cant., unit=UND, unit_price=precio total del item.
- Si la factura vende POR PESO (ej: "50 KG de alambre"): quantity=50, unit="KG".
- Si la factura vende PIEZAS PESADAS (ej: "2 láminas" con peso 444 kg): quantity=2, unit="UND". El peso es informativo, no es la cantidad.
- Para aceros estructurales, láminas, tubos, canales, vigas: la unidad casi siempre es UND y la cantidad es el número de barras/láminas/tramos pedidos (normalmente 1 a 20).
- Si unit_price × quantity NO cuadra con el subtotal del renglón, revisa si estás leyendo mal la columna de cantidad.

Responde ÚNICAMENTE con JSON válido, sin markdown ni explicaciones.`;

const EXTRACTION_PROMPT = `Analiza esta imagen de factura y extrae toda la información en este formato JSON exacto:

{
  "confidence": 0.95,
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
      "unit": "UND, KG, MT, etc.",
      "unit_price": 0.00,
      "discount": 0.00,
      "tax_rate": 19.00,
      "tax_amount": 0.00,
      "subtotal": 0.00,
      "total": 0.00
    }
  ],
  "totals": {
    "subtotal": 0.00,
    "discount": 0.00,
    "tax_base": 0.00,
    "tax_rate": 19.00,
    "tax_amount": 0.00,
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
    const { image_url, image_base64 } = body;

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
              content: SYSTEM_PROMPT,
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
