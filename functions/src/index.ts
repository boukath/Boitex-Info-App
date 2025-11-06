// functions/src/index.ts

import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";

// ------------------------------------------------------------------
// 1. INITIALIZE FIREBASE
// ------------------------------------------------------------------
admin.initializeApp();
setGlobalOptions({region: "europe-west1"});

// ------------------------------------------------------------------
// 2. EXPORT ALL MODULARIZED FUNCTIONS
//
// By exporting from these files, Firebase CLI will discover
// all your functions and deploy them.
// ------------------------------------------------------------------

// --- HTTP & Callable Functions ---
export * from "./http/ai_service";
export * from "./http/b2_service";

// --- Scheduled Functions ---
export * from "./scheduled/reminders";

// --- Firestore Triggers ---
export * from "./triggers/announcements";
export * from "./triggers/installations";
export * from "./triggers/interventions";
export * from "./triggers/livraisons";
export * from "./triggers/maintenance_it";
export * from "./triggers/projects";
export * from "./triggers/replacement_requests";
export * from "./triggers/requisitions";
export * from "./triggers/sav_tickets";
export * from "./triggers/support_tickets_it";
export * from "./triggers/generic"; // The generic update loop