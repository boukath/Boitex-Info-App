// functions/src/core/constants.ts

// ==================================================================
// FCM TOPIC NAMES (Used for Push Notifications)
// NOTE: These MUST match the topic names your app subscribes to.
// I am standardizing on the underscore format you used.
// ==================================================================
export const TOPIC_MANAGERS = "manager_notifications";
export const TOPIC_TECH_ST = "technician_st_alerts";
export const TOPIC_TECH_IT = "technician_it_alerts";
export const TOPIC_GLOBAL_ANNOUNCEMENTS = "GLOBAL_ANNOUNCEMENTS";

// Specific Role Topics (as seen in requisitions/projects)
export const TOPIC_PDG = "PDG";
export const TOPIC_ADMIN = "Admin";
export const TOPIC_RESP_ADMIN = "Responsable_Administratif";
export const TOPIC_RESP_COMM = "Responsable_Commercial";
export const TOPIC_RESP_TECH = "Responsable_Technique";
export const TOPIC_RESP_IT = "ResponsABLE_IT"; // Your original file had a typo, check if this is correct
export const TOPIC_CHEF_PROJET = "Chef_de_Projet";


// ==================================================================
// FIRESTORE ROLE NAMES (Used for Inbox Notifications)
// NOTE: These MUST match the 'role' field in your 'users' collection.
// I am standardizing on the space format.
// ==================================================================
export const ROLE_PDG = "PDG";
export const ROLE_ADMIN = "Admin";
export const ROLE_RESP_ADMIN = "Responsable Administratif";
export const ROLE_RESP_COMM = "Responsable Commercial";
export const ROLE_RESP_TECH = "Responsable Technique";
export const ROLE_RESP_IT = "Responsable IT";
export const ROLE_CHEF_PROJET = "Chef de Projet";
export const ROLE_TECH_ST = "Technicien ST";
export const ROLE_TECH_IT = "Technicien IT";

// --- Grouped Role Lists ---

export const ROLES_MANAGERS = [
ROLE_ADMIN,
ROLE_PDG,
ROLE_RESP_ADMIN,
ROLE_RESP_COMM,
ROLE_RESP_TECH,
ROLE_RESP_IT,
ROLE_CHEF_PROJET,
];

export const ROLES_TECH_ST = [ROLE_TECH_ST];
export const ROLES_TECH_IT = [ROLE_TECH_IT];

// --- Grouped Topic Lists ---

export const TOPICS_MANAGERS_AND_ADMINS = [
TOPIC_PDG,
TOPIC_ADMIN,
TOPIC_RESP_ADMIN,
TOPIC_RESP_COMM,
TOPIC_RESP_TECH,
TOPIC_RESP_IT, // Assuming typo fix
TOPIC_CHEF_PROJET,
];