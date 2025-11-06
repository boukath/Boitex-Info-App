// functions/src/services/b2_upload_service.ts

import B2 from "backblaze-b2";
import {defineSecret} from "firebase-functions/params";

// 1. Define the secrets this file needs
const backblazeKeyId = defineSecret("BACKBLAZE_KEY_ID");
const backblazeAppKey = defineSecret("BACKBLAZE_APP_KEY");
const backblazeBucketId = defineSecret("BACKBLAZE_BUCKET_ID");

/**
* Uploads a file buffer (like a PDF) to Backblaze B2
* from the server.
*
* @param {Buffer} fileBuffer The raw file data.
* @param {string} fileName The desired path and filename (e.g., "reports/intervention-123.pdf").
* @returns {Promise<string>} A promise that resolves with the public download URL.
*/
export const uploadBufferToB2 = async (
fileBuffer: Buffer,
fileName: string
): Promise<string> => {
const b2 = new B2({
applicationKeyId: backblazeKeyId.value(),
    applicationKey: backblazeAppKey.value(),
  });

  try {
    // 1. Authorize B2
    const authResponse = await b2.authorize();
    const { downloadUrl, apiUrl } = authResponse.data;
    const bucketId = backblazeBucketId.value();

    // 2. Get a server-side upload URL
    const uploadUrlResponse = await b2.getUploadUrl({ bucketId });
    const { uploadUrl, authorizationToken } = uploadUrlResponse.data;

    // 3. Upload the file
    const uploadResponse = await b2.uploadFile({
      uploadUrl: uploadUrl,
      uploadAuthToken: authorizationToken,
      fileName: fileName,
      data: fileBuffer,
      mime: "application/pdf",
      axios: {
        baseURL: apiUrl, // Important: specify API URL
      },
    });

    // 4. Construct the public-facing download URL
    const bucketName = "BoitexInfo"; // As defined in your other B2 service
    const downloadUrlPrefix = `${downloadUrl}/file/${bucketName}/`;
    const finalUrl = `${downloadUrlPrefix}${uploadResponse.data.fileName}`;

    console.log(`✅ File uploaded successfully to B2: ${finalUrl}`);
    return finalUrl;

  } catch (error) {
    console.error("❌ Error uploading to B2:", error);
    throw new Error(`Failed to upload to B2: ${error}`);
  }
};

/**
 * Defines the secrets needed for the B2 service.
 */
export const b2Secrets = [
  backblazeKeyId,
  backblazeAppKey,
  backblazeBucketId,
];