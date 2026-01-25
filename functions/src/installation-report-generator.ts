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
      // 2. Fetch Installation Data
      const installationSnap = await installationRef.get();
      if (!installationSnap.exists) {
        throw new HttpsError("not-found", "Installation not found");
      }
      const installationData = installationSnap.data();

      // 3. Fetch Daily Logs
      const logsSnap = await installationRef
        .collection("daily_logs")
        .orderBy("timestamp", "asc")
        .get();

      // Handle case with no logs
      if (logsSnap.empty) {
        // Update notes so the user sees something
        await installationRef.update({
          notes: "Aucun journal d'activité trouvé pour générer un rapport.",
          mediaUrls: [],
        });
        return { success: true, summary: "Pas de logs." };
      }

      // 4. Prepare Context & Aggregate Media
      let logsText = "";
      let allMediaUrls: string[] = []; // <--- 🆕 Container for all photos/videos

      logsSnap.docs.forEach((doc, index) => {
        const log = doc.data();
        const date = log.timestamp?.toDate().toLocaleDateString("fr-FR") || "Date inconnue";
        const tech = log.technicianName || "Technicien";
        const type = log.type === "blockage" ? "[BLOQUANT]" : "";

        // Build Text for AI
        logsText += `\n--- Log #${index + 1} (${date}) ---\n`;
        logsText += `Auteur: ${tech}\n`;
        logsText += `Type: ${log.type} ${type}\n`;
        logsText += `Note: ${log.description}\n`;

        // 🆕 Collect Media URLs from this specific log
        if (log.mediaUrls && Array.isArray(log.mediaUrls)) {
          allMediaUrls = [...allMediaUrls, ...log.mediaUrls];
        }
      });

      const clientName = installationData?.clientName || "Client";
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

      // 6. Save Draft & Media (DO NOT CLOSE TICKET YET)
      // ✅ FIX: We now write to 'notes' and 'mediaUrls' so the App sees them immediately.
      await installationRef.update({
        notes: summary,           // Was 'completionSummary'
        mediaUrls: allMediaUrls,  // Was 'finalReportMedia'
        // status: "Terminée",    <--- REMOVED (App handles this after signature)
      });

      return { success: true, summary: summary };

    } catch (error) {
      console.error("Error generating report:", error);
      throw new HttpsError("internal", "Failed to generate report");
    }
  }
);