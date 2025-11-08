// functions/src/intervention-handlers.ts

import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger"; // ✅ THIS IS THE FIX
import * as nodemailer from "nodemailer";
import {defineSecret} from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";

// --- 1. Define the secrets we just set ---
const smtpHost = defineSecret("SMTP_HOST");
const smtpPort = defineSecret("SMTP_PORT");
const smtpUser = defineSecret("SMTP_USER");
const smtpPassword = defineSecret("SMTP_PASSWORD");

/**
* Validates if a string is a plausible email address.
* @param {string} email The email string to test.
* @return {boolean} True if it looks like an email, false otherwise.
*/
function isValidEmail(email: string): boolean {
  if (!email || typeof email !== "string") {
    return false;
  }
  // A simple regex for email validation.
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// --- 2. Create the function trigger ---
export const onInterventionTermine = onDocumentUpdated(
  {
    document: "interventions/{interventionId}",
    region: "europe-west1", // Matching your project's region
    secrets: [smtpHost, smtpPort, smtpUser, smtpPassword],
  },
  async (event) => {
    // --- 3. Get the data before and after the change ---
    if (!event.data) {
      logger.log("No data found in event, exiting.");
      return;
    }

    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // --- 4. Get specific data fields ---
    const statusBefore = beforeData?.status;
    const statusAfter = afterData?.status;
    const interventionCode = afterData?.interventionCode || "N/A";

    logger.log(`Processing update for intervention: ${interventionCode}`);

    // --- 5. Status Check Logic ---
    // We only proceed if the status was *not* "Terminé" before
    // AND it *is* "Terminé" now.
    if (statusBefore === "Terminé" && statusAfter === "Terminé") {
      logger.log("Status was already 'Terminé', no email needed.");
      return;
    }

    if (statusAfter !== "Terminé") {
      logger.log(`Status changed to '${statusAfter}', not 'Terminé'. No email needed.`);
      return;
    }

    logger.log("Status changed to 'Terminé'. Preparing to send email...");

    // --- 6. Email Validation Logic ---
    const managerEmail = afterData?.managerEmail;

    if (!isValidEmail(managerEmail)) {
      logger.warn(
        `Invalid or missing managerEmail: '${managerEmail}'. Cannot send email.`
      );
      // We don't throw an error, as the function did its job
      // but the data was just missing.
      return;
    }

    logger.log(`Valid recipient email found: ${managerEmail}`);

    // --- 7. Configure Nodemailer (SMTP Transporter) ---
    // We create the 'transporter' object that will send the email
    const transporter = nodemailer.createTransport({
      host: smtpHost.value(),
      port: parseInt(smtpPort.value(), 10), // Convert port string to number
      secure: parseInt(smtpPort.value(), 10) === 465, // `true` if port is 465 (SSL)
      auth: {
        user: smtpUser.value(),
        pass: smtpPassword.value(),
      },
    });

    // --- 8. Define Email Content ---
    // Here you can customize the email subject and body.
    const subject = `Intervention Terminée: ${interventionCode}`;
    const body = `
      <p>Bonjour,</p>

      <p>L'intervention <strong>${interventionCode}</strong>
      concernant le client <strong>${afterData?.clientName || "N/A"}</strong>
      au magasin <strong>${afterData?.storeName || "N/A"}</strong>
      est maintenant terminée.</p>

      <p><strong>Diagnostique:</strong><br/>
      ${afterData?.diagnostic || "Non spécifié"}</p>

      <p><strong>Travaux Effectués:</strong><br/>
      ${afterData?.workDone || "Non spécifié"}</p>

      <p>Cordialement,<br/>
      Le Service Technique Boitex Info</p>
    `;

    const mailOptions = {
      from: `"Boitex Info Service Technique" <${smtpUser.value()}>`,
      to: managerEmail, // The email from the form field
      subject: subject,
      html: body,
    };

    // --- 9. Send the Email ---
    try {
      await transporter.sendMail(mailOptions);
      logger.log(`✅ Email successfully sent to ${managerEmail}`);
      return;
    } catch (error) {
      logger.error(`❌ Failed to send email to ${managerEmail}:`, error);
      // We re-throw the error here so Firebase knows the function failed
      // and can retry if necessary.
      throw new HttpsError(
        "internal",
        "Failed to send email.",
        error
      );
    }
  }
);