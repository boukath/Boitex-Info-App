// functions/src/callable-handlers.ts

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import axios from "axios";
import { defineSecret } from "firebase-functions/params";
import { generateInterventionPdf } from "./pdf-generator"; // Import your PDF utility
// ✅ ADDED: Imports for SAV PDF Generators
import { generateSavDechargePdf } from "./sav-pdf-generator";
import { generateSavReturnPdf } from "./sav-return-pdf-generator";

// --- Secrets and Constants ---
const groqApiKey = defineSecret("GROQ_API_KEY");
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

// ------------------------------------------------------------------
// 1. AI REPORT GENERATOR
// ------------------------------------------------------------------
/**
* Generates formal text from raw notes based on a given context.
* (e.g., 'problem_report', 'diagnostic', 'workDone')
*/
export const generateReportFromNotes = onCall(
{ secrets: [groqApiKey], region: "europe-west1" },
async (request) => {
    const rawNotes = request.data.rawNotes as string;
    const context = request.data.context as string | undefined;

    if (!rawNotes || rawNotes.trim().length === 0) {
      functions.logger.error("No rawNotes provided.");
      throw new HttpsError("invalid-argument", "The function must be called with 'rawNotes'.");
    }

    const modelId = "llama-3.1-8b-instant";

    const businessContext = `
      **CONTEXTE IMPORTANT:**
      - "Boitex Info" est une société spécialisée dans les systèmes de sécurité pour **magasins (retail)**.
      - Le terme "antivol" ou "anti vol" fait référence à des **systèmes de sécurité pour magasins** (portiques antivol, anti-vol à l'étalage, antivol textile).
      - **NE PAS** l'associer à des voitures ou des véhicules.
    `;

    let systemPrompt = "";
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
// 2. ON-DEMAND PDF EXPORTER
// ------------------------------------------------------------------
/**
 * Generates an intervention PDF on demand and returns it as a Base64 string.
 * Called from the intervention details page in the app.
 */
export const exportInterventionPdf = onCall(
  { secrets: [/* Add SMTP/B2 secrets if pdf-generator needs them */], region: "europe-west1" },
  async (request) => {
    const interventionId = request.data.interventionId as string;

    if (!interventionId) {
      functions.logger.error("No interventionId provided.");
      throw new HttpsError("invalid-argument", "The function must be called with an 'interventionId'.");
    }

    try {
      // 1. Fetch the intervention data
      const doc = await admin.firestore()
        .collection("interventions")
        .doc(interventionId)
        .get();

      if (!doc.exists) {
        functions.logger.error(`Intervention not found: ${interventionId}`);
        throw new HttpsError("not-found", "Intervention document not found.");
      }

      const interventionData = doc.data();

      // 2. Call your EXISTING PDF generator
      functions.logger.info(`Generating PDF for ${interventionId}...`);
      const pdfBuffer = await generateInterventionPdf(interventionData);
      functions.logger.info("✅ PDF generated successfully.");

      // 3. Return the PDF as a Base64 string
      return {
        pdfBase64: pdfBuffer.toString("base64"),
      };

    } catch (error) {
      functions.logger.error(`❌ Failed to generate PDF for ${interventionId}:`, error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Failed to generate PDF.", error);
    }
  }
);

// ------------------------------------------------------------------
// 3. SAV PDF DOWNLOADER (Universal)
// ------------------------------------------------------------------
/**
 * Generates a SAV Ticket PDF (Décharge or Restitution) on demand
 * and returns it as a Base64 string for mobile download.
 */
export const downloadSavPdf = onCall(
  { region: "europe-west1" },
  async (request) => {
    const { ticketId, type } = request.data;

    // 1. Validation
    if (!ticketId || !type) {
      throw new HttpsError("invalid-argument", "Missing ticketId or type (deposit/return).");
    }

    // 2. Fetch Ticket Data
    const docRef = admin.firestore().collection("sav_tickets").doc(ticketId);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw new HttpsError("not-found", "Ticket not found.");
    }

    const data = docSnap.data();

    try {
      let pdfBuffer: Buffer;

      // 3. Generate Requested PDF
      if (type === "deposit") {
        pdfBuffer = await generateSavDechargePdf(data);
      } else if (type === "return") {
        // Check if actually returned
        if (data?.status !== "Retourné") {
          throw new HttpsError("failed-precondition", "Cannot download return receipt: Ticket is not closed/returned.");
        }
        pdfBuffer = await generateSavReturnPdf(data);
      } else {
        throw new HttpsError("invalid-argument", "Invalid PDF type.");
      }

      // 4. Return as Base64 (Standard for mobile file transfer)
      return {
        filename: `SAV-${data?.savCode}-${type}.pdf`,
        pdfBase64: pdfBuffer.toString("base64"),
      };

    } catch (error) {
      functions.logger.error("PDF Generation Error", error);
      throw new HttpsError("internal", "Failed to generate PDF.");
    }
  }
);