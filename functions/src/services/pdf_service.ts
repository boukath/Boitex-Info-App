// functions/src/services/pdf_service.ts

// ✅ FIX 1: Change the import style for pdfkit
import PDFDocument from "pdfkit";


/**
* Fetches a network image (like from Backblaze) and returns it as a Buffer.
* This is crucial for embedding images into the PDF.
*/
// ✅ FIX 2: Comment out this unused function for now to pass deployment.
// We will uncomment this later when we build the full PDF.
/*
const getNetworkImage = async (url: string): Promise<Buffer> => {
try {
const response = await axios.get(url, {
responseType: "arraybuffer", // Get the raw image data
});
return Buffer.from(response.data, "binary");
} catch (error) {
console.error(`❌ Error fetching network image: ${url}`, error);
throw new Error(`Failed to fetch image: ${url}`);
}
};
*/

/**
* Generates the intervention PDF report.
* This function will re-create the logic from your Dart service.
*
* @param {any} data The intervention document data.
* @returns {Promise<Buffer>} A promise that resolves with the PDF as a Buffer.
*/
export const generateInterventionPdf = (data: any): Promise<Buffer> => {
return new Promise(async (resolve, reject) => {
    try {
      // ✅ This 'new PDFDocument()' line will now work correctly
      const doc = new PDFDocument({
        size: "A4",
        margin: 50,
        // Set up fonts, etc.
      });

      // --- We will build the PDF layout here, section by section ---

      // 1. HEADER (Logo + Title)
      // Example: Load your logo from its Backblaze URL
      // const logoUrl = "https://your-backblaze-url/assets/boitex_logo.png";
      // const logoBuffer = await getNetworkImage(logoUrl);
      // doc.image(logoBuffer, { width: 150 });

      doc.fontSize(20).text("Rapport d'Intervention", { align: "center" });
      doc.moveDown();

      // 2. CLIENT INFO
      doc.fontSize(12).text(`Client: ${data.clientName || "N/A"}`);
      doc.text(`Magasin: ${data.storeName || "N/A"}`);
      // ... (add more fields from your Dart file)

      // 3. SIGNATURE
      // Example: Load the client's signature from its Backblaze URL
      if (data.clientSignatureUrl) {
        doc.moveDown(2);
        doc.text("Signature Client:", { underline: true });
        // const sigBuffer = await getNetworkImage(data.clientSignatureUrl);
        // doc.image(sigBuffer, { width: 200, align: "center" });
      }

      // --- End of PDF layout ---


      // Finalize the PDF and convert it to a Buffer
      const buffers: Buffer[] = [];
      doc.on("data", buffers.push.bind(buffers));
      doc.on("end", () => {
        const pdfData = Buffer.concat(buffers);
        console.log("✅ PDF generated successfully in memory.");
        resolve(pdfData);
      });
      doc.end();

    } catch (error) {
      console.error("❌ Error generating PDF:", error);
      reject(error);
    }
  });
};