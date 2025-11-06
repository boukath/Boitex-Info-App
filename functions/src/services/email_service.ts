// functions/src/services/email_service.ts


import * as nodemailer from "nodemailer";
import {defineSecret} from "firebase-functions/params";

// 1. Define the secrets this file needs to access
const smtpHost = defineSecret("SMTP_HOST");
const smtpPort = defineSecret("SMTP_PORT");
const smtpUser = defineSecret("SMTP_USER");
const smtpPass = defineSecret("SMTP_PASS");

/**
* Sends an email with a PDF attachment using cPanel SMTP credentials.
*
* @param {string} toEmail The recipient's email address.
* @param {string} subject The subject line of the email.
* @param {string} htmlBody The HTML content for the email body.
* @param {Buffer} pdfBuffer The raw PDF data as a Buffer.
* @param {string} filename The desired filename for the PDF attachment (e.g., "report.pdf").
*/
export const sendEmailWithAttachment = async (
toEmail: string,
subject: string,
htmlBody: string,
pdfBuffer: Buffer,
filename: string
) => {
// We must run this inside a function that has the secrets "injected"
// so we pass them to an internal helper function.
const host = smtpHost.value();
const port = parseInt(smtpPort.value(), 10);
const user = smtpUser.value();
const pass = smtpPass.value();

// 2. Create a "transporter" - the object that sends the email
const transporter = nodemailer.createTransport({
host: host,
port: port,
secure: port === 465, // true for port 465, false for other ports
auth: {
user: user,
pass: pass,
},
// Add this for cPanel self-signed certificates
tls: {
rejectUnauthorized: false,
},
});

// 3. Define the email options
const mailOptions = {
from: `"Boitex Info Service" <${user}>`, // Sender address
to: toEmail, // List of receivers
subject: subject, // Subject line
html: htmlBody, // HTML body
attachments: [
{
filename: filename,
content: pdfBuffer,
contentType: "application/pdf",
},
],
};

// 4. Send the email
try {
const info = await transporter.sendMail(mailOptions);
console.log(`✅ Email sent successfully to ${toEmail}: ${info.messageId}`);
  } catch (error) {
    console.error(`❌ Error sending email to ${toEmail}:`, error);
    // We throw the error so the calling function knows it failed
    throw new Error(`Failed to send email: ${error}`);
  }
};

/**
 * Defines the secrets needed for the email service.
 * This array is used by the main function to grant access.
 */
export const emailSecrets = [
  smtpHost,
  smtpPort,
  smtpUser,
  smtpPass,
];