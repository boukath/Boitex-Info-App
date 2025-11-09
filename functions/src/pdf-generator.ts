// functions/src/pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios"; // To fetch images
import * as logger from "firebase-functions/logger"; // For logging errors

// --- 1. YOUR LOGO URL ---
//
// 🔴 IMPORTANT: For this design, you need a WHITE or transparent logo.
// Your current blue logo will not look good on the blue header.
// Please upload a white version of your logo and paste the URL here.
//
const LOGO_URL_WHITE = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png"; // <-- PASTE YOUR WHITE LOGO URL HERE
//
// If you only have the blue logo, use this URL and I will place it on a white header.
// const LOGO_URL_BLUE = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";


// --- Design Constants (Modern, Pro) ---
const BRAND_COLOR = "#0D47A1"; // Your deep blue
const HEADER_TEXT_COLOR = "#FFFFFF"; // White
const TITLE_COLOR = "#000000"; // Pure black for strong titles
const TEXT_COLOR = "#333333"; // Dark gray for content
const LABEL_COLOR = "#666666"; // Lighter gray for labels
const LIGHT_GRAY_BACKGROUND = "#F7F9FA"; // Very light gray for "cards"
const LINE_COLOR = "#E0E0E0"; // Light divider line
const MARGIN = 40; // A bit less margin for a more "full-page" feel

/**
* Fetches an image from a URL and returns it as a Buffer.
*/
async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || !url.startsWith("http")) {
    logger.warn(`Invalid image URL: ${url}`);
    return null;
  }
  try {
    const response = await axios.get(url, {
      responseType: "arraybuffer",
    });
    return response.data;
  } catch (error) {
    logger.error(`❌ Error fetching image at ${url}:`, error);
    return null;
  }
}

// ✅ --- FIX ---
// Removed the unused 'formatDate' function
// ✅ --- END FIX ---

/**
 * ✅ --- NEW: MODERN HEADER ---
 * Draws a full-width blue bar with the logo and title.
 */
async function _buildHeader(doc: PDFKit.PDFDocument, logoBuffer: Buffer | null) {
  // Full-width blue rectangle
  doc
    .rect(0, 0, doc.page.width, 100) // 100 points high
    .fillColor(BRAND_COLOR)
    .fill();

  // Draw the WHITE logo on the left
  if (logoBuffer) {
    doc.image(logoBuffer, MARGIN, 25, { // Vertically centered
      height: 50, // Fixed height
    });
  }

  // Draw the title on the right
  doc
    .font("Helvetica-Bold")
    .fontSize(18)
    .fillColor(HEADER_TEXT_COLOR)
    .text(
      "RAPPORT D'INTERVENTION",
      doc.page.width - MARGIN - 250, // Align right
      40, // Vertically centered
      {
        width: 250,
        align: "right",
      }
    );

  // Set Y cursor for the content, well below the header
  doc.y = 130;
}

/**
 * ✅ --- NEW: CLIENT INFO SECTION ---
 * A clean, two-column layout for client details.
 */
function _buildClientInfo(doc: PDFKit.PDFDocument, data: any) {
  const col1X = MARGIN;
  const col2X = doc.page.width / 2 + 30; // 60px gutter
  const colWidth = doc.page.width / 2 - MARGIN - 30;

  doc.font("Helvetica").fontSize(10);

  // A helper to draw a labeled field
  const drawField = (label: string, value: string, x: number, y: number) => {
    doc
      .font("Helvetica-Bold")
      .fillColor(LABEL_COLOR)
      .text(label, x, y, { width: colWidth });

    doc
      .font("Helvetica")
      .fillColor(TEXT_COLOR)
      .text(value || "N/A", { width: colWidth });

    doc.moveDown(0.5);
  };

  const startY = doc.y;

  // --- Column 1 ---
  drawField("Client", data.clientName, col1X, startY);
  drawField("Magasin", `${data.storeName || "N/A"} - ${data.storeLocation || ""}`, col1X, doc.y);

  // --- Column 2 ---
  drawField("Code Intervention", data.interventionCode, col2X, startY);
  drawField("Contact sur Site", `${data.managerName || "N/A"} (${data.managerPhone || ""})`, col2X, doc.y);

  // Set Y to below the *taller* of the two columns
  doc.y = Math.max(doc.y, startY + 50); // Ensure a minimum height
  doc.moveDown(2); // Add space after the section
}

/**
 * ✅ --- NEW: TECHNICAL REPORT SECTION ---
 * A clean "card" for all technical text.
 */
function _buildTechnicalReport(doc: PDFKit.PDFDocument, data: any) {
  const startY = doc.y;

  // --- Draw text first to measure height ---
  const tempY = doc.y; // Save Y pos

  // Helper to draw a text block
  const drawTextBlock = (label: string, text: string) => {
    doc
      .font("Helvetica-Bold")
      .fontSize(12)
      .fillColor(TITLE_COLOR)
      .text(label, { lineGap: 5 }); // More space after label

    doc
      .font("Helvetica")
      .fontSize(10)
      .fillColor(TEXT_COLOR)
      .text(text || "Non spécifié", {
        width: doc.page.width - MARGIN * 2 - 40, // 20px padding
      });
    doc.moveDown(1.5); // More space between blocks
  };

  doc.y = tempY + 20; // 20px top padding
  drawTextBlock("Problème Rapporté (Client)", data.requestDescription);
  drawTextBlock("Diagnostic (Technicien)", data.diagnostic);
  drawTextBlock("Travaux Effectués", data.workDone);

  const endY = doc.y;

  // --- Draw the gray "card" background ---
  doc
    .rect(MARGIN, startY, doc.page.width - MARGIN * 2, endY - startY + 10)
    .fillColor(LIGHT_GRAY_BACKGROUND)
    .fill();

  // --- Redraw the text ON TOP of the card ---
  doc.y = tempY + 20; // 20px top padding
  doc.x = MARGIN + 20; // 20px left padding

  drawTextBlock("Problème Rapporté (Client)", data.requestDescription);
  drawTextBlock("Diagnostic (Technicien)", data.diagnostic);
  drawTextBlock("Travaux Effectués", data.workDone);

  // Set Y cursor for next section
  doc.y = endY + 20;
}

/**
 * ✅ --- NEW: VALIDATION SECTION ---
 * A two-column section for technicians and the signature.
 */
async function _buildValidationSection(doc: PDFKit.PDFDocument, data: any, signatureBuffer: Buffer | null) {
  doc.moveDown(2); // Add space

  const startY = doc.y;
  const col1X = MARGIN;
  const col2X = doc.page.width / 2 + 30;

  // --- Column 1: Technicians ---
  doc
    .font("Helvetica-Bold")
    .fontSize(12)
    .fillColor(TITLE_COLOR)
    .text("Intervenants", col1X, startY);

  const techs: string[] = data.assignedTechnicians || [];
  if (techs.length > 0) {
    techs.forEach((tech) => {
      doc
        .font("Helvetica")
        .fontSize(10)
        .fillColor(TEXT_COLOR)
        .text(`• ${tech}`, { lineGap: 3 });
    });
  } else {
    doc
      .font("Helvetica-Oblique")
      .fontSize(10)
      .fillColor(LABEL_COLOR)
      .text("Non spécifié", { lineGap: 3 });
  }
  const techSectionEndY = doc.y;

  // --- Column 2: Signature ---
  doc
    .font("Helvetica-Bold")
    .fontSize(12)
    .fillColor(TITLE_COLOR)
    .text("Validation Client", col2X, startY);

  const sigBoxWidth = doc.page.width / 2 - MARGIN - 30;
  const sigBoxHeight = 100;
  const sigBoxY = startY + 25;

  // Draw the signature box
  doc
    .rect(col2X, sigBoxY, sigBoxWidth, sigBoxHeight)
    .lineWidth(0.5)
    .strokeColor(LINE_COLOR)
    .stroke();

  if (signatureBuffer) {
    // Fit the signature inside the box
    doc.image(signatureBuffer, col2X, sigBoxY, {
      fit: [sigBoxWidth, sigBoxHeight],
      align: "center",
      valign: "center",
    });
  } else {
    // No signature
    doc
      .font("Helvetica-Oblique")
      .fontSize(10)
      .fillColor(LABEL_COLOR)
      .text("Aucune signature client.", col2X + (sigBoxWidth / 2), sigBoxY + (sigBoxHeight / 2) - 5, {
        align: "center",
      });
  }

  // Client name (if available) under the box
  doc
    .font("Helvetica")
    .fontSize(9)
    .fillColor(LABEL_COLOR)
    .text(`Par: ${data.managerName || "N/A"}`, col2X, sigBoxY + sigBoxHeight + 5, {
      width: sigBoxWidth,
      align: "center",
    });

  // Ensure cursor is below both columns
  doc.y = Math.max(techSectionEndY, sigBoxY + sigBoxHeight + 25);
  doc.moveDown(2);
}

/**
 * ✅ --- NEW: MODERN FOOTER ---
 * A clean, single-line footer for every page.
 */
function _buildFooter(doc: PDFKit.PDFDocument) {
  const range = doc.bufferedPageRange();
  const pageCount = range.start + range.count;
  const footerY = doc.page.height - 35; // 35 points from bottom

  for (let i = range.start; i < pageCount; i++) {
    doc.switchToPage(i);

    // --- Thin Line Separator ---
    doc
      .save()
      .moveTo(MARGIN, footerY)
      .lineTo(doc.page.width - MARGIN, footerY)
      .lineWidth(0.5)
      .strokeColor(LINE_COLOR)
      .stroke()
      .restore();

    // --- Contact Info ---
    const contactInfo = "www.boitexinfo.com | commercial@boitexinfo.com | +213 560 367 256";
    doc
      .font("Helvetica")
      .fontSize(8)
      .fillColor(LABEL_COLOR)
      .text(contactInfo, MARGIN, footerY + 10, {
        align: "left",
      });

    // --- Page Number ---
    doc
      .font("Helvetica")
      .fontSize(8)
      .fillColor(LABEL_COLOR)
      .text(
        `Page ${i + 1} / ${pageCount}`,
        doc.page.width - MARGIN - 50, // Align right
        footerY + 10,
        {
          width: 50,
          align: "right",
        }
      );
  }
}

/**
 * The main function to generate the intervention PDF.
 */
export async function generateInterventionPdf(data: any): Promise<Buffer> {
  const doc = new PDFDocument({
    size: "A4",
    margins: { top: 0, bottom: 0, left: 0, right: 0 }, // We control all margins
    bufferPages: true,
  });

  const buffers: Buffer[] = [];
  doc.on("data", buffers.push.bind(buffers));

  // --- 1. Fetch Images ---
  // 🔴 Use the new WHITE logo URL
  const logoBuffer = await fetchImage(LOGO_URL_WHITE);
  const signatureBuffer = await fetchImage(data.signatureUrl);

  // --- 2. Build PDF Header ---
  await _buildHeader(doc, logoBuffer);

  // --- 3. Build PDF Body ---
  // We set the horizontal margins for the body content here
  doc.x = MARGIN;
  _buildClientInfo(doc, data);

  // Draw a thin divider line
  doc
    .save()
    .moveTo(MARGIN, doc.y)
    .lineTo(doc.page.width - MARGIN, doc.y)
    .lineWidth(0.5)
    .strokeColor(LINE_COLOR)
    .stroke()
    .restore();
  doc.moveDown(2);

  _buildTechnicalReport(doc, data);
  await _buildValidationSection(doc, data, signatureBuffer);

  // --- 4. Build PDF Footer ---
  _buildFooter(doc);

  // --- Finalize and return the PDF Buffer ---
  return new Promise((resolve, reject) => {
    doc.on("end", () => {
      const pdfData = Buffer.concat(buffers);
      resolve(pdfData);
    });

    doc.on("error", (err: any) => {
      logger.error("❌ Erreur lors de la génération du PDF:", err);
      reject(err);
    });
    doc.end();
  });
}