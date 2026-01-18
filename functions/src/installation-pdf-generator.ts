// functions/src/installation-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";

// --- 1. CONSTANTS & STYLING ---
const LOGO_URL_WHITE = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
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
    margins: { top: 0, bottom: 0, left: 0, right: 0 }, // Custom margins
    bufferPages: true,
  });

  const buffers: Buffer[] = [];
  doc.on("data", buffers.push.bind(buffers));

  // --- A. PRELOAD IMAGES ---
  const [logoBuffer, clientSigBuffer, cacheBuffer] = await Promise.all([
    fetchImage(LOGO_URL_WHITE),
    data.signatureUrl ? fetchImage(data.signatureUrl) : Promise.resolve(null),
    fetchImage(CACHE_URL),
  ]);

  // --- B. BUILD DOCUMENT ---

  // 1. Header (Big Blue Bar with Logo Left / Title Right)
  _buildHeader(doc, logoBuffer, data);

  // 2. Reset Position (Move down to avoid overlap)
  doc.y = 140;

  // 3. Client Info Box
  _buildClientInfo(doc, data);

  doc.moveDown(3);

  // 4. The Equipment Table (Polymorphic: IT vs Tech)
  // ✅ UPDATED: Pass serviceType to decide layout
  _buildInventoryTable(doc, data.systems || [], data.serviceType);

  doc.moveDown(2);

  // 5. Technician Notes Section (if any)
  if (data.notes && data.notes.length > 0) {
      _buildNotesSection(doc, data.notes);
      doc.moveDown(2);
  }

  // 6. Photo Grid (If images exist)
  if (data.mediaUrls && data.mediaUrls.length > 0) {
    // Only fetch non-video images for PDF
    const photoUrls = data.mediaUrls.filter((url: string) => !url.toLowerCase().endsWith('.mp4'));
    if (photoUrls.length > 0) {
      await _buildPhotoGrid(doc, photoUrls);
      doc.moveDown(2);
    }
  }

  // 7. Signatures
  // Check page break (ensure signatures aren't cut off)
  if (doc.y > 650) doc.addPage();

  _buildSignatureSection(doc, data, clientSigBuffer, cacheBuffer);

  // 8. Finalize
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

function _buildHeader(doc: PDFKit.PDFDocument, logoBuffer: Buffer | null, data: any) {
  // 1. Blue background header
  doc
    .rect(0, 0, doc.page.width, 110) // Taller header
    .fillColor(BRAND_COLOR)
    .fill();

  // 2. Logo (Left Side)
  if (logoBuffer) {
    // Vertically centered in the 110px header
    doc.image(logoBuffer, MARGIN, 25, { height: 60 });
  }

  // 3. Title & Meta (Right Side)
  // ✅ UPDATED: Dynamic Title based on Service Type
  const typeTitle = data.serviceType === 'Service IT' ? "RAPPORT IT / RÉSEAU" : "RAPPORT D'INSTALLATION";

  doc
    .font("Helvetica-Bold")
    .fontSize(18)
    .fillColor("white")
    .text(typeTitle, doc.page.width - MARGIN - 300, 35, {
      width: 300,
      align: "right",
    });

  // Reference & Date (Smaller, under title)
  const installCode = data.installationCode || "REF-N/A";
  const dateStr = data.createdAt
    ? new Date(data.createdAt.toDate()).toLocaleDateString("fr-FR")
    : new Date().toLocaleDateString("fr-FR");

  doc
    .font("Helvetica")
    .fontSize(10)
    .opacity(0.9)
    .text(`Réf: ${installCode}  |  Date: ${dateStr}`, doc.page.width - MARGIN - 300, 60, {
      width: 300,
      align: "right",
    });

  doc.opacity(1); // Reset opacity
}

function _buildClientInfo(doc: PDFKit.PDFDocument, data: any) {
  const startY = doc.y;

  // Section Title
  doc
    .font("Helvetica-Bold")
    .fontSize(12)
    .fillColor(BRAND_COLOR)
    .text("INFORMATIONS CLIENT", MARGIN, startY);

  doc.moveDown(0.5);

  // Draw Gray Background Box
  const boxTop = doc.y;
  doc
    .rect(MARGIN, boxTop, doc.page.width - MARGIN * 2, 60)
    .fillAndStroke(LIGHT_GRAY_BACKGROUND, LINE_COLOR);

  doc.fillColor(TEXT_COLOR).fontSize(10);

  const textY = boxTop + 15;

  // Column 1: Client & Address
  doc.font("Helvetica").text("CLIENT:", MARGIN + 20, textY);
  doc.font("Helvetica-Bold").text(data.clientName || "N/A", MARGIN + 80, textY);

  doc.font("Helvetica").text("ADRESSE:", MARGIN + 20, textY + 20);
  // Combine store location or address
  const address = data.storeLocation || data.address || "Non spécifiée";
  doc.font("Helvetica-Bold").text(address, MARGIN + 80, textY + 20, { width: 200, height: 20, ellipsis: true });

  // Column 2: Magasin & Phone (Right side of box)
  const col2X = 320;
  doc.font("Helvetica").text("MAGASIN:", col2X, textY);
  doc.font("Helvetica-Bold").text(data.storeName || "N/A", col2X + 60, textY);

  if (data.clientPhone) {
      doc.font("Helvetica").text("TÉL:", col2X, textY + 20);
      doc.font("Helvetica-Bold").text(data.clientPhone, col2X + 60, textY + 20);
  }
}

// ✅ UPDATED: Polymorphic Table Builder
function _buildInventoryTable(doc: PDFKit.PDFDocument, systems: any[], serviceType: string = 'Service Technique') {
  const startX = MARGIN;
  let currentY = doc.y;
  const isIT = serviceType === 'Service IT';

  // Column Widths
  const wName = 140;
  const wDetails = 100;
  const wQty = 50;
  const wConfig = 220; // Replaces wSerial

  // -- Table Header --
  doc
    .font("Helvetica-Bold")
    .fontSize(9)
    .fillColor(BRAND_COLOR);

  doc.text("PRODUIT", startX + 5, currentY);
  doc.text("MARQUE / RÉF", startX + wName + 5, currentY);
  doc.text("QTÉ", startX + wName + wDetails, currentY, { width: wQty, align: "center" });

  // ✅ Dynamic Header
  const configHeader = isIT ? "CONFIGURATION (IP / MAC / PORT)" : "NUMÉROS DE SÉRIE";
  doc.text(configHeader, startX + wName + wDetails + wQty + 10, currentY);

  // Header Line
  currentY += 15;
  doc.moveTo(startX, currentY).lineTo(doc.page.width - MARGIN, currentY).strokeColor(BRAND_COLOR).lineWidth(1.5).stroke();
  currentY += 10;

  // -- Table Body --
  doc.font("Helvetica").fontSize(9).fillColor(TEXT_COLOR);

  if (!systems || systems.length === 0) {
    doc.text("Aucun équipement enregistré pour cette installation.", startX, currentY);
    return;
  }

  systems.forEach((item, index) => {
    const name = item.name || "Inconnu";
    const marque = item.marque || item.brand || "-";
    const ref = item.reference || "-";
    const details = `${marque}\n${ref}`;
    const qty = item.quantity || 1;

    // ✅ Dynamic Data Formatting
    let configText = "N/A";

    if (isIT) {
      // Build IT Configuration List
      const lines: string[] = [];
      for (let i = 0; i < qty; i++) {
        const ip = (item.ipAddresses && item.ipAddresses[i]) ? `IP: ${item.ipAddresses[i]}` : null;
        const port = (item.portNumbers && item.portNumbers[i]) ? `Port: ${item.portNumbers[i]}` : null;
        const mac = (item.macAddresses && item.macAddresses[i]) ? `MAC: ${item.macAddresses[i]}` : null;
        const serial = (item.serialNumbers && item.serialNumbers[i]) ? `S/N: ${item.serialNumbers[i]}` : null;

        // Construct line components
        const parts = [ip, port, mac, serial].filter(Boolean); // Remove nulls
        if (parts.length > 0) {
          lines.push(`${qty > 1 ? `[#${i + 1}] ` : ''}${parts.join(" | ")}`);
        }
      }
      configText = lines.length > 0 ? lines.join("\n") : "Non Configuré";

    } else {
      // Standard Technical Serial Numbers
      if (Array.isArray(item.serialNumbers)) {
        const validSerials = item.serialNumbers.filter((s: string) => s && s.trim().length > 0);
        configText = validSerials.length > 0 ? validSerials.join(", ") : "N/A";
      } else if (item.serialNumber) {
        configText = item.serialNumber;
      }
    }

    // Calculate Row Height
    const configHeight = doc.heightOfString(configText, { width: wConfig - 10 });
    const nameHeight = doc.heightOfString(name, { width: wName - 10 });
    const rowHeight = Math.max(configHeight, nameHeight, 30) + 15;

    // Page Break Check
    if (currentY + rowHeight > 720) {
      doc.addPage();
      currentY = MARGIN + 40;
    }

    // Zebra Striping
    if (index % 2 === 0) {
      doc
        .rect(startX, currentY - 5, doc.page.width - MARGIN * 2, rowHeight)
        .fillColor(LIGHT_GRAY_BACKGROUND)
        .fill();
      doc.fillColor(TEXT_COLOR);
    }

    // Content
    doc.text(name, startX + 5, currentY, { width: wName - 10 });
    doc.text(details, startX + wName + 5, currentY, { width: wDetails - 10 });
    doc.text(qty.toString(), startX + wName + wDetails, currentY, { width: wQty, align: "center" });
    doc.text(configText, startX + wName + wDetails + wQty + 10, currentY, { width: wConfig - 10 });

    currentY += rowHeight;

    // Thin Divider
    doc.moveTo(startX, currentY).lineTo(doc.page.width - MARGIN, currentY).strokeColor(LINE_COLOR).lineWidth(0.5).stroke();
    currentY += 10;
  });

  doc.y = currentY;
}

function _buildNotesSection(doc: PDFKit.PDFDocument, notes: string) {
    doc.font("Helvetica-Bold").fontSize(11).fillColor(BRAND_COLOR);
    doc.text("NOTES / TRAVAUX EFFECTUÉS:", MARGIN, doc.y);
    doc.moveDown(0.5);

    doc.font("Helvetica").fontSize(10).fillColor(TEXT_COLOR);
    doc.text(notes, { align: "justify" });
}

async function _buildPhotoGrid(doc: PDFKit.PDFDocument, photoUrls: string[]) {
  doc.font("Helvetica-Bold").fontSize(11).fillColor(BRAND_COLOR);
  doc.text("PHOTOS DE L'INSTALLATION:", MARGIN, doc.y);
  doc.moveDown(0.5);

  const startX = MARGIN;
  let currentY = doc.y;
  const photoSize = 150; // Size of each square photo
  const gap = 10;

  // Limit to 4 photos for layout cleanliness
  const maxPhotos = Math.min(photoUrls.length, 4);

  // Fetch photos in parallel
  const buffers = await Promise.all(photoUrls.slice(0, maxPhotos).map((url) => fetchImage(url)));

  buffers.forEach((buf, i) => {
    if (!buf) return;

    // Grid Logic: 2 columns
    const col = i % 2;
    const row = Math.floor(i / 2);

    const x = startX + (col * (photoSize + gap));
    const y = currentY + (row * (photoSize + gap));

    try {
      doc.image(buf, x, y, { width: photoSize, height: photoSize, fit: [photoSize, photoSize] });
      // Draw border around photo
      doc.rect(x, y, photoSize, photoSize).lineWidth(0.5).strokeColor(LINE_COLOR).stroke();
    } catch (e) {
      logger.warn("Error embedding photo into PDF", e);
    }
  });

  // Advance cursor below the grid
  const rows = Math.ceil(maxPhotos / 2);
  doc.y = currentY + (rows * (photoSize + gap));
}

function _buildSignatureSection(
  doc: PDFKit.PDFDocument,
  data: any,
  clientSig: Buffer | null,
  cache: Buffer | null
) {
  const startY = doc.y + 20; // Extra spacing

  // -- 1. Technician Side (Left) --
  doc.font("Helvetica-Bold").fontSize(10).fillColor(BRAND_COLOR);
  doc.text("TECHNICIEN(S) BOITEX INFO", MARGIN, startY);

  const sigY = startY + 25;

  // Logic: Use assignedTechnicianNames first, fall back to Object Array
  let techNames = "Service Technique";

  if (data.assignedTechnicianNames && Array.isArray(data.assignedTechnicianNames) && data.assignedTechnicianNames.length > 0) {
      techNames = data.assignedTechnicianNames.join("\n");
  } else if (data.assignedTechnicians && Array.isArray(data.assignedTechnicians)) {
      techNames = data.assignedTechnicians
          .map((t: any) => t.displayName || "Technicien")
          .join("\n");
  }

  doc.font("Helvetica").fontSize(10).fillColor(TEXT_COLOR);
  doc.text(techNames, MARGIN, sigY);

  // Place Cache (Stamp) under names
  const namesHeight = doc.heightOfString(techNames, { width: 200 });
  if (cache) {
      doc.image(cache, MARGIN, sigY + namesHeight + 10, { width: 100 });
  }

  // -- 2. Client Side (Right) --
  doc.font("Helvetica-Bold").fontSize(10).fillColor(BRAND_COLOR);
  doc.text("SIGNATURE CLIENT", 350, startY);

  if (clientSig) {
    doc.image(clientSig, 350, sigY, { fit: [150, 80] });
  } else {
    doc.fontSize(9).fillColor(LINE_COLOR).text("(Non signé)", 350, sigY + 30);
  }

  // ✅ Display the Specific Signatory Name
  const clientNameY = sigY + 90;
  doc.font("Helvetica-Bold").fontSize(10).fillColor(TEXT_COLOR);
  const finalSignatory = data.signatoryName || data.contactName || data.clientName || "";
  doc.text(finalSignatory, 350, clientNameY);
}