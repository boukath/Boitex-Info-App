// functions/src/installation-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";

// --- 1. CONSTANTS & STYLING ---
const LOGO_URL_WHITE = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
// Using the "cache technique" image for the company stamp
const CACHE_URL = "https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/cache+technique.png";

const BRAND_COLOR = "#0D47A1"; // Deep blue
const TEXT_COLOR = "#333333"; // Dark gray
const LIGHT_GRAY_BACKGROUND = "#F7F9FA";
const LINE_COLOR = "#E0E0E0";
const MARGIN = 40;

/**
* Helper: Fetches an image from a URL and returns it as a Buffer.
*/
async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || !url.startsWith("http")) return null;
  try {
    const response = await axios.get(url, { responseType: "arraybuffer" });
    return Buffer.from(response.data);
  } catch (error) {
    logger.warn(`Failed to fetch image: ${url}`, error);
    return null;
  }
}

/**
 * ✅ MAIN FUNCTION: Generates the Installation PDF Report
 */
export async function generateInstallationPdf(data: any): Promise<Buffer> {
  const doc = new PDFDocument({
    size: "A4",
    margins: { top: 0, bottom: 0, left: 0, right: 0 },
    bufferPages: true,
  });

  const buffers: Buffer[] = [];
  doc.on("data", buffers.push.bind(buffers));

  // --- A. PRELOAD IMAGES ---
  // We don't need techSigBuffer anymore based on your request.
  // We load CACHE_URL for the technician side.
  const [logoBuffer, clientSigBuffer, cacheBuffer] = await Promise.all([
    fetchImage(LOGO_URL_WHITE),
    data.clientSignatureUrl ? fetchImage(data.clientSignatureUrl) : Promise.resolve(null),
    fetchImage(CACHE_URL),
  ]);

  // --- B. BUILD DOCUMENT ---

  // 1. Header (Updated: Big Logo, No Text on right)
  _buildHeader(doc, logoBuffer);

  // 2. Title & Meta Data
  doc.x = MARGIN;
  doc.moveDown(2);

  doc
    .font("Helvetica-Bold")
    .fontSize(22)
    .fillColor(BRAND_COLOR)
    .text("RAPPORT D'INSTALLATION", { align: "center" });

  doc.moveDown(0.5);

  const installCode = data.installationCode || "N/A";
  const dateStr = data.createdAt
    ? new Date(data.createdAt.toDate()).toLocaleDateString("fr-FR")
    : new Date().toLocaleDateString("fr-FR");

  doc
    .fontSize(10)
    .fillColor(TEXT_COLOR)
    .text(`Réf: ${installCode}  |  Date: ${dateStr}`, { align: "center" });

  doc.moveDown(2);

  // 3. Client Info Box
  _buildClientInfo(doc, data);

  doc.moveDown(3);

  // 4. The Equipment Table
  _buildInventoryTable(doc, data.systems || []);

  doc.moveDown(2);

  // 5. ✅ NEW: Technician Notes Section
  if (data.notes && data.notes.isNotEmpty) {
      _buildNotesSection(doc, data.notes);
      doc.moveDown(2);
  }

  // 6. Signatures (Updated Logic)
  // Check page break
  if (doc.y > 600) doc.addPage();

  _buildSignatureSection(doc, data, clientSigBuffer, cacheBuffer);

  // 7. Finalize
  doc.end();

  return new Promise((resolve) => {
    doc.on("end", () => {
      resolve(Buffer.concat(buffers));
    });
  });
}

// ==========================================================
// 🛠️ PRIVATE HELPER FUNCTIONS
// ==========================================================

function _buildHeader(doc: PDFKit.PDFDocument, logoBuffer: Buffer | null) {
  // Blue background header
  doc
    .rect(0, 0, doc.page.width, 100) // Increased height for bigger logo
    .fillColor(BRAND_COLOR)
    .fill();

  // Logo - ✅ Much Bigger and vertically centered in the new 100px header
  if (logoBuffer) {
    doc.image(logoBuffer, MARGIN, 10, { height: 80 });
  }

  // ✅ Removed "BOITEX INFO" and "Systèmes Antivol..." text as requested
}

function _buildClientInfo(doc: PDFKit.PDFDocument, data: any) {
  const startY = doc.y;

  // Draw Gray Background Box
  doc
    .rect(MARGIN, startY, doc.page.width - MARGIN * 2, 65)
    .fillAndStroke(LIGHT_GRAY_BACKGROUND, LINE_COLOR);

  doc.fillColor(TEXT_COLOR).fontSize(10);

  // Row 1: Client & Magasin
  const textY = startY + 15;

  // Client
  doc.font("Helvetica").text("CLIENT:", MARGIN + 20, textY, { continued: true });
  doc.font("Helvetica-Bold").text(`  ${data.clientName || "N/A"}`);

  // Store (Right aligned manually)
  doc.font("Helvetica").text("MAGASIN:", 300, textY, { continued: true });
  doc.font("Helvetica-Bold").text(`  ${data.storeName || "N/A"}`);

  // Row 2: Address
  doc.moveDown(1.5);
  doc.font("Helvetica").text("ADRESSE:", MARGIN + 20, doc.y, { continued: true });
  doc.font("Helvetica-Bold").text(`  ${data.storeLocation || data.address || "Non spécifiée"}`);
}

function _buildInventoryTable(doc: PDFKit.PDFDocument, systems: any[]) {
  const startX = MARGIN;
  let currentY = doc.y;

  // Column Widths
  const wName = 140;
  const wDetails = 100;
  const wQty = 50;
  const wSerial = 220; // Wide column for serials

  // -- Header --
  doc.font("Helvetica-Bold").fontSize(9).fillColor(BRAND_COLOR);
  doc.text("PRODUIT", startX + 5, currentY);
  doc.text("MARQUE / RÉF", startX + wName + 5, currentY);
  doc.text("QTÉ", startX + wName + wDetails, currentY, { width: wQty, align: "center" });
  doc.text("NUMÉROS DE SÉRIE", startX + wName + wDetails + wQty + 10, currentY);

  currentY += 15;
  doc.moveTo(startX, currentY).lineTo(doc.page.width - MARGIN, currentY).strokeColor(BRAND_COLOR).stroke();
  currentY += 10;

  // -- Body --
  doc.font("Helvetica").fontSize(9).fillColor(TEXT_COLOR);

  if (!systems || systems.length === 0) {
    doc.text("Aucun équipement enregistré.", startX, currentY);
    return;
  }

  systems.forEach((item, index) => {
    const name = item.name || "Inconnu";
    const marque = item.marque || item.brand || "-";
    const ref = item.reference || "-";
    const details = `${marque}\n${ref}`;

    // Handle Serials
    let serials = "N/A";
    let qty = 0;

    if (Array.isArray(item.serialNumbers)) {
        serials = item.serialNumbers.join(", ");
        qty = item.serialNumbers.length;
    } else if (item.serialNumber) {
        serials = item.serialNumber;
        qty = 1;
    }

    // Calculate Row Height (Text Wrapping)
    const serialHeight = doc.heightOfString(serials, { width: wSerial });
    const nameHeight = doc.heightOfString(name, { width: wName });
    const rowHeight = Math.max(serialHeight, nameHeight, 30) + 10;

    // Page Break Check
    if (currentY + rowHeight > 750) {
      doc.addPage();
      currentY = MARGIN;
    }

    // Zebra Striping
    if (index % 2 === 0) {
      doc
        .rect(startX, currentY - 5, doc.page.width - MARGIN * 2, rowHeight)
        .fillColor(LIGHT_GRAY_BACKGROUND)
        .fill();
      doc.fillColor(TEXT_COLOR);
    }

    // Draw Content
    doc.text(name, startX + 5, currentY, { width: wName - 10 });
    doc.text(details, startX + wName + 5, currentY, { width: wDetails - 10 });
    doc.text(qty.toString(), startX + wName + wDetails, currentY, { width: wQty, align: "center" });
    doc.text(serials, startX + wName + wDetails + wQty + 10, currentY, { width: wSerial });

    currentY += rowHeight;

    // Divider
    doc.moveTo(startX, currentY).lineTo(doc.page.width - MARGIN, currentY).strokeColor(LINE_COLOR).lineWidth(0.5).stroke();
    currentY += 10;
  });

  doc.y = currentY; // Update cursor
}

// ✅ NEW: Notes Section
function _buildNotesSection(doc: PDFKit.PDFDocument, notes: string) {
    doc.font("Helvetica-Bold").fontSize(12).fillColor(BRAND_COLOR);
    doc.text("NOTES / TRAVAUX EFFECTUÉS:", MARGIN, doc.y);
    doc.moveDown(0.5);

    doc.font("Helvetica").fontSize(10).fillColor(TEXT_COLOR);
    doc.text(notes, { align: "justify" });
}

function _buildSignatureSection(
  doc: PDFKit.PDFDocument,
  data: any,
  clientSig: Buffer | null,
  cache: Buffer | null
) {
  const startY = doc.y;

  // Labels
  doc.font("Helvetica-Bold").fontSize(10).fillColor(BRAND_COLOR);
  doc.text("Technicien(s) Boitex Info", MARGIN, startY);
  doc.text("Signature Client", 350, startY);

  const sigY = startY + 20;

  // --- 1. LEFT SIDE: Technicians & Cache ---
  // A. List Technician Names
  if (data.assignedTechnicians && Array.isArray(data.assignedTechnicians)) {
      doc.font("Helvetica").fontSize(10).fillColor(TEXT_COLOR);
      const names = data.assignedTechnicians
          .map((t: any) => t.displayName || "Technicien")
          .join("\n");

      doc.text(names, MARGIN, sigY);

      // Move down based on number of names to put cache under them
      const namesHeight = doc.heightOfString(names, { width: 200 });
      // B. Draw Cache (Stamp) Under Names
      if (cache) {
          doc.image(cache, MARGIN, sigY + namesHeight + 5, { width: 100 });
      }

  } else {
      // Fallback if no technicians assigned
      if (cache) {
          doc.image(cache, MARGIN, sigY, { width: 100 });
      }
  }

  // --- 2. RIGHT SIDE: Client Signature ---
  if (clientSig) {
    doc.image(clientSig, 350, sigY, { fit: [150, 80] });
  } else {
    doc.fontSize(9).fillColor(LINE_COLOR).text("(Non signé)", 350, sigY + 30);
  }
}