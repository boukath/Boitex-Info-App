// functions/src/sav-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";

// --- 1. ASSETS ---
const LOGO_URL = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
const STAMP_URL = "https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/cache+technique.png";

// --- 2. PREMIUM DESIGN TOKENS ---
const COLORS = {
primary: "#0F172A",     // Deep Space Dark
secondary: "#64748B",   // Slate Gray
accent: "#2563EB",      // Vibrant Apple Blue
border: "#E2E8F0",      // Light Border
bgLight: "#F8FAFC",     // Frost White
success: "#10B981",     // Emerald
warning: "#F59E0B",     // Sunset Amber
white: "#FFFFFF"
};

const FONTS = {
regular: "Helvetica",
bold: "Helvetica-Bold",
italic: "Helvetica-Oblique"
};

const LAYOUT = {
margin: 50,
pageWidth: 595.28,
pageHeight: 841.89,
contentWidth: 495.28
};

/**
* 🚀 Helper: Fetch Image Buffer safely
*/
async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || typeof url !== 'string' || !url.startsWith("http")) return null;
  try {
    const response = await axios.get(url, { responseType: "arraybuffer", timeout: 10000 });
    const buffer = Buffer.from(response.data);

    if (buffer.length > 2.5 * 1024 * 1024) {
      logger.warn(`Skipping image ${url} - Size is too large.`);
      return null;
    }
    return buffer;
  } catch (error) {
    logger.warn(`Could not load image at ${url}`);
    return null;
  }
}

/**
 * Helper: Format Date
 */
function formatDate(dateObj: any, includeTime = false): string {
  if (!dateObj) return "N/A";
  let d: Date;
  if (dateObj._seconds) d = new Date(dateObj._seconds * 1000);
  else if (dateObj.seconds) d = new Date(dateObj.seconds * 1000);
  else d = new Date(dateObj);

  if (isNaN(d.getTime())) return "N/A";

  const opts: Intl.DateTimeFormatOptions = {
    day: "2-digit", month: "long", year: "numeric",
    ...(includeTime && { hour: "2-digit", minute: "2-digit" })
  };
  return d.toLocaleDateString("fr-FR", opts);
}

/**
 * 🚀 SMART PAGE BREAK HANDLER
 */
function _checkPageBreak(doc: PDFKit.PDFDocument, requiredSpace: number) {
  if (doc.y + requiredSpace > LAYOUT.pageHeight - 80) {
    doc.addPage();
    doc.x = LAYOUT.margin;
    doc.y = LAYOUT.margin;
  }
}

/**
 * 🚀 MAIN GENERATOR FUNCTION
 */
export async function generateSavDechargePdf(data: any): Promise<Buffer> {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: "A4",
        margins: { top: LAYOUT.margin, bottom: LAYOUT.margin, left: LAYOUT.margin, right: LAYOUT.margin },
        bufferPages: true,
      });

      const buffers: Buffer[] = [];
      doc.on("data", buffers.push.bind(buffers));

      // 🌟 WHATSAPP STYLE QR CODE
      const ticketTitle = data.ticketType === 'removal' ? "BON DE DÉPOSE" : "DÉCHARGE MATÉRIEL";
      const qrData = encodeURIComponent(`Certifié BOITEX INFO | ${ticketTitle} | SAV: ${data.savCode || 'N/A'} | Client: ${data.clientName || 'N/A'}`);
      const logoUrlEnc = encodeURIComponent(LOGO_URL);
      const QR_URL = `https://quickchart.io/qr?text=${qrData}&dark=0F172A&light=FFFFFF&size=150&centerImageUrl=${logoUrlEnc}`;

      // Fetch Assets
      const [logoBuffer, signatureBuffer, stampBuffer, qrBuffer] = await Promise.all([
        fetchImage(LOGO_URL),
        fetchImage(data.storeManagerSignatureUrl),
        fetchImage(STAMP_URL),
        fetchImage(QR_URL),
      ]);

      doc.on('pageAdded', () => {
        _drawWatermark(doc, logoBuffer);
      });

      // --- START DRAWING ---
      _drawWatermark(doc, logoBuffer);
      _drawHeader(doc, data, logoBuffer, ticketTitle);

      doc.moveDown(1);
      _drawInformationGrid(doc, data);

      doc.moveDown(1.5);
      _drawEquipmentDetails(doc, data);

      doc.moveDown(1.5);
      _drawValidationSection(doc, data, signatureBuffer, stampBuffer, qrBuffer);

      _addGlobalFooters(doc, data, ticketTitle);

      doc.end();
      doc.on("end", () => resolve(Buffer.concat(buffers)));

    } catch (error) {
      logger.error("CRITICAL ERROR IN SAV PDF GENERATION:", error);
      reject(error);
    }
  });
}

// ============================================================================
// 🎨 PREMIUM DRAWING FUNCTIONS
// ============================================================================

function _drawWatermark(doc: PDFKit.PDFDocument, logoBuffer: Buffer | null) {
  if (!logoBuffer) return;
  try {
    doc.save()
       .opacity(0.06)
       .image(logoBuffer, LAYOUT.margin, (LAYOUT.pageHeight - 400) / 2, {
          fit: [LAYOUT.contentWidth, 400],
          align: 'center',
          valign: 'center'
       })
       .restore();
  } catch (e) {
    doc.restore();
  }
}

function _drawHeader(doc: PDFKit.PDFDocument, data: any, logoBuffer: Buffer | null, title: string) {
  doc.x = LAYOUT.margin;
  const startY = doc.y;

  // Draw Logo
  if (logoBuffer) {
    try {
      doc.image(logoBuffer, LAYOUT.margin, startY, { fit: [210, 80] });
    } catch (e) {
      doc.font(FONTS.bold).fontSize(16).fillColor(COLORS.primary).text("BOITEX INFO", LAYOUT.margin, startY);
    }
  } else {
    doc.font(FONTS.bold).fontSize(16).fillColor(COLORS.primary).text("BOITEX INFO", LAYOUT.margin, startY);
  }

  // Draw Title
  doc.font(FONTS.bold).fontSize(20).fillColor(COLORS.primary)
     .text(title, LAYOUT.margin, startY, { align: "right", width: LAYOUT.contentWidth });

  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.secondary)
     .text(`RÉF SAV: ${data.savCode || 'N/A'}`, LAYOUT.margin, doc.y + 2, { align: "right", width: LAYOUT.contentWidth });

  const dateLabel = data.ticketType === 'removal' ? "DÉPOSE LE :" : "RÉCUPÉRÉ LE :";
  doc.text(`${dateLabel} ${formatDate(data.createdAt)}`, LAYOUT.margin, doc.y + 2, { align: "right", width: LAYOUT.contentWidth });

  // Status Badge
  doc.moveDown(0.5);
  const status = data.status || "Nouveau";
  const isDepose = data.ticketType === 'removal';
  const badgeColor = isDepose ? COLORS.warning : COLORS.success;

  const textWidth = doc.widthOfString(status.toUpperCase()) + 20;
  const badgeX = LAYOUT.pageWidth - LAYOUT.margin - textWidth;

  doc.roundedRect(badgeX, doc.y, textWidth, 18, 9).fill(badgeColor);
  doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.white)
     .text(status.toUpperCase(), badgeX, doc.y + 5, { width: textWidth, align: "center" });

  // Divider Line
  doc.y = Math.max(startY + 80, doc.y + 20);
  doc.moveTo(LAYOUT.margin, doc.y).lineTo(LAYOUT.pageWidth - LAYOUT.margin, doc.y)
     .lineWidth(1).strokeColor(COLORS.border).stroke();
  doc.y += 15;
  doc.x = LAYOUT.margin;
}

function _drawSectionTitle(doc: PDFKit.PDFDocument, title: string) {
  _checkPageBreak(doc, 40);
  doc.x = LAYOUT.margin;
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.accent)
     .text(title.toUpperCase(), LAYOUT.margin, doc.y, { characterSpacing: 1.5 });
  doc.moveDown(1);
}

function _drawInformationGrid(doc: PDFKit.PDFDocument, data: any) {
  _checkPageBreak(doc, 80);
  doc.x = LAYOUT.margin;

  const startY = doc.y;
  const colWidth = (LAYOUT.contentWidth / 2) - 10;
  const rightColX = LAYOUT.margin + colWidth + 20;

  // Left Column: Client
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("INFORMATIONS CLIENT", LAYOUT.margin, startY, { characterSpacing: 1 });
  doc.font(FONTS.bold).fontSize(11).fillColor(COLORS.primary).text(data.clientName || "Client Inconnu", LAYOUT.margin, startY + 15, { width: colWidth });
  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
     .text(data.storeName || "Site non spécifié", LAYOUT.margin, startY + 30, { width: colWidth })
     .text(`Responsable: ${data.storeManagerName || "N/A"}`, LAYOUT.margin, startY + 45, { width: colWidth })
     .fillColor(COLORS.secondary).text(data.storeManagerEmail || "", LAYOUT.margin, startY + 60, { width: colWidth });

  // Right Column: Details
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("DÉTAILS INTERVENTION", rightColX, startY, { characterSpacing: 1 });

  let techs = "Non assigné";
  if (Array.isArray(data.pickupTechnicianNames) && data.pickupTechnicianNames.length > 0) {
    techs = data.pickupTechnicianNames.join(", ");
  }

  // ✅ NEW LOGIC: Precisely determine the Ticket Type and Technician Label
  let ticketTypeDisplay = "Récupération Matériel";
  let roleLabel = "Équipe (Récup):";

  if (data.ticketType === 'removal' || data.status === 'Dépose') {
    ticketTypeDisplay = "Dépose Matériel";
    roleLabel = "Équipe (Dépose):";
  } else if (data.status === 'Dépose') {
    ticketTypeDisplay = "Retour Matériel";
    roleLabel = "Équipe (Retour):";
  } else if (data.ticketType === 'standard' || data.status === 'standard') {
    ticketTypeDisplay = "Récupération Matériel";
    roleLabel = "Équipe (Récup):";
  }

  const row = (label: string, val: string, yPos: number) => {
    doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.secondary).text(label, rightColX, yPos, { width: 90 });
    doc.font(FONTS.bold).fillColor(COLORS.primary).text(val, rightColX + 90, yPos, { width: colWidth - 90 });
  };

  row("Type Ticket:", ticketTypeDisplay, startY + 15);
  row(roleLabel, techs, startY + 30);

  doc.y = startY + 80;
  doc.x = LAYOUT.margin;
}

function _drawEquipmentDetails(doc: PDFKit.PDFDocument, data: any) {
  const problemLabelHeader = data.ticketType === 'removal' ? "Motif / Problème" : "Problème Déclaré";

  // ---------------------------------------------------------
  // 🅰️ MULTI-PRODUCT MODE (Table View)
  // ---------------------------------------------------------
  if (data.multiProducts && data.multiProducts.length > 0) {
    _drawSectionTitle(doc, "Liste des Équipements");

    const startX = LAYOUT.margin;
    doc.rect(startX, doc.y, LAYOUT.contentWidth, 20).fill(COLORS.bgLight);

    const headerY = doc.y + 6;
    doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.secondary);
    doc.text("PRODUIT", startX + 10, headerY, { width: 180 });
    doc.text("N° SÉRIE", startX + 200, headerY, { width: 120 });
    doc.text(problemLabelHeader.toUpperCase(), startX + 330, headerY, { width: doc.page.width - startX - 350 });

    doc.y = headerY + 14;

    data.multiProducts.forEach((item: any) => {
      _checkPageBreak(doc, 30);
      const rowY = doc.y + 6;

      const name = item.productName || "Inconnu";
      const sns = item.serialNumber || "-";
      const prob = item.problemDescription || "-";

      doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.primary);
      doc.text(name, startX + 10, rowY, { width: 180 });

      doc.font(FONTS.regular).fillColor(COLORS.secondary);
      doc.text(sns, startX + 200, rowY, { width: 120 });

      doc.fillColor(COLORS.primary);
      doc.text(prob, startX + 330, rowY, { width: doc.page.width - startX - 350 });

      const nameHeight = doc.heightOfString(name, { width: 180 });
      const probHeight = doc.heightOfString(prob, { width: doc.page.width - startX - 350 });
      const maxH = Math.max(nameHeight, probHeight);

      doc.y = rowY + maxH + 6;
      doc.moveTo(startX, doc.y).lineTo(LAYOUT.pageWidth - startX, doc.y)
         .lineWidth(0.5).strokeColor(COLORS.border).stroke();
    });

    doc.y += 15;
    doc.x = LAYOUT.margin;
    return;
  }

  // ---------------------------------------------------------
  // 🅱️ SINGLE PRODUCT MODE (Premium Card)
  // ---------------------------------------------------------
  _checkPageBreak(doc, 100);
  _drawSectionTitle(doc, "Équipement Concerné");

  const cardX = LAYOUT.margin;
  const cardWidth = LAYOUT.contentWidth;

  // Calculate dynamic height based on problem description length
  doc.font(FONTS.regular).fontSize(10);
  const probHeight = doc.heightOfString(data.problemDescription || "Non spécifié", { width: cardWidth - 40 });
  const cardHeight = 80 + probHeight;

  doc.roundedRect(cardX, doc.y, cardWidth, cardHeight, 10)
     .fillAndStroke(COLORS.bgLight, COLORS.border);

  const innerY = doc.y + 15;

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary)
     .text("PRODUIT", cardX + 20, innerY);
  doc.font(FONTS.bold).fontSize(12).fillColor(COLORS.primary)
     .text(data.productName || "Inconnu", cardX + 20, innerY + 12);

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary)
     .text("NUMÉRO DE SÉRIE", cardX + 250, innerY);
  doc.font(FONTS.regular).fontSize(11).fillColor(COLORS.primary)
     .text(data.serialNumber || "N/A", cardX + 250, innerY + 12);

  doc.moveTo(cardX + 20, innerY + 35).lineTo(cardX + cardWidth - 20, innerY + 35)
     .lineWidth(0.5).strokeColor(COLORS.border).stroke();

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary)
     .text(problemLabelHeader.toUpperCase(), cardX + 20, innerY + 45);
  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
     .text(data.problemDescription || "Non spécifié", cardX + 20, innerY + 60, { width: cardWidth - 40 });

  doc.y += cardHeight + 20;
}

// ----------------------------------------------------------------------------
// 🌟 THE ULTIMATE VALIDATION CARD (Same as Intervention PDF)
// ----------------------------------------------------------------------------
function _drawValidationSection(doc: PDFKit.PDFDocument, data: any, signatureBuffer: Buffer | null, stampBuffer: Buffer | null, qrBuffer: Buffer | null) {
  _checkPageBreak(doc, 145);
  doc.x = LAYOUT.margin;

  const cardX = LAYOUT.margin;
  const cardY = doc.y;
  const cardWidth = LAYOUT.contentWidth;
  const cardHeight = 125;

  doc.roundedRect(cardX, cardY, cardWidth, cardHeight, 10)
     .fillAndStroke(COLORS.bgLight, COLORS.border);

  doc.font(FONTS.bold).fontSize(10).fillColor(COLORS.primary)
     .text("VALIDATION & SIGNATURE", cardX + 15, cardY + 12);

  const agreementText = data.ticketType === 'removal'
      ? "En signant ce document, le client confirme la dépose et la remise du matériel au technicien."
      : "En signant ce document, le client confirme la récupération du matériel de la part de Boitex Info.";

  doc.font(FONTS.regular).fontSize(8).fillColor(COLORS.secondary)
     .text(agreementText, cardX + 15, cardY + 25, { width: cardWidth - 30 });

  const elementsY = cardY + 40;

  if (qrBuffer) {
    try {
      doc.image(qrBuffer, cardX + 15, elementsY, { width: 60, height: 60 });
    } catch (e) {}
  }

  const stampX = cardX + 90;
  if (stampBuffer) {
    try {
      doc.image(stampBuffer, stampX, elementsY - 5, { width: 100, height: 70, fit: [100, 70], align: 'center', valign: 'center' });
    } catch (e) {}
  }

  const sigWidth = 160;
  const sigX = cardX + cardWidth - sigWidth - 15;

  doc.roundedRect(sigX, elementsY, sigWidth, 60, 6).fillAndStroke(COLORS.white, COLORS.border);

  if (signatureBuffer) {
    try {
      doc.image(signatureBuffer, sigX + 5, elementsY + 5, { width: sigWidth - 10, height: 40, fit: [sigWidth - 10, 40], align: 'center', valign: 'center' });
    } catch (e) {
      doc.fillColor(COLORS.secondary).fontSize(8).text("Erreur Signature", sigX, elementsY + 25, { width: sigWidth, align: "center" });
    }
  } else {
    doc.fillColor(COLORS.secondary).fontSize(8).text("Signature non fournie", sigX, elementsY + 25, { width: sigWidth, align: "center" });
  }

  doc.fillColor(COLORS.primary).font(FONTS.bold).fontSize(9)
     .text(data.storeManagerName || "Responsable Site", sigX, elementsY + 47, { width: sigWidth, align: "center" });

  doc.moveTo(cardX, cardY + 110).lineTo(cardX + cardWidth, cardY + 110)
     .lineWidth(0.5).strokeColor(COLORS.border).stroke();

  doc.font(FONTS.italic).fontSize(7).fillColor(COLORS.secondary)
     .text("Certifié Numériquement -- Garantie de traçabilité Boitex Info.", cardX, cardY + 115, { align: "center", width: cardWidth });

  doc.y = cardY + cardHeight + 20;
}

function _addGlobalFooters(doc: PDFKit.PDFDocument, data: any, title: string) {
  const pageCount = doc.bufferedPageRange().count;
  const originalBottomMargin = doc.page.margins.bottom;
  doc.page.margins.bottom = 0;

  for (let i = 0; i < pageCount; i++) {
    doc.switchToPage(i);

    try {
      const footerY = LAYOUT.pageHeight - 35;

      doc.moveTo(LAYOUT.margin, footerY - 5).lineTo(LAYOUT.pageWidth - LAYOUT.margin, footerY - 5)
         .lineWidth(0.5).strokeColor(COLORS.border).stroke();

      doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.primary)
         .text("BOITEX INFO", LAYOUT.margin, footerY);

      doc.font(FONTS.regular).fillColor(COLORS.accent)
         .text("www.Boitexinfo.com", LAYOUT.margin, footerY + 12, { link: "https://www.Boitexinfo.com" });

      doc.font(FONTS.regular).fillColor(COLORS.secondary)
         .text(`${title} - SAV: ${data.savCode || "N/A"}`, LAYOUT.margin, footerY, { align: "center", width: LAYOUT.contentWidth });

      doc.text(`Page ${i + 1} / ${pageCount}`, LAYOUT.margin, footerY, { align: "right", width: LAYOUT.contentWidth });
    } finally {
      doc.page.margins.bottom = originalBottomMargin;
    }
  }
}