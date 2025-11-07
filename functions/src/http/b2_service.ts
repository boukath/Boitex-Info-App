// functions/src/http/b2_service.ts

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger"; // ⭐️ Use v2 logger
import B2 from "backblaze-b2";
// ⭐️ --- REMOVED: We no longer need uuid ---
// import {v4 as uuidv4} from "uuid";

// ⭐️ --- MODIFICATION: Import the secrets AND their definitions ---
import {
b2Secrets,
backblazeKeyId,
backblazeAppKey,
backblazeBucketId,
} from "../services/b2_upload_service";

/**
* A callable function that gives the app a secure, one-time URL
* to upload a file directly to Backblaze B2.
*/
export const getB2UploadUrl = onCall(
{ secrets: b2Secrets, region: "europe-west1" }, // ⭐️ Set region
async (request) => {

    // ⭐️ --- ADDED: Get data from the app ---
    const { interventionId, interventionCode } = request.data;
    if (!interventionId || !interventionCode) {
      throw new HttpsError(
        "invalid-argument",
        "Missing 'interventionId' or 'interventionCode' in request data."
      );
    }

    // 1. Authorize B2
    const b2 = new B2({
      // ⭐️ --- MODIFICATION: Use the v2 .value() method ---
      applicationKeyId: backblazeKeyId.value(),
      applicationKey: backblazeAppKey.value(),
    });

    // ⭐️ --- MODIFICATION: Use the v2 .value() method ---
    const bucketId = backblazeBucketId.value();

    if (!bucketId) {
      throw new HttpsError("internal", "Backblaze Bucket ID is not configured.");
    }

    logger.info("B2 Authorized, getting upload URL...");

    try {
      // 2. Get a temporary upload URL from B2
      const authResponse = await b2.authorize(); // ⭐️ Authorize is needed first
      const { downloadUrl } = authResponse.data;
      const uploadUrlResponse = await b2.getUploadUrl({ bucketId });
      const { uploadUrl, authorizationToken } = uploadUrlResponse.data;

      // 3. Create a unique file name for this report
      // ⭐️ --- MODIFICATION: Use intervention code/ID for a stable name ---
      const safeCode = (interventionCode as string).replace(/\//g, "-");
      const b2FileName = `interventions_reports/${safeCode}_${interventionId}.pdf`;

      // 4. Construct the final, public-facing URL
      const bucketName = "BoitexInfo"; // ⭐️ Make sure this is your public bucket name!
      const publicPdfUrl = `${downloadUrl}/file/${bucketName}/${b2FileName}`;

      logger.info(`Providing app with upload URL for: ${b2FileName}`);

      // 5. Send all the necessary info back to the Flutter app
      return {
        uploadUrl: uploadUrl,
        authorizationToken: authorizationToken,
        b2FileName: b2FileName, // The app MUST use this file name
        publicPdfUrl: publicPdfUrl, // The app will save this to Firestore
      };

    } catch (error) {
      logger.error("Error getting B2 upload URL:", error);
      throw new HttpsError("internal", "Failed to get B2 upload URL.");
    }
  }
);