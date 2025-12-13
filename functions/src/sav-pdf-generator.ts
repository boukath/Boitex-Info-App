// functions/src/sav-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";

// --- 1. CONSTANTS (Identical to Intervention PDF) ---
const LOGO_URL_WHITE = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
const WATERMARK_URL = "https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/cache+technique.png";

// --- Design Constants ---
const BRAND_COLOR = "#0D47A1"; // Deep blue
const HEADER_TEXT_COLOR = "#FFFFFF";
const TITLE_COLOR = "#000000";
const TEXT_COLOR = "#333333";
const LABEL_COLOR = "#666666";
const LIGHT_GRAY_BACKGROUND = "#F7F9FA";
const LINE_COLOR = "#E0E0E0";
const MARGIN = 40;

/**
* Fetches an image from a URL and returns it as a Buffer.
*/
async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || !url.startsWith("http")) {
    return null;
  }
  try {
    const response = await axios.get(url, { responseType: "arraybuffer" });
    return Buffer.from(response.data);
  } catch (error) {
    logger.error(`❌ Error fetching image at ${url}:`, error);
    return null;
  }
}

/**
 * Builds the Header (Reused layout, Custom Title)
 */
function _buildHeader(doc: PDFKit.PDFDocument, logoBuffer: Buffer | null, title: string) {
  // Full-width blue rectangle
  doc.rect(0, 0, doc.page.width, 100).fillColor(BRAND_COLOR).fill();

  // Draw Logo
  if (logoBuffer) {
    doc.image(logoBuffer, MARGIN, 25, { height: 50 });
  }

  // Draw Title
  doc
    .font("Helvetica-Bold")
    .fontSize(18)
    .fillColor(HEADER_TEXT_COLOR)
    .text(title, doc.page.width - MARGIN - 250, 40, {
      width: 250,
      align: "right",
    });

  doc.y = 130; // Reset Y cursor
}

/**
 * Section 1: Client & Store Manager Info
 * Layout: 2 Columns
 */
function _buildClientAndManagerInfo(doc: PDFKit.PDFDocument, data: any) {
  const col1X = MARGIN;
  const col2X = doc.page.width / 2 + 30;
  const colWidth = doc.page.width / 2 - MARGIN - 30;

  doc.font("Helvetica").fontSize(10);

  const drawField = (label: string, value: string, x: number, y: number) => {
    doc.font("Helvetica-Bold").fillColor(LABEL_COLOR).text(label, x, y, { width: colWidth });
    doc.font("Helvetica").fillColor(TEXT_COLOR).text(value || "N/A", { width: colWidth });
    doc.moveDown(0.5);
  };

  const startY = doc.y;

  // Format Date from Firestore Timestamp
  let dateStr = "N/A";
  if (data.createdAt && data.createdAt._seconds) {
    dateStr = new Date(data.createdAt._seconds * 1000).toLocaleDateString("fr-FR");
  } else if (data.createdAt instanceof Date) {
    dateStr = data.createdAt.toLocaleDateString("fr-FR");
  }

  // --- Column 1: Client & Store ---
  drawField("Client", data.clientName, col1X, startY);
  drawField("Magasin / Site", data.storeName, col1X, doc.y);

  // --- Column 2: Manager & Date ---
  // ✅ LOGIC: If removal, label is 'Date de Dépose', else 'Date de Récupération'
  const dateLabel = data.ticketType === 'removal' ? "Date de Dépose" : "Date de Récupération";

  drawField(dateLabel, dateStr, col2X, startY);
  drawField("Responsable sur Site", data.storeManagerName, col2X, doc.y);
  drawField("Email Responsable", data.storeManagerEmail, col2X, doc.y);

  doc.y = Math.max(doc.y, startY + 60);
  doc.moveDown(2);
}

/**
 * Section 2: Equipment Details
 * ✅ MODIFIED: Handles both Single Item (Card) and Multi-Items (Table)
 */
function _buildEquipmentDetails(doc: PDFKit.PDFDocument, data: any) {
  const startY = doc.y;

  // ✅ LOGIC: Change label based on ticket type
  const problemLabelHeader = data.ticketType === 'removal' ? "Motif" : "Problème";

  // ---------------------------------------------------------
  // 🅰️ MULTI-PRODUCT MODE (Table View)
  // ---------------------------------------------------------
  if (data.multiProducts && data.multiProducts.length > 0) {
    // Table Config
    const col1X = MARGIN;           // Product Name
    const col2X = MARGIN + 200;     // Serial Number
    const col3X = MARGIN + 350;     // Problem/Description

    const col1Width = 190;
    const col2Width = 140;
    const col3Width = doc.page.width - MARGIN - col3X;

    // 1. Draw Table Header
    doc.rect(MARGIN, doc.y, doc.page.width - (MARGIN * 2), 20).fillColor(BRAND_COLOR).fill();

    const headerY = doc.y + 5; // vertical centering offset
    doc.font("Helvetica-Bold").fontSize(10).fillColor(HEADER_TEXT_COLOR);
    doc.text("Produit / Équipement", col1X + 5, headerY, { width: col1Width });
    doc.text("N° Série (S/N)", col2X, headerY, { width: col2Width });
    doc.text(problemLabelHeader, col3X, headerY, { width: col3Width });

    doc.moveDown(2); // Move past header rectangle

    // 2. Draw Rows
    doc.font("Helvetica").fontSize(9).fillColor(TEXT_COLOR);

    data.multiProducts.forEach((item: any, index: number) => {
      // ✅ FIX: Check for Page Break BEFORE getting rowY
      if (doc.y > doc.page.height - 50) {
        doc.addPage();
        // Optional: Re-draw header here if you want perfect polish
      }

      const rowY = doc.y; // Capture Y *after* potentially adding a page
      const rowHeight = 25;

      // Zebra Striping
      if (index % 2 === 0) {
        doc.rect(MARGIN, rowY - 5, doc.page.width - (MARGIN * 2), rowHeight + 5)
           .fillColor(LIGHT_GRAY_BACKGROUND).fill();
        doc.fillColor(TEXT_COLOR);
      }

      doc.text(item.productName || "N/A", col1X + 5, rowY, { width: col1Width });
      doc.text(item.serialNumber || "N/A", col2X, rowY, { width: col2Width });
      doc.text(item.problemDescription || "N/A", col3X, rowY, { width: col3Width });

      doc.moveDown(1);
    });

    doc.moveDown(1);

    // ✅ ADDED: Technicians Summary right after table
    const techs: string[] = data.pickupTechnicianNames || [];
    const techLabel = data.ticketType === 'removal' ? "Techniciens (Dépose) :" : "Techniciens (Récupération) :";

    doc.font("Helvetica-Bold").fontSize(10).fillColor(TITLE_COLOR)
       .text(techLabel, MARGIN, doc.y, { continued: true });

    doc.font("Helvetica").fillColor(TEXT_COLOR)
       .text(`  ${techs.length > 0 ? techs.join(", ") : "Non spécifié"}`);

    doc.moveDown(2);
    return; // 🛑 Stop here
  }

  // ---------------------------------------------------------
  // 🅱️ SINGLE PRODUCT MODE (Original Gray Card)
  // ---------------------------------------------------------

  const contentX = MARGIN + 20;
  const contentWidth = doc.page.width - MARGIN * 2 - 40;
  const problemLabel = data.ticketType === 'removal' ? "Motif de la Dépose" : "Problème Déclaré";

  const drawTextBlock = (label: string, text: string) => {
    doc
      .font("Helvetica-Bold")
      .fontSize(12)
      .fillColor(TITLE_COLOR)
      .text(label, contentX, doc.y, { width: contentWidth });

    doc
      .font("Helvetica")
      .fontSize(10)
      .fillColor(TEXT_COLOR)
      .text(text || "Non spécifié", contentX, doc.y, { width: contentWidth });

    doc.moveDown(1.5);
  };

  const tempY = doc.y;
  doc.y = tempY + 20;

  drawTextBlock("Produit / Équipement", data.productName);
  drawTextBlock("Numéro de Série (S/N)", data.serialNumber);
  drawTextBlock(problemLabel, data.problemDescription);

  const endY = doc.y;

  // Draw Gray Card Background
  doc
    .rect(MARGIN, startY, doc.page.width - MARGIN * 2, endY - startY + 10)
    .fillColor(LIGHT_GRAY_BACKGROUND)
    .fill();

  // Draw Text on Top
  doc.y = tempY + 20;
  drawTextBlock("Produit / Équipement", data.productName);
  drawTextBlock("Numéro de Série (S/N)", data.serialNumber);
  drawTextBlock(problemLabel, data.problemDescription);

  doc.y = endY + 20;
}

/**
 * Section 3: Validation (Technicians & Signature)
 * Layout: 2 Columns with Watermark
 */
async function _buildValidationSection(
  doc: PDFKit.PDFDocument,
  data: any,
  signatureBuffer: Buffer | null,
  watermarkBuffer: Buffer | null
) {
  // Ensure we don't start at the very bottom
  if (doc.y > doc.page.height - 150) {
    doc.addPage();
  }

  const startY = doc.y;
  const col1X = MARGIN;
  const col2X = doc.page.width / 2 + 30;
  const colWidth = doc.page.width / 2 - MARGIN - 30;

  // --- Watermark (Background) ---
  if (watermarkBuffer) {
    doc.save()
      .opacity(0.20) // 20% Opacity
      .image(watermarkBuffer, col1X, startY + 25, {
        fit: [colWidth, 100],
        align: "center",
        valign: "center",
      })
      .restore();
  }

  // --- Column 1: Boitex Technicians ---
  const techLabel = data.ticketType === 'removal' ? "Techniciens (Dépose)" : "Techniciens (Récupération)";

  doc.font("Helvetica-Bold").fontSize(12).fillColor(TITLE_COLOR)
     .text(techLabel, col1X, startY);

  const techs: string[] = data.pickupTechnicianNames || [];

  if (techs.length > 0) {
    techs.forEach((tech) => {
      doc.font("Helvetica").fontSize(10).fillColor(TEXT_COLOR).text(`• ${tech}`, { lineGap: 3 });
    });
  } else {
    doc.font("Helvetica-Oblique").fontSize(10).fillColor(LABEL_COLOR).text("Non spécifié", { lineGap: 3 });
  }

  // --- Column 2: Manager Signature ---
  doc.font("Helvetica-Bold").fontSize(12).fillColor(TITLE_COLOR)
     .text("Signature Responsable", col2X, startY);

  const sigBoxHeight = 100;
  const sigBoxY = startY + 25;

  doc.rect(col2X, sigBoxY, colWidth, sigBoxHeight).lineWidth(0.5).strokeColor(LINE_COLOR).stroke();

  if (signatureBuffer) {
    doc.image(signatureBuffer, col2X, sigBoxY, {
      fit: [colWidth, sigBoxHeight],
      align: "center",
      valign: "center",
    });
  } else {
    doc.font("Helvetica-Oblique").fontSize(10).fillColor(LABEL_COLOR)
       .text("Absence de signature", col2X, sigBoxY + 40, { width: colWidth, align: "center" });
  }

  doc.font("Helvetica").fontSize(9).fillColor(LABEL_COLOR)
     .text(`Validé par : ${data.storeManagerName || "N/A"}`, col2X, sigBoxY + sigBoxHeight + 5, {
       width: colWidth, align: "center"
     });
}

/**
 * Footer: Page Numbers & Contact
 */
function _buildFooter(doc: PDFKit.PDFDocument) {
  const range = doc.bufferedPageRange();
  const pageCount = range.start + range.count;
  const footerY = doc.page.height - 35;

  for (let i = range.start; i < pageCount; i++) {
    doc.switchToPage(i);

    doc.save().moveTo(MARGIN, footerY).lineTo(doc.page.width - MARGIN, footerY)
       .lineWidth(0.5).strokeColor(LINE_COLOR).stroke().restore();

    const contactInfo = "www.boitexinfo.com | commercial@boitexinfo.com | +213 560 367 256";
    doc.font("Helvetica").fontSize(8).fillColor(LABEL_COLOR)
       .text(contactInfo, MARGIN, footerY + 10, { align: "left" });

    doc.text(`Page ${i + 1} / ${pageCount}`, doc.page.width - MARGIN - 50, footerY + 10, {
      width: 50, align: "right"
    });
  }
}

/**
 * MAIN EXPORT: Generates the "Décharge Matériel" PDF
 */
export async function generateSavDechargePdf(data: any): Promise<Buffer> {
  const doc = new PDFDocument({
    size: "A4",
    margins: { top: 0, bottom: 0, left: 0, right: 0 },
    bufferPages: true,
  });

  const buffers: Buffer[] = [];
  doc.on("data", buffers.push.bind(buffers));

  // 1. Fetch Images
  const [logoBuffer, signatureBuffer, watermarkBuffer] = await Promise.all([
    fetchImage(LOGO_URL_WHITE),
    fetchImage(data.storeManagerSignatureUrl),
    fetchImage(WATERMARK_URL),
  ]);

  // ✅ 2. Header (Dynamic Title)
  const isRemoval = data.ticketType === 'removal';
  const title = isRemoval ? "BON DE DÉPOSE" : "DÉCHARGE MATÉRIEL";

  _buildHeader(doc, logoBuffer, title);

  // 3. Info Section
  doc.x = MARGIN;
  _buildClientAndManagerInfo(doc, data);

  // Divider
  doc.save().moveTo(MARGIN, doc.y).lineTo(doc.page.width - MARGIN, doc.y)
     .lineWidth(0.5).strokeColor(LINE_COLOR).stroke().restore();
  doc.moveDown(2);

  // 4. Equipment Details (Gray Card OR Table)
  _buildEquipmentDetails(doc, data);

  // 5. Validation (Signatures)
  await _buildValidationSection(doc, data, signatureBuffer, watermarkBuffer);

  // 6. Footer
  _buildFooter(doc);

  return new Promise((resolve, reject) => {
    doc.on("end", () => resolve(Buffer.concat(buffers)));
    doc.on("error", (err) => reject(err));
    doc.end();
  });
}