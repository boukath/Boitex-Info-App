// functions/src/http/b2_service.ts

import * as functions from "firebase-functions";
import B2 from "backblaze-b2";
import cors from "cors";
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";

// ✅ --- ADDED: Define secrets here ---
const backblazeKeyId = defineSecret("BACKBLAZE_KEY_ID");
const backblazeAppKey = defineSecret("BACKBLAZE_APP_KEY");
const backblazeBucketId = defineSecret("BACKBLAZE_BUCKET_ID");

// ✅ --- ADDED: Create CORS handler here ---
const corsHandler = cors({origin: true});

//
// ⭐️ ----- NEW FILE ----- ⭐️
//
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