// functions/src/email-utils.ts

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

export interface EmailSettings {
intervention_cc_tech: string[];
intervention_cc_it: string[];

// ✅ CHANGED: Split SAV into two specific lists
sav_cc_tech: string[];
sav_cc_it: string[];

installation_cc_tech: string[];
installation_cc_it: string[];
}

/**
* Fetches the dynamic email configuration from Firestore.
* Returns default empty arrays if the document doesn't exist.
*/
export async function getEmailSettings(): Promise<EmailSettings> {
  try {
    const doc = await admin.firestore().collection("settings").doc("email_config").get();

    if (doc.exists && doc.data()) {
      const data = doc.data() as any;
      return {
        intervention_cc_tech: data.intervention_cc_tech || [],
        intervention_cc_it: data.intervention_cc_it || [],

        // ✅ NEW: Fetch the split SAV lists
        sav_cc_tech: data.sav_cc_tech || [],
        sav_cc_it: data.sav_cc_it || [],

        installation_cc_tech: data.installation_cc_tech || [],
        installation_cc_it: data.installation_cc_it || [],
      };
    }
  } catch (error) {
    logger.error("❌ Error fetching email settings from Firestore:", error);
  }

  // Fallback defaults if DB fails or is empty
  return {
    intervention_cc_tech: [],
    intervention_cc_it: [],
    sav_cc_tech: [],
    sav_cc_it: [],
    installation_cc_tech: [],
    installation_cc_it: [],
  };
}