// functions/src/pdf-generator.ts

// ✅ --- FIX #2 ---
// Import PDFDocument as the default export
import PDFDocument from "pdfkit";
// ✅ --- END FIX ---

import axios from "axios"; // To fetch images
import * as logger from "firebase-functions/logger"; // For logging errors

// --- 1. YOUR LOGO URL ---
const LOGO_URL = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";

// --- Design Constants (from your sample PDF) ---
const BRAND_COLOR = "#0D47A1"; // Dark blue
const TEXT_COLOR = "#333333"; // Dark gray, not pure black
const LIGHT_TEXT_COLOR = "#666666";
const LIGHT_GRAY_BACKGROUND = "#F5F5F5";
const MARGIN = 50;

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

/**
 * Helper function to format Firestore Timestamps or dates.
 */
function formatDate(timestamp: any, format = "long"): string {
  if (!timestamp) return "N/A";
  let date: Date;
  if (timestamp && typeof timestamp.toDate === "function") {
    date = timestamp.toDate();
  } else if (timestamp instanceof Date) {
    date = timestamp;
  } else {
    date = new Date(timestamp);
    if (isNaN(date.getTime())) return "Date Invalide";
  }

  if (format === "long") {
    return new Intl.DateTimeFormat("fr-FR", {
      day: "2-digit",
      month: "long",
      year: "numeric",
    }).format(date);
  } else {
    // Short format for footer
    return new Intl.DateTimeFormat("fr-FR", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(date);
  }
}

/**
 * Generic function to draw a section title (e.g., "Détails du Client")
 */
function _buildSectionTitle(doc: PDFKit.PDFDocument, title: string) {
  doc
    .font("Helvetica-Bold")
    .fontSize(12)
    .fillColor(BRAND_COLOR)
    .text(title);

  // Add a light gray underline
  doc
    .save()
    .moveTo(doc.x, doc.y + 2)
    .lineTo(doc.page.width - MARGIN, doc.y + 2)
    .lineWidth(0.5)
    .strokeColor("#DDDDDD")
    .stroke()
    .restore();

  doc.moveDown(0.75); // Space after title
}

// ✅ --- FIX #1 ---
// Removed the unused _buildInfoRow function
// ✅ --- END FIX ---

/**
 * Builds the header section with logo and titles.
 */
async function _buildHeader(doc: PDFKit.PDFDocument, data: any, logoBuffer: Buffer | null) {
  // --- Logo ---
  if (logoBuffer) {
    doc.image(logoBuffer, MARGIN, MARGIN - 20, {
      width: 100,
    });
  }

  // --- "BOITEXINFO Service Technique" ---
  doc
    .font("Helvetica-Bold")
    .fontSize(10)
    .fillColor(LIGHT_TEXT_COLOR)
    .text("BOITEXINFO Service Technique", MARGIN, MARGIN + 25, {
      align: "left",
    });

  // --- Blue Line Separator ---
  doc
    .save()
    .moveTo(MARGIN, MARGIN + 45)
    .lineTo(doc.page.width - MARGIN, MARGIN + 45)
    .lineWidth(2)
    .strokeColor(BRAND_COLOR)
    .stroke()
    .restore();

  // --- Main Title: RAPPORT D'INTERVENTION ---
  doc
    .font("Helvetica-Bold")
    .fontSize(18)
    .fillColor(BRAND_COLOR)
    .text("RAPPORT D'INTERVENTION", MARGIN, MARGIN + 60, {
      align: "left",
    });

  // --- Intervention Code ---
  doc
    .font("Helvetica-Bold")
    .fontSize(18)
    .fillColor(TEXT_COLOR)
    .text(data.interventionCode || "N/A", MARGIN, MARGIN + 60, {
      align: "right",
    });

  // --- Subtitle: Date | Client Name ---
  const creationDate = formatDate(data.createdAt);
  const clientName = data.clientName || "N/A";
  doc
    .font("Helvetica")
    .fontSize(10)
    .fillColor(LIGHT_TEXT_COLOR)
    .text(`${creationDate} | ${clientName}`, MARGIN, MARGIN + 85, {
      align: "left",
    });

  doc.moveDown(6);
}

/**
 * Builds the Client Details section
 */
function _buildDetailsSection(doc: PDFKit.PDFDocument, data: any) {
  _buildSectionTitle(doc, "Détails du Client et de l'Intervention");

  const storeLocation = data.storeLocation || "N/A";
  const storeName = data.storeName || "N/A";

  // Use a two-column layout
  const col1X = MARGIN;
  const col2X = doc.page.width / 2 + 10;
  const colWidth = doc.page.width / 2 - MARGIN - 10;
  const startY = doc.y;

  // --- Column 1 ---
  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Nom du client", col1X, startY)
    .font("Helvetica")
    .fillColor(LIGHT_TEXT_COLOR)
    .text(data.clientName || "N/A", { width: colWidth });

  doc.moveDown(1);
  const col1Y2 = doc.y;
  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Magasin", col1X, col1Y2)
    .font("Helvetica")
    .fillColor(LIGHT_TEXT_COLOR)
    .text(`${storeName} - ${storeLocation}`, { width: colWidth });

  // --- Column 2 ---
  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Service", col2X, startY)
    .font("Helvetica")
    .fillColor(LIGHT_TEXT_COLOR)
    .text(data.serviceType || "Service Technique", { width: colWidth });

  doc.moveDown(1);
  const col2Y2 = doc.y;
  const contactName = data.managerName || "N/A";
  const contactPhone = data.managerPhone || "";
  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Contact sur site", col2X, col1Y2) // Align with "Magasin"
    .font("Helvetica")
    .fillColor(LIGHT_TEXT_COLOR)
    .text(`${contactName} (${contactPhone})`, { width: colWidth });

  // Ensure we move below the tallest column
  doc.y = Math.max(doc.y, col2Y2);

  doc.moveDown(2); // Space after section
}

/**
 * Builds the Analysis & Solution section
 */
function _buildAnalysisSection(doc: PDFKit.PDFDocument, data: any) {
  _buildSectionTitle(doc, "Analyse et Solution Technique");

  // Helper to draw a text block with a label
  const drawTextBlock = (label: string, text: string) => {
    doc
      .font("Helvetica-Bold")
      .fontSize(9)
      .fillColor(TEXT_COLOR)
      .text(label, { continued: true })
      .font("Helvetica")
      .fillColor(LIGHT_TEXT_COLOR)
      .text(text || "Non spécifié");
    doc.moveDown(1);
  };

  // Create a light gray background box for this section
  const startY = doc.y;

  drawTextBlock("Rapport de Problème (Client):", data.requestDescription);
  drawTextBlock("Diagnostique (Technicien):", data.diagnostic);
  drawTextBlock("Travaux Effectués:", data.workDone);

  const endY = doc.y;

  // Draw the gray box behind the text
  doc
    .rect(MARGIN, startY - 10, doc.page.width - MARGIN * 2, endY - startY + 10)
    .fillColor(LIGHT_GRAY_BACKGROUND)
    .fill();

  // Redraw the text *on top* of the box
  let textY = startY;

  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Rapport de Problème (Client):", MARGIN + 10, textY, { continued: true })
    .font("Helvetica")
    .fillColor(LIGHT_TEXT_COLOR)
    .text(data.requestDescription || "Non spécifié", {
      width: doc.page.width - MARGIN * 2 - 20,
    });
  doc.moveDown(1);
  textY = doc.y;

  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Diagnostique (Technicien):", MARGIN + 10, textY, { continued: true })
    .font("Helvetica")
    .fillColor(LIGHT_TEXT_COLOR)
    .text(data.diagnostic || "Non spécifié", {
      width: doc.page.width - MARGIN * 2 - 20,
    });
  doc.moveDown(1);
  textY = doc.y;

  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Travaux Effectués:", MARGIN + 10, textY, { continued: true })
    .font("Helvetica")
    .fillColor(LIGHT_TEXT_COLOR)
    .text(data.workDone || "Non spécifié", {
      width: doc.page.width - MARGIN * 2 - 20,
    });

  doc.moveDown(2); // Space after section
}

/**
 * Builds the Validation & Signature section
 */
async function _buildValidationSection(doc: PDFKit.PDFDocument, data: any, signatureBuffer: Buffer | null) {
  _buildSectionTitle(doc, "Intervenants et Validation");

  const startY = doc.y;
  const col1X = MARGIN;
  const col2X = doc.page.width / 2 + 10;

  // --- Column 1: Technicians ---
  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Technicien(s) Intervenant(s):", col1X, startY);

  const techs: string[] = data.assignedTechnicians || ["N/A"];
  techs.forEach((tech) => {
    doc
      .font("Helvetica")
      .fontSize(9)
      .fillColor(LIGHT_TEXT_COLOR)
      .text(`- ${tech}`);
  });

  const techSectionEndY = doc.y;

  // --- Column 2: Signature ---
  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(TEXT_COLOR)
    .text("Signature Client:", col2X, startY);

  // Create a box for the signature
  const sigBoxWidth = 180;
  const sigBoxHeight = 80;
  doc
    .rect(col2X, startY + 15, sigBoxWidth, sigBoxHeight)
    .fillColor(LIGHT_GRAY_BACKGROUND)
    .fill();

  if (signatureBuffer) {
    // Signature image exists, fit it inside the box
    doc.image(signatureBuffer, col2X + 10, startY + 20, {
      fit: [sigBoxWidth - 20, sigBoxHeight - 10], // Fit within padding
      align: "center",
      valign: "center",
    });
  } else {
    // No signature
    doc
      .font("Helvetica-Oblique") // Italic
      .fontSize(9)
      .fillColor(LIGHT_TEXT_COLOR)
      .text("Aucune signature client fournie.", col2X, startY + 50, {
        width: sigBoxWidth,
        align: "center",
      });
  }

  // Ensure cursor is below both columns
  doc.y = Math.max(techSectionEndY, startY + sigBoxHeight + 20);
  doc.moveDown(2);
}

/**
 * Builds the footer on every page
 */
function _buildFooter(doc: PDFKit.PDFDocument) {
  const range = doc.bufferedPageRange();
  for (let i = range.start; i < range.start + range.count; i++) {
    doc.switchToPage(i);

    // --- Page Number ---
    doc
      .font("Helvetica")
      .fontSize(8)
      .fillColor(LIGHT_TEXT_COLOR)
      .text(
        `Page ${i + 1} sur ${range.count}`,
        MARGIN,
        doc.page.height - MARGIN + 20,
        { align: "right" }
      );

    // --- Blue Line Separator ---
    doc
      .save()
      .moveTo(MARGIN, doc.page.height - MARGIN + 10)
      .lineTo(doc.page.width - MARGIN, doc.page.height - MARGIN + 10)
      .lineWidth(2)
      .strokeColor(BRAND_COLOR)
      .stroke()
      .restore();

    // --- Contact Info ---
    const contactInfo = "commercial@boitexinfo.com | +213 560 367 256 | www.boitexinfo.com";
    doc
      .font("Helvetica")
      .fontSize(8)
      .fillColor(LIGHT_TEXT_COLOR)
      .text(contactInfo, MARGIN, doc.page.height - MARGIN + 20, {
        align: "left",
      });
  }
}

/**
 * The main function to generate the intervention PDF.
 * @param data The data from the 'intervention' Firestore document.
 * @returns A Promise that resolves with the PDF as a Buffer.
 */
export async function generateInterventionPdf(data: any): Promise<Buffer> {
  // ✅ --- FIX #2 ---
  // Call the imported 'PDFDocument' as a constructor
  const doc = new PDFDocument({
  // ✅ --- END FIX ---
    size: "A4",
    margins: { top: MARGIN, bottom: MARGIN + 40, left: MARGIN, right: MARGIN },
    bufferPages: true,
  });

  // This will hold the PDF data in memory
  const buffers: Buffer[] = [];
  doc.on("data", buffers.push.bind(buffers));

  // --- 1. Fetch Images ---
  const logoBuffer = await fetchImage(LOGO_URL);
  const signatureBuffer = await fetchImage(data.signatureUrl);

  // --- 2. Build PDF Header ---
  await _buildHeader(doc, data, logoBuffer);

  // --- 3. Build PDF Body ---
  _buildDetailsSection(doc, data);
  _buildAnalysisSection(doc, data);
  await _buildValidationSection(doc, data, signatureBuffer);

  // --- 4. Build PDF Footer ---
  _buildFooter(doc);

  // --- Finalize and return the PDF Buffer ---
  return new Promise((resolve, reject) => {
    doc.on("end", () => {
      const pdfData = Buffer.concat(buffers);
      resolve(pdfData);
    });

    // ✅ --- FIX #3 ---
    // Added 'any' type to the error parameter
    doc.on("error", (err: any) => {
    // ✅ --- END FIX ---
      logger.error("❌ Erreur lors de la génération du PDF:", err);
      reject(err);
    });
    doc.end();
  });
}