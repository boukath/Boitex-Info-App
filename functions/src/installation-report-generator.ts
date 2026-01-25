// functions/src/installation-report-generator.ts

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import Groq from "groq-sdk";

// 🔐 Define the Secret
const groqApiKey = defineSecret("GROQ_API_KEY");

// 🤖 Cloud Function: Generate Installation Report
export const generateInstallationReport = onCall(
{
region: "europe-west1",
secrets: [groqApiKey],
timeoutSeconds: 60,
},
async (request) => {
    // 1. Validation
    const installationId = request.data.installationId;
    if (!installationId) {
      throw new HttpsError("invalid-argument", "Missing installationId");
    }

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const db = admin.firestore();
    const installationRef = db.collection("installations").doc(installationId);

    try {
      // 3. Fetch Data
      const installationSnap = await installationRef.get();
      if (!installationSnap.exists) {
        throw new HttpsError("not-found", "Installation not found");
      }
      const installationData = installationSnap.data();

      const logsSnap = await installationRef
        .collection("daily_logs")
        .orderBy("timestamp", "asc")
        .get();

      if (logsSnap.empty) {
        await installationRef.update({
          status: "Terminée",
          completionSummary: "Installation clôturée sans journal d'activité.",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true, summary: "Clôture standard (pas de logs)." };
      }

      // 4. Prepare Context
      let logsText = "";
      logsSnap.docs.forEach((doc, index) => {
        const log = doc.data();
        const date = log.timestamp?.toDate().toLocaleDateString("fr-FR") || "Date inconnue";
        const tech = log.technicianName || "Technicien";
        const type = log.type === "blockage" ? "[BLOQUANT]" : "";

        logsText += `\n--- Log #${index + 1} (${date}) ---\n`;
        logsText += `Auteur: ${tech}\n`;
        logsText += `Type: ${log.type} ${type}\n`;
        logsText += `Note: ${log.description}\n`;
      });

      const clientName = installationData?.clientName || "Client";
      // ✅ FIX: Variable is now used in the prompt below
      const projectType = installationData?.serviceType || "Installation";

      // 5. Call Groq AI
      const groq = new Groq({ apiKey: groqApiKey.value() });

      const systemPrompt = `
        Tu es un expert technique chez "Boitex Info".
        Ta tâche est de rédiger un "Rapport de Fin de Chantier" pour une intervention de type "${projectType}" chez le client "${clientName}".

        Instructions:
        1. Lis les logs quotidiens ci-dessous.
        2. Synthétise-les en un paragraphe fluide et professionnel (en Français).
        3. Ignore le jargon trop familier et corrige les fautes.
        4. Mentionne explicitement si des blocages ont été résolus.
        5. Ne signe pas. Commence directement par "L'intervention a été réalisée..."
      `;

      const completion = await groq.chat.completions.create({
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `Voici les logs:\n${logsText}` },
        ],
        model: "llama-3.3-70b-versatile",
        temperature: 0.3,
      });

      const summary = completion.choices[0]?.message?.content || "Erreur de génération.";

      // 6. Save & Close
      await installationRef.update({
        status: "Terminée",
        completionSummary: summary,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, summary: summary };

    } catch (error) {
      console.error("Error generating report:", error);
      throw new HttpsError("internal", "Failed to generate report");
    }
  }
);