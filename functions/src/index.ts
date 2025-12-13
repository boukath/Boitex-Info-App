// functions/src/index.ts

import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import B2 from "backblaze-b2";
import cors from "cors";
import axios from "axios";
import { defineSecret } from "firebase-functions/params";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";

// ------------------------------------------------------------------
// 1. INITIALIZATION & CONFIGURATION
// ------------------------------------------------------------------

admin.initializeApp();
setGlobalOptions({ region: "europe-west1" });

const backblazeKeyId = defineSecret("BACKBLAZE_KEY_ID");
const backblazeAppKey = defineSecret("BACKBLAZE_APP_KEY");
const backblazeBucketId = defineSecret("BACKBLAZE_BUCKET_ID");
const groqApiKey = defineSecret("GROQ_API_KEY");

// ------------------------------------------------------------------
// 2. EXPORTS (The "Table of Contents")
// ------------------------------------------------------------------

// Notifications & Activity Logs
export * from "./notification-handlers";

// Analytics Handlers
export {
  onInterventionAnalytics,
  onInstallationAnalytics,
  onLivraisonAnalytics,
  onMissionAnalytics,
  onSavAnalytics,
  onStockHistoryAnalytics,
  onProductAnalytics,
  onProductStockChanged
} from "./analytics-updater";

// PDF & Document Handlers
export { onInstallationTermine, getInstallationPdf } from "./installation-handlers";
export { createLivraisonFromInstallation } from "./installation-delivery-handler";
export { onInterventionTermine } from "./intervention-handlers";
export { onSavTicketCreated } from "./sav-handlers";
export { onSavTicketReturned } from "./sav-return-handlers";
export { downloadSavPdf } from "./callable-handlers";
export * from "./callable-handlers";
export { notifyUsersOnAppVersionUpdate } from "./notification-handlers";

// ------------------------------------------------------------------
// 3. AI / LLM FEATURES (GROQ)
// ------------------------------------------------------------------

const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

export const generateReportFromNotes = onCall(
  { secrets: [groqApiKey] },
  async (request) => {
    const rawNotes = request.data.rawNotes as string;
    const context = request.data.context as string | undefined;

    if (!rawNotes || rawNotes.trim().length === 0) {
      functions.logger.error("No rawNotes provided.");
      throw new HttpsError("invalid-argument", "The function must be called with 'rawNotes'.");
    }

    const modelId = "llama-3.1-8b-instant";
    let systemPrompt = "";

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
      default:
        systemPrompt = `Tu es un assistant expert pour Boitex Info.
        ${businessContext}
        **TA TÂCHE:** Ton unique objectif est de convertir les notes/mots-clés suivants en une **description de problème** claire et professionnelle en Français, telle que rapportée par un client de magasin. Ne crée PAS de section "Diagnostic" ou "Solution". Rédige simplement la plainte du client en utilisant le bon contexte.`;
        break;
    }

    const messages = [
      { role: "system", content: systemPrompt },
      { role: "user", content: rawNotes },
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
      return formalReport;

    } catch (error) {
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

// ------------------------------------------------------------------
// 4. STORAGE HELPERS (BACKBLAZE B2)
// ------------------------------------------------------------------

const corsHandler = cors({ origin: true });

export const getB2UploadUrl = onRequest(
  { secrets: [backblazeKeyId, backblazeAppKey, backblazeBucketId] },
  (request, response) => {
    corsHandler(request, response, async () => {
      try {
        const b2 = new B2({
          applicationKeyId: backblazeKeyId.value(),
          applicationKey: backblazeAppKey.value(),
        });

        const authResponse = await b2.authorize();
        const { downloadUrl } = authResponse.data;
        const bucketId = backblazeBucketId.value();

        const uploadUrlResponse = await b2.getUploadUrl({ bucketId: bucketId });
        const bucketName = "BoitexInfo";
        const downloadUrlPrefix = `${downloadUrl}/file/${bucketName}/`;

        functions.logger.info("Successfully generated B2 upload URL.");

        response.status(200).send({
          uploadUrl: uploadUrlResponse.data.uploadUrl,
          authorizationToken: uploadUrlResponse.data.authorizationToken,
          downloadUrlPrefix: downloadUrlPrefix,
        });
      } catch (error) {
        functions.logger.error("Error getting B2 upload URL:", error);
        response.status(500).send({
          error: "Failed to get an upload URL from Backblaze B2.",
        });
      }
    });
  }
);