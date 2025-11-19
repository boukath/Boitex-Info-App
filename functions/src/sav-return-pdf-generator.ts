// functions/src/sav-return-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";

// --- Constants ---
const LOGO_URL_WHITE = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
const WATERMARK_URL = "https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/cache+technique.png";

const BRAND_COLOR = "#0D47A1";
const HEADER_TEXT_COLOR = "#FFFFFF";
const TITLE_COLOR = "#000000";
const TEXT_COLOR = "#333333";
const LABEL_COLOR = "#666666";
const LIGHT_GRAY_BACKGROUND = "#F7F9FA";
const LINE_COLOR = "#E0E0E0";
const MARGIN = 40;

// --- Helper Functions ---

async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || !url.startsWith("http")) return null;
  try {
    const response = await axios.get(url, { responseType: "arraybuffer" });
    return Buffer.from(response.data);
  } catch (error) {
    logger.error(`❌ Error fetching image at ${url}:`, error);
    return null;
  }
}

function _buildHeader(doc: PDFKit.PDFDocument, logoBuffer: Buffer | null) {
  doc.rect(0, 0, doc.page.width, 100).fillColor(BRAND_COLOR).fill();
  if (logoBuffer) {
    doc.image(logoBuffer, MARGIN, 25, { height: 50 });
  }
  doc
    .font("Helvetica-Bold")
    .fontSize(18)
    .fillColor(HEADER_TEXT_COLOR)
    .text("BON DE RESTITUTION SAV", doc.page.width - MARGIN - 300, 40, {
      width: 300,
      align: "right",
    });
  doc.y = 130;
}

function _buildFooter(doc: PDFKit.PDFDocument) {
  const range = doc.bufferedPageRange();
  const pageCount = range.start + range.count;
  const footerY = doc.page.height - 35;

  for (let i = range.start; i < pageCount; i++) {
    doc.switchToPage(i);
    doc.save().moveTo(MARGIN, footerY).lineTo(doc.page.width - MARGIN, footerY)
       .lineWidth(0.5).strokeColor(LINE_COLOR).stroke().restore();

    doc.font("Helvetica").fontSize(8).fillColor(LABEL_COLOR)
       .text("www.boitexinfo.com | commercial@boitexinfo.com | +213 560 367 256", MARGIN, footerY + 10, { align: "left" });

    doc.text(`Page ${i + 1} / ${pageCount}`, doc.page.width - MARGIN - 50, footerY + 10, {
      width: 50, align: "right"
    });
  }
}

// --- Main Generator Function ---

export async function generateSavReturnPdf(data: any): Promise<Buffer> {
  const doc = new PDFDocument({
    size: "A4",
    margins: { top: 0, bottom: 0, left: 0, right: 0 },
    bufferPages: true,
  });

  const buffers: Buffer[] = [];
  doc.on("data", buffers.push.bind(buffers));

  // 1. Fetch Images
  const signatureUrl = data.returnSignatureUrl || data.storeManagerSignatureUrl;

  const [logoBuffer, signatureBuffer, watermarkBuffer] = await Promise.all([
    fetchImage(LOGO_URL_WHITE),
    fetchImage(signatureUrl),
    fetchImage(WATERMARK_URL),
  ]);

  // 2. Header
  _buildHeader(doc, logoBuffer);

  // 3. Info Section (2 Columns)
  doc.x = MARGIN;
  const col1X = MARGIN;
  const col2X = doc.page.width / 2 + 30;
  const startY = doc.y;

  const returnDate = new Date().toLocaleDateString("fr-FR");

  // Col 1
  doc.font("Helvetica-Bold").fontSize(10).fillColor(LABEL_COLOR).text("Client", col1X, startY);
  doc.font("Helvetica").fillColor(TEXT_COLOR).text(data.clientName || "N/A", col1X);
  doc.moveDown(0.5);

  doc.font("Helvetica-Bold").fillColor(LABEL_COLOR).text("Magasin", col1X);
  doc.font("Helvetica").fillColor(TEXT_COLOR).text(data.storeName || "N/A", col1X);
  doc.moveDown(0.5);

  doc.font("Helvetica-Bold").fillColor(LABEL_COLOR).text("Réf. Ticket", col1X);
  doc.font("Helvetica").fillColor(TEXT_COLOR).text(data.savCode || "N/A", col1X);

  // Col 2
  doc.font("Helvetica-Bold").fillColor(LABEL_COLOR).text("Date de Restitution", col2X, startY);
  doc.font("Helvetica").fillColor(TEXT_COLOR).text(returnDate, col2X);
  doc.moveDown(0.5);

  doc.font("Helvetica-Bold").fillColor(LABEL_COLOR).text("Responsable", col2X);
  doc.font("Helvetica").fillColor(TEXT_COLOR).text(data.storeManagerName || "N/A", col2X);
  doc.moveDown(0.5);

  doc.font("Helvetica-Bold").fillColor(LABEL_COLOR).text("Email", col2X);
  doc.font("Helvetica").fillColor(TEXT_COLOR).text(data.storeManagerEmail || "N/A", col2X);

  doc.y = Math.max(doc.y, startY + 80);
  doc.moveDown(2);

  // Divider
  doc.save().moveTo(MARGIN, doc.y).lineTo(doc.page.width - MARGIN, doc.y)
     .lineWidth(0.5).strokeColor(LINE_COLOR).stroke().restore();
  doc.moveDown(2);

  // 4. Product Details & Repair Report (Consolidated Gray Card)
  const contentX = MARGIN + 20;
  const contentWidth = doc.page.width - MARGIN * 2 - 40;

  const cardTop = doc.y;

  // --- Helper to draw a standard block ---
  const drawBlock = (title: string, value: string) => {
     doc.font("Helvetica-Bold").fontSize(12).fillColor(TITLE_COLOR).text(title, contentX, doc.y, { width: contentWidth });
     doc.font("Helvetica").fontSize(10).fillColor(TEXT_COLOR).text(value || "N/A", contentX, doc.y, { width: contentWidth });
     doc.moveDown(1.5);
  };

  // MEASURE PASS: Calculate height
  doc.y += 20;
  drawBlock("Produit", data.productName);
  drawBlock("Numéro de Série", data.serialNumber);
  drawBlock("Problème Initial", data.problemDescription);
  // ✅ NEW: "Réparation" is now inside the box, same style
  drawBlock("Réparation", data.technicianReport || "Maintenance standard effectuée.");

  const cardBottom = doc.y + 20;

  // DRAW PASS: Draw background and text
  doc.rect(MARGIN, cardTop, doc.page.width - MARGIN * 2, cardBottom - cardTop).fillColor(LIGHT_GRAY_BACKGROUND).fill();

  doc.y = cardTop + 20; // Reset Y to top of card padding
  drawBlock("Produit", data.productName);
  drawBlock("Numéro de Série", data.serialNumber);
  drawBlock("Problème Initial", data.problemDescription);
  drawBlock("Réparation", data.technicianReport || "Maintenance standard effectuée.");

  doc.y = cardBottom + 30; // Move below card

  // 5. Validation
  if (watermarkBuffer) {
    const colWidth = doc.page.width / 2 - MARGIN - 30;
    doc.save().opacity(0.2).image(watermarkBuffer, col1X, doc.y, { fit: [colWidth, 100] }).restore();
  }

  // Techs
  doc.font("Helvetica-Bold").fontSize(12).fillColor(TITLE_COLOR).text("Techniciens", col1X, doc.y);
  const techs = data.pickupTechnicianNames || [];
  if (techs.length > 0) {
    techs.forEach((t: string) => doc.font("Helvetica").fontSize(10).fillColor(TEXT_COLOR).text(`• ${t}`));
  } else {
    doc.font("Helvetica-Oblique").fontSize(10).fillColor(LABEL_COLOR).text("Non spécifié");
  }

  // Signature Box
  const colWidth = doc.page.width / 2 - MARGIN - 30;
  doc.y = doc.y - (techs.length * 12); // Approximate Y reset
  doc.font("Helvetica-Bold").fontSize(12).fillColor(TITLE_COLOR).text("Signature Client (Réception)", col2X, doc.y);

  const sigBoxY = doc.y + 10;
  const sigBoxHeight = 80;

  doc.rect(col2X, sigBoxY, colWidth, sigBoxHeight).lineWidth(0.5).strokeColor(LINE_COLOR).stroke();

  if (signatureBuffer) {
    doc.image(signatureBuffer, col2X, sigBoxY, { fit: [colWidth, sigBoxHeight], align: "center", valign: "center" });
  } else {
    doc.font("Helvetica-Oblique").fontSize(10).fillColor(LABEL_COLOR)
       .text("Non signé", col2X, sigBoxY + 35, { width: colWidth, align: "center" });
  }

  // ✅ FIX: Manager Name visibility
  // Placed explicitly 5 units below the signature box bottom
  const nameY = sigBoxY + sigBoxHeight + 5;
  const managerName = data.returnClientName || data.storeManagerName || "Client";

  doc.font("Helvetica").fontSize(9).fillColor(LABEL_COLOR)
     .text(`Validé par : ${managerName}`, col2X, nameY, { width: colWidth, align: "center" });
  
  // Footer
  _buildFooter(doc);

  return new Promise((resolve, reject) => {
    doc.on("end", () => resolve(Buffer.concat(buffers)));
    doc.on("error", reject);
    doc.end();
  });
}