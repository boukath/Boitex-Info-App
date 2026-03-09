// functions/src/pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// --- 1. ASSETS ---
const LOGO_URL = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
const STAMP_URL = "https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/cache+technique.png";

// --- 2. PREMIUM DESIGN TOKENS ---
const COLORS = {
primary: "#0F172A",
secondary: "#64748B",
accent: "#2563EB",
border: "#E2E8F0",
bgLight: "#F8FAFC",
success: "#10B981",
warning: "#F59E0B",
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
* 🚀 Helper: Fetch Image Buffer safely with 10MB Callable Protection
*/
async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || typeof url !== 'string' || !url.startsWith("http")) return null;
  try {
    const response = await axios.get(url, { responseType: "arraybuffer", timeout: 10000 });
    const buffer = Buffer.from(response.data);

    // 🛑 FIREBASE CALLABLE 10MB LIMIT SHIELD
    // If an image is larger than 2.5MB, it will bloat the PDF and crash the 10MB limit.
    if (buffer.length > 2.5 * 1024 * 1024) {
      logger.warn(`Skipping image ${url} - Size (${(buffer.length / 1024 / 1024).toFixed(2)} MB) is too large and will crash the PDF.`);
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
 * 🚀 HELPER: Sanitize Text for PDFKit
 * Removes invisible zero-width characters that crash standard PDF fonts.
 */
function sanitizeText(text: any): string {
  if (!text || typeof text !== 'string') return "";
  // Replaces zero-width spaces, non-joiners, and invisible separators with a normal space
  return text.replace(/[\u200B-\u200D\uFEFF\u2028\u2029]/g, ' ').trim();
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
export async function generateInterventionPdf(data: any, interventionId: string): Promise<Buffer> {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: "A4",
        margins: { top: LAYOUT.margin, bottom: LAYOUT.margin, left: LAYOUT.margin, right: LAYOUT.margin },
        bufferPages: true,
      });

      const buffers: Buffer[] = [];
      doc.on("data", buffers.push.bind(buffers));

      // 🌟 WHATSAPP STYLE QR CODE (Embedded Logo)
      const qrData = encodeURIComponent(`Certifié BOITEX INFO | Réf: ${data.interventionCode || 'N/A'} | Date: ${formatDate(data.createdAt)}`);
      const logoUrlEnc = encodeURIComponent(LOGO_URL);
      // QuickChart API creates a QR code with your logo perfectly centered inside it
      const QR_URL = `https://quickchart.io/qr?text=${qrData}&dark=0F172A&light=FFFFFF&size=150&centerImageUrl=${logoUrlEnc}`;

      // Fetch Assets
      const [logoBuffer, signatureBuffer, stampBuffer, qrBuffer] = await Promise.all([
        fetchImage(LOGO_URL),
        fetchImage(data.signatureUrl),
        fetchImage(STAMP_URL),
        fetchImage(QR_URL),
      ]);

      // --- FETCH MULTI-VISIT JOURNAL ENTRIES (IF APPLICABLE) ---
      let journalEntries: any[] = [];
      if (data.isExtended === true) {
        try {
          const snapshot = await admin.firestore()
            .collection('interventions')
            .doc(interventionId)
            .collection('journal_entries')
            .orderBy('date', 'asc') // Chronological order for PDF
            .get();

          if (!snapshot.empty) {
            journalEntries = snapshot.docs.map(d => d.data());
          }
        } catch (e) {
          logger.error(`Error fetching journal entries for ${interventionId}`, e);
        }
      }

      // Safely Fetch Photos (Combine both types if possible)
      let photoUrls: string[] = [];
      if (data.isExtended && journalEntries.length > 0) {
        journalEntries.forEach((entry: any) => {
          if (Array.isArray(entry.mediaUrls)) {
            photoUrls.push(...entry.mediaUrls);
          }
        });
      } else if (Array.isArray(data.mediaUrls)) {
        photoUrls.push(...data.mediaUrls);
      }

      photoUrls = photoUrls.filter(url => typeof url === 'string' && !url.match(/\.(mp4|mov|avi|pdf|doc)$/i)).slice(0, 4);
      const photoBuffers = await Promise.all(photoUrls.map(url => fetchImage(url)));

      doc.on('pageAdded', () => {
        _drawWatermark(doc, logoBuffer);
      });

      // --- START DRAWING ---
      _drawWatermark(doc, logoBuffer);
      _drawHeader(doc, data, logoBuffer);

      doc.moveDown(1);
      _drawInformationGrid(doc, data);

      doc.moveDown(1);
      _drawEquipmentTable(doc, data);

      doc.moveDown(1);
      // THE CORE CONTENT: Switch based on whether it's extended
      if (data.isExtended && journalEntries.length > 0) {
        _drawMultiVisitTimeline(doc, journalEntries);
      } else {
        _drawSimpleDiagnostic(doc, data);
      }

      if (photoBuffers.some(buf => buf !== null)) {
        _drawPhotoGallery(doc, photoBuffers.filter(b => b !== null) as Buffer[]);
      }

      // 🌟 THE ULTIMATE VALIDATION CARD
      _drawValidationSection(doc, data, signatureBuffer, stampBuffer, qrBuffer);

      _addGlobalFooters(doc, data);

      doc.end();
      doc.on("end", () => resolve(Buffer.concat(buffers)));

    } catch (error) {
      logger.error("CRITICAL ERROR IN PDF GENERATION:", error);
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

function _drawHeader(doc: PDFKit.PDFDocument, data: any, logoBuffer: Buffer | null) {
  doc.x = LAYOUT.margin;
  const startY = doc.y;

  if (logoBuffer) {
    try {
      doc.image(logoBuffer, LAYOUT.margin, startY, { fit: [210, 80] });
    } catch (e) {
      doc.font(FONTS.bold).fontSize(16).fillColor(COLORS.primary).text("BOITEX INFO", LAYOUT.margin, startY);
    }
  } else {
    doc.font(FONTS.bold).fontSize(16).fillColor(COLORS.primary).text("BOITEX INFO", LAYOUT.margin, startY);
  }

  doc.font(FONTS.bold).fontSize(20).fillColor(COLORS.primary)
     .text("RAPPORT D'INTERVENTION", LAYOUT.margin, startY, { align: "right", width: LAYOUT.contentWidth });

  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.secondary)
     .text(`RÉF: ${data.interventionCode || 'N/A'}`, LAYOUT.margin, doc.y + 2, { align: "right", width: LAYOUT.contentWidth });

  doc.text(`DATE: ${formatDate(data.createdAt)}`, LAYOUT.margin, doc.y + 2, { align: "right", width: LAYOUT.contentWidth });

  doc.moveDown(0.5);
  const status = data.status || "Nouveau";
  const isFinished = ["Terminé", "Clôturé", "Facturé"].includes(status);
  const badgeColor = isFinished ? COLORS.success : COLORS.accent;

  const textWidth = doc.widthOfString(status.toUpperCase()) + 20;
  const badgeX = LAYOUT.pageWidth - LAYOUT.margin - textWidth;

  doc.roundedRect(badgeX, doc.y, textWidth, 18, 9).fill(badgeColor);
  doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.white)
     .text(status.toUpperCase(), badgeX, doc.y + 5, { width: textWidth, align: "center" });

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

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("INFORMATIONS CLIENT", LAYOUT.margin, startY, { characterSpacing: 1 });
  doc.font(FONTS.bold).fontSize(11).fillColor(COLORS.primary).text(data.clientName || "Client Inconnu", LAYOUT.margin, startY + 15, { width: colWidth });
  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
     .text(data.storeName || "Site non spécifié", LAYOUT.margin, startY + 30, { width: colWidth })
     .text(`Contact: ${data.managerName || "N/A"}`, LAYOUT.margin, startY + 45, { width: colWidth })
     .fillColor(COLORS.secondary).text(data.managerPhone || data.clientPhone || "", LAYOUT.margin, startY + 60, { width: colWidth });

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("DÉTAILS INTERVENTION", rightColX, startY, { characterSpacing: 1 });

  let techs = "Non assigné";
  if (Array.isArray(data.assignedTechnicians) && data.assignedTechnicians.length > 0) {
    techs = data.assignedTechnicians.join(", ");
  }

  const row = (label: string, val: string, yPos: number) => {
    doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.secondary).text(label, rightColX, yPos, { width: 80 });
    doc.font(FONTS.bold).fillColor(COLORS.primary).text(val, rightColX + 70, yPos, { width: colWidth - 70 });
  };

  row("Type:", data.interventionType || "Non spécifié", startY + 15);
  row("Technicien:", techs, startY + 30);
  row("Créé par:", data.createdByName || "Système", startY + 45);

  doc.y = startY + 80;
  doc.x = LAYOUT.margin;
}

function _drawEquipmentTable(doc: PDFKit.PDFDocument, data: any) {
  let systems: any[] = [];
  if (Array.isArray(data.systems) && data.systems.length > 0) {
    systems = data.systems;
  } else if (data.systemName) {
    systems.push({ name: data.systemName, reference: data.systemReference, quantity: 1, serialNumbers: [data.serialNumber] });
  }

  if (systems.length === 0) return;

  _drawSectionTitle(doc, "Équipements Concernés");

  const startX = LAYOUT.margin;
  doc.rect(startX, doc.y, LAYOUT.contentWidth, 20).fill(COLORS.bgLight);

  const headerY = doc.y + 6;
  doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.secondary);
  doc.text("QTE", startX + 10, headerY, { width: 30 });
  doc.text("PRODUIT", startX + 50, headerY, { width: 200 });
  doc.text("RÉFÉRENCE", startX + 260, headerY, { width: 120 });
  doc.text("NUMÉROS DE SÉRIE", startX + 390, headerY, { width: 100 });

  doc.y = headerY + 14;

  systems.forEach((sys) => {
    _checkPageBreak(doc, 30);

    const qty = sys.quantity || 1;
    const name = sys.name || "Produit Inconnu";
    const ref = sys.reference || "-";
    const sns = Array.isArray(sys.serialNumbers) ? sys.serialNumbers.filter((s:any)=>s).join(", ") : (sys.serialNumber || "-");

    const rowY = doc.y + 6;

    doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.primary);
    doc.text(`${qty}`, startX + 10, rowY, { width: 30 });

    doc.font(FONTS.regular);
    doc.text(name, startX + 50, rowY, { width: 200 });

    doc.fillColor(COLORS.secondary);
    doc.text(ref, startX + 260, rowY, { width: 120 });

    doc.fillColor(COLORS.primary);
    doc.text(sns, startX + 390, rowY, { width: 100 });

    const nameHeight = doc.heightOfString(name, { width: 200 });
    const snsHeight = doc.heightOfString(sns, { width: 100 });
    const maxH = Math.max(nameHeight, snsHeight);

    doc.y = rowY + maxH + 6;

    doc.moveTo(startX, doc.y).lineTo(LAYOUT.pageWidth - startX, doc.y)
       .lineWidth(0.5).strokeColor(COLORS.border).stroke();
  });

  doc.y += 15;
  doc.x = LAYOUT.margin;
}

function _drawMultiVisitTimeline(doc: PDFKit.PDFDocument, entries: any[]) {
  doc.x = LAYOUT.margin;
  _drawSectionTitle(doc, "Journal Multi-Visites");

  const timelineX = LAYOUT.margin + 10;
  const contentX = timelineX + 25;
  const contentWidth = LAYOUT.pageWidth - LAYOUT.margin - contentX;

  entries.forEach((entry, index) => {
    _checkPageBreak(doc, 60);

    const startY = doc.y;

    doc.font(FONTS.bold).fontSize(10).fillColor(COLORS.primary);
    doc.text(formatDate(entry.date), contentX, startY);

    const techName = entry.technicianName || "Technicien";
    const hours = entry.hours ? ` • ${entry.hours} heures` : "";
    doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.accent);
    doc.text(`${techName}${hours}`, contentX, doc.y + 2);

    doc.moveDown(0.5);
    doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary);

    const safeEntryWorkDone = sanitizeText(entry.workDone) || "Aucune description.";
    doc.text(safeEntryWorkDone, contentX, doc.y, {
      width: contentWidth,
      lineGap: 4,
      align: 'left'
    });

    const endY = doc.y + 15;

    doc.circle(timelineX, startY + 5, 4).lineWidth(2).strokeColor(COLORS.accent).stroke();
    doc.circle(timelineX, startY + 5, 1.5).fill(COLORS.accent);

    if (index < entries.length - 1) {
      doc.moveTo(timelineX, startY + 15).lineTo(timelineX, endY - 5).lineWidth(1).strokeColor(COLORS.border).stroke();
    }

    doc.y = endY;
    doc.x = LAYOUT.margin;
  });
}

function _drawSimpleDiagnostic(doc: PDFKit.PDFDocument, data: any) {
  doc.x = LAYOUT.margin;
  _drawSectionTitle(doc, "Rapport Technique");

  _checkPageBreak(doc, 50);
  doc.x = LAYOUT.margin;
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("DIAGNOSTIC / PANNE SIGNALÉE", LAYOUT.margin, doc.y);
  doc.moveDown(0.5);

  const safeDiagnostic = sanitizeText(data.diagnostic) || "Aucun diagnostic spécifié.";
  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
     .text(safeDiagnostic, LAYOUT.margin, doc.y, { width: LAYOUT.contentWidth, lineGap: 4, align: 'left' });

  doc.moveDown(1.5);

  _checkPageBreak(doc, 50);
  doc.x = LAYOUT.margin;
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("TRAVAUX EFFECTUÉS", LAYOUT.margin, doc.y);
  doc.moveDown(0.5);

  const safeWorkDone = sanitizeText(data.workDone) || "Aucun travail spécifié.";
  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
     .text(safeWorkDone, LAYOUT.margin, doc.y, { width: LAYOUT.contentWidth, lineGap: 4, align: 'left' });

  doc.moveDown(2);
}

// ✅ FIXED: Completely rewritten Gallery Generator to prevent desyncing doc.y and empty pages
function _drawPhotoGallery(doc: PDFKit.PDFDocument, photoBuffers: Buffer[]) {
  if (photoBuffers.length === 0) return;

  const imgSize = (LAYOUT.contentWidth - 20) / 2;

  // 1. Ensure we have space for the Title + the FIRST row of images
  _checkPageBreak(doc, 40 + imgSize + 30);

  doc.x = LAYOUT.margin;
  _drawSectionTitle(doc, "Preuves Visuelles (Galerie)");

  let startX = LAYOUT.margin;

  photoBuffers.forEach((buf, i) => {
    // Move to the next row every 2 images
    if (i % 2 === 0 && i !== 0) {
      doc.y += imgSize + 15; // Move doc.y down to the new row
      startX = LAYOUT.margin;

      // Now that doc.y is updated, check if this new row forces a page break
      _checkPageBreak(doc, imgSize + 30);
    }

    const currentY = doc.y; // currentY always strictly follows doc.y

    try {
      doc.save();
      // Add a clipping path with rounded corners
      doc.roundedRect(startX, currentY, imgSize, imgSize, 8).clip();

      // Draw the image
      doc.image(buf, startX, currentY, {
        width: imgSize,
        height: imgSize,
        fit: [imgSize, imgSize],
        align: 'center',
        valign: 'center'
      });
      doc.restore();
    } catch (e) {
      doc.restore();
      logger.warn("Failed to draw a photo in the gallery", e);
    }

    startX += imgSize + 20;
  });

  // Update doc.y to the bottom of the gallery safely for the elements coming after it
  doc.y += imgSize + 30;
  doc.x = LAYOUT.margin;
}

// ----------------------------------------------------------------------------
// 🌟 THE ULTIMATE VALIDATION CARD
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
  doc.font(FONTS.regular).fontSize(8).fillColor(COLORS.secondary)
     .text("En signant ce document, le client confirme que l'intervention a été réalisée avec succès.", cardX + 15, cardY + 25, { width: cardWidth - 30 });

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
     .text(data.managerName || "Client", sigX, elementsY + 47, { width: sigWidth, align: "center" });

  doc.moveTo(cardX, cardY + 110).lineTo(cardX + cardWidth, cardY + 110)
     .lineWidth(0.5).strokeColor(COLORS.border).stroke();

  doc.font(FONTS.italic).fontSize(7).fillColor(COLORS.secondary)
     .text("Certifié Numériquement -- Qualité Garantie par Boitex Info.", cardX, cardY + 115, { align: "center", width: cardWidth });

  doc.y = cardY + cardHeight + 20;
}

function _addGlobalFooters(doc: PDFKit.PDFDocument, data: any) {
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
         .text(data.interventionCode || "DOCUMENT", LAYOUT.margin, footerY, { align: "center", width: LAYOUT.contentWidth });

      doc.text(`Page ${i + 1} / ${pageCount}`, LAYOUT.margin, footerY, { align: "right", width: LAYOUT.contentWidth });
    } finally {
      doc.page.margins.bottom = originalBottomMargin;
    }
  }
}