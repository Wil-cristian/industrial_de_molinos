# Asistente IA para Industrial de Molinos - Investigación y Plan

> **Fecha:** Marzo 2026  
> **Estado:** Investigación completada - Listo para implementación  
> **Prioridad:** Alta

---

## 1. Resumen Ejecutivo

Se propone agregar un **Asistente IA conversacional** a la aplicación que:
- **Reciba entrada por voz** (audio) y texto
- **Responda preguntas** sobre la información de la empresa (clientes, facturas, inventario, etc.)
- **Ejecute acciones** en los módulos (crear facturas, consultar saldos, registrar movimientos)
- **Responda por voz** opcionalmente (text-to-speech)

---

## 2. Arquitectura Recomendada (Estado del Arte 2025-2026)

### Patrón: **Edge Function + LLM con Function Calling**

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                           │
│                                                         │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Micrófono│───▶│ speech_to_   │───▶│   Chat UI    │  │
│  │  (record) │    │ text (local) │    │  (mensajes)  │  │
│  └──────────┘    └──────────────┘    └──────┬───────┘  │
│                                              │          │
│                                              ▼          │
│                                     ┌──────────────┐   │
│                                     │   Provider    │   │
│                                     │  (Riverpod)  │   │
│                                     └──────┬───────┘   │
└────────────────────────────────────────────┼───────────┘
                                              │ HTTPS
                                              ▼
┌─────────────────────────────────────────────────────────┐
│              Supabase Edge Function                      │
│              "ai-assistant"                              │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  1. Recibe mensaje + contexto del usuario         │   │
│  │  2. Consulta Supabase DB para contexto relevante  │   │
│  │  3. Llama OpenAI API con Function Calling         │   │
│  │  4. Si el LLM pide una función → la ejecuta      │   │
│  │  5. Retorna respuesta al Flutter app              │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ OpenAI API  │  │ Supabase DB  │  │  Functions   │  │
│  │ gpt-4.1     │  │ (consultas)  │  │ (acciones)   │  │
│  └─────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### ¿Por qué esta arquitectura?

| Decisión | Razón |
|----------|-------|
| **Edge Function como proxy** | La API key de OpenAI queda segura en el servidor, nunca en el cliente |
| **Function Calling de OpenAI** | Técnica más moderna (GA 2025). El LLM decide cuándo llamar funciones |
| **Speech-to-text en Edge Function** | Usar Whisper/gpt-4o-transcribe de OpenAI — más preciso que opciones locales |
| **Supabase DB como contexto** | Los datos de la empresa ya están ahí — el asistente los consulta en tiempo real |
| **Riverpod para estado** | Consistente con el resto de la app |

---

## 3. Componentes Técnicos Detallados

### 3.1 Entrada de Audio (Speech-to-Text)

#### Opción A: Audio grabado en Flutter + Transcripción en Edge Function (RECOMENDADA)

**Flujo:**
1. El usuario presiona el botón de micrófono en la app
2. Se graba audio usando el paquete `record` (soporta Windows, Android, iOS, Web)
3. Se envía el audio como base64 a la Edge Function
4. La Edge Function usa **OpenAI Whisper API** (`gpt-4o-transcribe`) para transcribir
5. El texto transcrito se envía al LLM

**Paquetes Flutter necesarios:**
```yaml
# Para grabar audio en todas las plataformas
record: ^5.1.2            # Grabación de audio (Windows, Android, iOS, Web, macOS, Linux)
```

**Ventajas:**
- Transcripción de alta calidad (Whisper es el mejor STT del mercado)
- Soporta español nativo
- No requiere permisos especiales de Google/Apple para STT
- Funciona offline para grabar, online para transcribir

#### Opción B: Alternativa — OpenAI Realtime API (WebRTC)

La **Realtime API** de OpenAI (GA 2025) permite interacción speech-to-speech en tiempo real via WebRTC o WebSocket. Es la tecnología más avanzada, pero:
- Más compleja de implementar en Flutter (requiere WebRTC en Dart)
- Más costosa ($$ por minuto de audio)
- Mejor para assistentes de voz puros (tipo call center)
- **Recomendación:** Considerar en una segunda fase si el asistente por voz es muy usado

#### Opción C: Speech-to-Text del dispositivo (Menor calidad)

Usar `speech_to_text` de Flutter (usa los motores del SO):
- Android: Google Speech Recognition
- iOS: Apple Speech Framework  
- Windows: Windows Speech Recognition
- **Limitación:** Calidad variable, requiere internet de todos modos, no funciona bien en Windows

**Decisión: Opción A** — Grabar audio localmente + Whisper en el backend.

---

### 3.2 Motor de IA (LLM + Function Calling)

#### Modelo recomendado: **GPT-4.1** o **GPT-4.1-mini**

El **Function Calling** de OpenAI (ahora GA, ya no beta) es la técnica más madura y adecuada:

```typescript
// Ejemplo de tools que el asistente puede llamar
const tools = [
  // === CONSULTAS (solo lectura) ===
  {
    type: "function",
    name: "consultar_clientes",
    description: "Busca clientes por nombre, NIT o teléfono",
    parameters: {
      type: "object",
      properties: {
        busqueda: { type: "string", description: "Término de búsqueda" }
      },
      required: ["busqueda"],
      additionalProperties: false
    },
    strict: true
  },
  {
    type: "function",
    name: "consultar_facturas",
    description: "Busca facturas por cliente, fecha, estado o número",
    parameters: {
      type: "object",
      properties: {
        cliente: { type: ["string", "null"], description: "Nombre del cliente" },
        estado: { type: ["string", "null"], enum: ["pendiente", "pagada", "anulada", null] },
        fecha_inicio: { type: ["string", "null"], description: "Fecha inicio YYYY-MM-DD" },
        fecha_fin: { type: ["string", "null"], description: "Fecha fin YYYY-MM-DD" }
      },
      required: ["cliente", "estado", "fecha_inicio", "fecha_fin"],
      additionalProperties: false
    },
    strict: true
  },
  {
    type: "function",
    name: "consultar_inventario",
    description: "Consulta stock de materiales o productos",
    parameters: {
      type: "object",
      properties: {
        material: { type: ["string", "null"], description: "Nombre del material" },
        categoria: { type: ["string", "null"], description: "Categoría del material" }
      },
      required: ["material", "categoria"],
      additionalProperties: false
    },
    strict: true
  },
  {
    type: "function",
    name: "consultar_caja_diaria",
    description: "Obtiene el resumen de caja del día o fecha específica",
    parameters: {
      type: "object",
      properties: {
        fecha: { type: ["string", "null"], description: "Fecha YYYY-MM-DD, null para hoy" }
      },
      required: ["fecha"],
      additionalProperties: false
    },
    strict: true
  },
  {
    type: "function",
    name: "consultar_cuentas_por_cobrar",
    description: "Lista facturas pendientes de pago por cliente",
    parameters: {
      type: "object",
      properties: {
        cliente: { type: ["string", "null"] }
      },
      required: ["cliente"],
      additionalProperties: false
    },
    strict: true
  },
  
  // === ACCIONES (escritura) ===
  {
    type: "function",
    name: "crear_factura",
    description: "Crea una nueva factura de venta. SIEMPRE confirmar datos con el usuario antes de ejecutar.",
    parameters: {
      type: "object",
      properties: {
        cliente_nombre: { type: "string" },
        items: {
          type: "array",
          items: {
            type: "object",
            properties: {
              descripcion: { type: "string" },
              cantidad: { type: "number" },
              precio_unitario: { type: "number" },
              iva_porcentaje: { type: "number" }
            },
            required: ["descripcion", "cantidad", "precio_unitario", "iva_porcentaje"],
            additionalProperties: false
          }
        },
        notas: { type: ["string", "null"] }
      },
      required: ["cliente_nombre", "items", "notas"],
      additionalProperties: false
    },
    strict: true
  },
  {
    type: "function",
    name: "registrar_pago",
    description: "Registra un pago contra una factura pendiente",
    parameters: {
      type: "object",
      properties: {
        factura_numero: { type: "string" },
        monto: { type: "number" },
        metodo_pago: { type: "string", enum: ["efectivo", "transferencia", "cheque"] }
      },
      required: ["factura_numero", "monto", "metodo_pago"],
      additionalProperties: false
    },
    strict: true
  },
  {
    type: "function",
    name: "registrar_gasto",
    description: "Registra un gasto o compra en caja diaria",
    parameters: {
      type: "object",
      properties: {
        concepto: { type: "string" },
        monto: { type: "number" },
        categoria: { type: "string" },
        proveedor: { type: ["string", "null"] }
      },
      required: ["concepto", "monto", "categoria", "proveedor"],
      additionalProperties: false
    },
    strict: true
  }
];
```

**El flujo de Function Calling funciona así:**
1. Usuario dice: *"¿Cuánto debe el cliente Ferretería López?"*
2. El LLM analiza y decide llamar `consultar_cuentas_por_cobrar({ cliente: "Ferretería López" })`
3. La Edge Function ejecuta la query SQL en Supabase
4. Retorna el resultado al LLM
5. El LLM genera respuesta natural: *"Ferretería López tiene 3 facturas pendientes por un total de $4,500,000 COP..."*

Para acciones de escritura (crear factura, registrar pago):
1. El LLM **siempre** pide confirmación antes de ejecutar
2. La Edge Function valida los datos
3. Se ejecuta la acción en la BD
4. Se confirma al usuario

---

### 3.3 Respuesta por Voz (Text-to-Speech) — Opcional

#### Opción recomendada: **OpenAI TTS** (`gpt-4o-mini-tts`)

```typescript
// En la Edge Function, después de generar la respuesta de texto:
const ttsResponse = await fetch("https://api.openai.com/v1/audio/speech", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${OPENAI_API_KEY}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    model: "gpt-4o-mini-tts",
    input: respuestaTexto,
    voice: "nova",  // Voces: alloy, echo, fable, onyx, nova, shimmer
    response_format: "mp3"
  })
});
```

**Alternativa gratuita:** `flutter_tts` (usa TTS del sistema operativo) — menor calidad pero sin costo.

---

### 3.4 Contexto de Empresa (System Prompt)

El system prompt es CRUCIAL. Debe contener toda la información contextual de la empresa:

```typescript
const SYSTEM_PROMPT = `Eres el asistente IA de "Industrial de Molinos", una empresa metalmecánica 
e industrial ubicada en Colombia. Tu rol es ayudar al equipo con la gestión del negocio.

SOBRE LA EMPRESA:
- Empresa metalmecánica/industrial (fabricación de molinos y productos de acero)
- Moneda: Pesos Colombianos (COP)
- IVA estándar: 19%
- Retenciones aplicables: RteFte, ReteICA, ReteIVA
- Sistema contable colombiano

TUS CAPACIDADES:
- Consultar clientes, proveedores, facturas, inventario, caja diaria
- Crear facturas, registrar pagos, registrar gastos
- Dar reportes y resúmenes ejecutivos
- Responder preguntas sobre el estado del negocio

REGLAS:
1. Responde SIEMPRE en español
2. Sé conciso y directo — este es un ambiente de trabajo industrial
3. Para ACCIONES que modifican datos (crear factura, registrar pago), SIEMPRE confirma 
   los datos con el usuario antes de ejecutar. Muestra un resumen y pregunta "¿Confirmo?"
4. Formatea montos como moneda colombiana: $1.234.567
5. Si no tienes suficiente información para una acción, pregunta lo que falta
6. Nunca inventes datos — si no encuentras algo, dilo
7. Para consultas de fechas, asume que "hoy" es la fecha actual del sistema`;
```

---

## 4. Estructura de Archivos Propuesta

```
lib/
  domain/
    entities/
      chat_message.dart           # Entidad: mensaje de chat (user/assistant/system)
  data/
    datasources/
      ai_assistant_datasource.dart # Comunicación con Edge Function
    providers/
      ai_assistant_provider.dart   # Estado del chat (Riverpod)
  presentation/
    pages/
      ai_assistant_page.dart       # Pantalla principal del asistente
    widgets/
      chat_bubble.dart             # Widget de burbuja de mensaje
      voice_input_button.dart      # Botón de grabación de voz
      action_confirmation_card.dart # Card para confirmar acciones

supabase/
  functions/
    ai-assistant/
      index.ts                     # Edge Function principal
```

---

## 5. Edge Function: `ai-assistant` (Diseño)

```typescript
// supabase/functions/ai-assistant/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

// Se recibe: { message: string, audio_base64?: string, conversation_history: [] }
// Se retorna: { response: string, audio_base64?: string, action_performed?: {} }

serve(async (req) => {
  const { message, audio_base64, conversation_history } = await req.json();
  
  let userMessage = message;
  
  // 1. Si hay audio, transcribir con Whisper
  if (audio_base64) {
    userMessage = await transcribeAudio(audio_base64);
  }
  
  // 2. Preparar contexto y tools
  const tools = getAssistantTools();
  const messages = [
    { role: "system", content: SYSTEM_PROMPT },
    ...conversation_history,
    { role: "user", content: userMessage }
  ];
  
  // 3. Llamar OpenAI con Function Calling
  let response = await callOpenAI(messages, tools);
  
  // 4. Si el modelo pide funciones, ejecutarlas
  while (response.hasToolCalls) {
    const results = await executeToolCalls(response.toolCalls, supabaseClient);
    response = await callOpenAIWithResults(messages, tools, results);
  }
  
  // 5. Retornar respuesta
  return new Response(JSON.stringify({
    response: response.text,
    transcription: audio_base64 ? userMessage : undefined,
  }));
});
```

---

## 6. Paquetes Flutter Necesarios

```yaml
# pubspec.yaml - NUEVAS dependencias
dependencies:
  # ... existentes ...
  
  # Grabación de audio (multi-plataforma)
  record: ^5.1.2
  
  # Reproductor de audio (para TTS response)  
  just_audio: ^0.9.40
  
  # Permisos (micrófono)
  permission_handler: ^11.3.1
  
  # Animaciones para el indicador de grabación
  lottie: ^3.1.2  # Opcional, para animaciones bonitas
```

---

## 7. Costos Estimados (OpenAI API)

| Servicio | Modelo | Costo por llamada aprox. |
|----------|--------|-------------------------|
| Transcripción (STT) | gpt-4o-transcribe | ~$0.006/minuto de audio |
| Chat + Function Calling | gpt-4.1-mini | ~$0.0004-$0.002/mensaje |
| Chat + Function Calling | gpt-4.1 | ~$0.002-$0.01/mensaje |
| Text-to-Speech | gpt-4o-mini-tts | ~$0.015/1000 caracteres |

**Estimación mensual** (uso moderado, ~100 interacciones/día):
- Solo texto: **$5-15 USD/mes** (gpt-4.1-mini)
- Con audio STT: **$10-25 USD/mes**  
- Con TTS (respuesta por voz): **$20-40 USD/mes**

**Recomendación:** Empezar con `gpt-4.1-mini` + Whisper STT. Es barato y muy capaz.

---

## 8. Fases de Implementación

### Fase 1: Chat Básico con Texto (1-2 días)
- [ ] Crear entidad `ChatMessage`
- [ ] Crear Edge Function `ai-assistant` con system prompt + OpenAI API
- [ ] Crear `ai_assistant_datasource.dart` 
- [ ] Crear `ai_assistant_provider.dart` (Riverpod)
- [ ] Crear UI de chat básica (`ai_assistant_page.dart`)
- [ ] Agregar ruta `/assistant` al router
- [ ] Agregar botón de acceso en sidebar/navbar

### Fase 2: Function Calling — Consultas (1-2 días)
- [ ] Definir tools de consulta en la Edge Function
- [ ] Implementar funciones: `consultar_clientes`, `consultar_facturas`, `consultar_inventario`
- [ ] Implementar: `consultar_caja_diaria`, `consultar_cuentas_por_cobrar`
- [ ] Probar consultas de lenguaje natural → SQL

### Fase 3: Entrada por Voz (1 día)
- [ ] Agregar paquete `record` + `permission_handler`
- [ ] Crear widget `VoiceInputButton` con animación de grabación
- [ ] Enviar audio a Edge Function → Whisper transcription
- [ ] Mostrar transcripción en la UI

### Fase 4: Function Calling — Acciones (1-2 días)
- [ ] Implementar `crear_factura` con confirmación
- [ ] Implementar `registrar_pago` con confirmación
- [ ] Implementar `registrar_gasto` con confirmación
- [ ] UI de confirmación de acciones (card especial)
- [ ] Validación de datos antes de escritura

### Fase 5: Polish y TTS (1 día)
- [ ] Agregar TTS opcional (respuesta por voz)
- [ ] Historial de conversaciones (persistencia local)
- [ ] Mejoras de UX (sugerencias rápidas, loading states)
- [ ] Testing end-to-end

---

## 9. Alternativas Investigadas y Descartadas

### Google Gemini (Firebase AI)
- **Pro:** SDK nativo de Flutter (`google_generative_ai`), gratis en tier bajo
- **Contra:** Function Calling menos maduro, menor calidad en español, no tiene STT/TTS integrado
- **Veredicto:** Viable como segunda opción si OpenAI es muy caro

### Claude (Anthropic)
- **Pro:** Excelente razonamiento
- **Contra:** No tiene STT/TTS, function calling menos estándar, no hay SDK de Dart
- **Veredicto:** Se puede usar vía API REST pero OpenAI tiene mejor ecosistema de audio

### Soluciones On-Device (Ollama, llama.cpp)
- **Pro:** Sin costo de API, privacidad total
- **Contra:** Requiere hardware potente, no viable en móviles, function calling muy limitado
- **Veredicto:** No viable para esta app multi-plataforma

### OpenAI Realtime API (WebRTC)
- **Pro:** Latencia ultra-baja, speech-to-speech nativo
- **Contra:** Complejo de implementar en Flutter/Dart, más caro, diseñado para JS/browser
- **Veredicto:** Excelente para Fase 2 futura si se necesita experiencia tipo "Siri"

### LangChain (Dart)
- **Pro:** Framework de orquestación de LLMs
- **Contra:** El paquete Dart está inmaduro, agrega complejidad innecesaria
- **Veredicto:** La Edge Function con OpenAI directo es más simple y mantenible

---

## 10. Consideraciones de Seguridad

| Riesgo | Mitigación |
|--------|------------|
| API Key expuesta | Edge Function guarda la key en env vars del servidor |
| Inyección de prompts | Validar inputs, system prompt robusto, no exponer SQL directo |
| Acciones no autorizadas | Confirmar SIEMPRE antes de ejecutar acciones de escritura |
| Datos sensibles en el LLM | No enviar passwords, tokens ni datos de autenticación al prompt |
| Costos desbocados | Rate limiting en Edge Function, tope de mensajes por día |
| Alucinaciones del LLM | Solo datos de BD real, nunca inventar cifras |

---

## 11. Diagrama de Flujo de una Interacción Completa

```
Usuario habla: "Hazme una factura para Ferretería López, 
                5 láminas de acero a 200 mil cada una"
    │
    ▼
[Flutter] Graba audio → base64
    │
    ▼
[Edge Function] Whisper transcribe → texto
    │
    ▼
[Edge Function] OpenAI analiza con Function Calling
    │
    ▼
[OpenAI] Decide llamar: consultar_clientes("Ferretería López")
    │
    ▼
[Edge Function] Query Supabase → encuentra cliente ID=42
    │
    ▼
[OpenAI] Retorna respuesta con resumen:
    "Voy a crear la factura:
     Cliente: Ferretería López (NIT 900.123.456-7)
     - 5x Lámina de Acero: $200.000 c/u = $1.000.000
     - IVA 19%: $190.000
     - Total: $1.190.000
     ¿Confirmo la factura?"
    │
    ▼
[Flutter] Muestra card de confirmación
    │
    ▼
Usuario confirma: "Sí, confirmar"
    │
    ▼
[Edge Function] Ejecuta crear_factura(...)
    │
    ▼
[OpenAI] "✅ Factura #FV-0234 creada exitosamente por $1.190.000"
```

---

## 12. Quick Start — Primeros Pasos

Para empezar la implementación, el orden es:

1. **Agregar `OPENAI_API_KEY`** al `.env` (ya deberían tener una por el scanner de facturas)
2. **Crear la Edge Function** `ai-assistant` en Supabase
3. **Crear la UI de chat** en Flutter
4. **Conectar** con el provider de Riverpod
5. **Probar** con mensajes de texto simples
6. **Agregar** function calling progresivamente
7. **Agregar** entrada de voz al final

**La clave de OpenAI existente del scan-invoice sirve perfectamente. No se necesita ningún servicio adicional.**

---

## 13. Resumen de Tecnologías Seleccionadas

| Componente | Tecnología | Versión/Modelo |
|------------|-----------|----------------|
| **LLM** | OpenAI Responses API | gpt-4.1-mini (inicio) → gpt-4.1 (si necesario) |
| **Function Calling** | OpenAI Tools (GA) | strict mode habilitado |
| **Speech-to-Text** | OpenAI Whisper | gpt-4o-transcribe |
| **Text-to-Speech** | OpenAI TTS | gpt-4o-mini-tts (opcional) |
| **Backend** | Supabase Edge Function | Deno runtime |
| **Grabación Audio** | record (Flutter) | ^5.1.2 |
| **Estado** | flutter_riverpod | ^3.0.3 (existente) |
| **Base de Datos** | Supabase PostgreSQL | (existente) |
| **UI** | Material Design 3 | (existente) |

---

*Este plan aprovecha al máximo la infraestructura existente (Supabase, OpenAI API key, Riverpod) 
y las técnicas más actualizadas de IA (Function Calling GA, Whisper, GPT-4.1).  
La implementación completa se puede lograr en aproximadamente 1 semana.*
