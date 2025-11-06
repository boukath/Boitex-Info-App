// functions/src/http/ai_service.ts

import * as functions from "firebase-functions";
import axios from "axios"; // ✅ ADDED
import {defineSecret} from "firebase-functions/params";
import {onCall, HttpsError} from "firebase-functions/v2/https"; // ✅ MODIFIED

// ✅ --- ADDED: Define secrets here ---
const groqApiKey = defineSecret("GROQ_API_KEY");

// Define the Groq API endpoint
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

/**
* Generates formal text from raw notes based on a given context.
* (e.g., 'problem_report', 'diagnostic', 'workDone')
*/
//
// ⭐️ ----- NEW FILE ----- ⭐️
//
export const generateReportFromNotes = onCall(
{secrets: [groqApiKey]},
async (request) => {
    // ✅ 1. Get both rawNotes and context from the app
    const rawNotes = request.data.rawNotes as string;
    const context = request.data.context as string | undefined; // 'problem_report', 'diagnostic', 'workDone'

    if (!rawNotes || rawNotes.trim().length === 0) {
      functions.logger.error("No rawNotes provided.");
      throw new HttpsError("invalid-argument", "The function must be called with 'rawNotes'.");
    }

    // Use a fast model available on Groq
    const modelId = "llama-3.1-8b-instant";

    // ✅ 2. Select the correct prompt based on the context
    let systemPrompt = "";

    // ✅ THIS IS THE "TRAINING" YOU REQUESTED.
    // We give it business context.
    const businessContext = `
      **CONTEXTE IMPORTANT:**
      - "Boitex Info" est une société spécialisée dans les systèmes de sécurité pour **magasins (retail)**.
      - Le terme "antivol" ou "anti vol" fait référence à des **systèmes de sécurité pour magasins** (portiques antivol, anti-vol à l'étalage, antivol textile).
      - **NE PAS** l'associer à des voitures ou des véhicules.
    `;

    switch (context) {
      case 'diagnostic':
        systemPrompt = `Tu es un technicien expert pour Boitex Info.
        ${businessContext}
        **TA TÂCHE:** Convertir les notes/mots-clés suivants en un **diagnostic technique** clair et professionnel. Reste factuel et précis. Ne parle pas de la solution.`;
        break;
      case 'workDone':
        systemPrompt = `Tu es un technicien expert pour Boitex Info.
        ${businessContext}
        **TA TÂCHE:** Convertir les notes/mots-clés suivants en un rapport formel des **travaux effectués**. Liste les actions de manière claire. Ne parle pas du diagnostic.`;
        break;
      case 'problem_report':
      default: // This is the original prompt from add_intervention_page
        systemPrompt = `Tu es un assistant expert pour Boitex Info.
        ${businessContext}
        **TA TÂCHE:** Ton unique objectif est de convertir les notes/mots-clés suivants en une **description de problème** claire et professionnelle en Français, telle que rapportée par un client de magasin. Ne crée PAS de section "Diagnostic" ou "Solution". Rédige simplement la plainte du client en utilisant le bon contexte.`;
        break;
    }

    // 3. Use the standard OpenAI "messages" format
    const messages = [
      {
        role: "system",
        content: systemPrompt, // Use the selected prompt
      },
      {
        role: "user",
        content: rawNotes,
      },
    ];

    try {
      functions.logger.info(`Calling Groq API (${modelId}) for context: ${context}`);

      const response = await axios.post(
        GROQ_API_URL,
        {
          model: modelId,
          messages: messages,
          max_tokens: 300,
          stream: false,
        },
        {
          headers: {
            "Authorization": `Bearer ${groqApiKey.value()}`,
            "Content-Type": "application/json",
          },
        }
      );

      if (!response.data || !response.data.choices || response.data.choices.length === 0) {
        functions.logger.error("Invalid response from Groq API", response.data);
        throw new Error("Invalid response from Groq API");
      }

      const formalReport = response.data.choices[0].message.content.trim();

      functions.logger.info(`Successfully generated report: ${formalReport}`);
      return formalReport; // Send the clean text back to the app

    } catch (error) {
      // We must check the type of 'error' before accessing properties.
      if (axios.isAxiosError(error)) {
        functions.logger.error("Error calling Groq API (Axios):", error.response?.data || error.message);
      } else if (error instanceof Error) {
        functions.logger.error("Error calling Groq API (General):", error.message);
      } else {
        functions.logger.error("Error calling Groq API (Unknown):", error);
      }

      throw new HttpsError("internal", "Failed to generate AI report.");
    }
  }
);