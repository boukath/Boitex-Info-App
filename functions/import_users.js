const admin = require('firebase-admin');
const fs = require('fs');

// 1. Initialize Firebase with your new project credentials
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importUsers() {
  try {
    // 2. Read the file
    if (!fs.existsSync('users.json')) {
      console.error("❌ Error: 'users.json' file not found in this folder.");
      return;
    }

    const rawData = fs.readFileSync('users.json', 'utf8');
    const jsonData = JSON.parse(rawData);

    console.log("🚀 Starting Import...");

    let usersArray = [];

    // Handle different JSON formats (Array vs Object Map)
    if (Array.isArray(jsonData)) {
      usersArray = jsonData;
    } else if (jsonData.users && Array.isArray(jsonData.users)) {
      usersArray = jsonData.users;
    } else {
      // If it's a map {"uid1": {data}, "uid2": {data}}
      usersArray = Object.keys(jsonData).map(key => {
        let user = jsonData[key];
        user.uid = key; // Ensure UID is preserved
        return user;
      });
    }

    let count = 0;
    const batchSize = 500;
    let batch = db.batch();

    for (const user of usersArray) {
      // ⚠️ CRITICAL: Validate UID
      // If the JSON object doesn't have a 'uid' field, we skip or rely on the key map above
      const uid = user.uid || user.id || user.localId;

      if (!uid) {
        console.warn("⚠️ Skipping user without UID:", JSON.stringify(user).substring(0, 50));
        continue;
      }

      // 🧹 CLEANUP: Remove old tokens immediately
      delete user.fcmToken;
      delete user.fcmTokenMobile;
      delete user.fcmTokenWeb;
      delete user.fcmTokens;

      // Add optional flag so you know this was imported
      user.importedAt = admin.firestore.FieldValue.serverTimestamp();

      // Add to batch
      const userRef = db.collection('users').doc(uid);

      // ✅ FIX: We must pass 'userRef' first, then the data 'user'
      batch.set(userRef, user, { merge: true });

      count++;

      // Commit batch if full
      if (count % batchSize === 0) {
        await batch.commit();
        console.log(`✅ Imported ${count} users...`);
        batch = db.batch();
      }
    }

    // Final commit
    if (count % batchSize !== 0) {
      await batch.commit();
    }

    console.log(`🎉 COMPLETED! Successfully imported/cleaned ${count} users.`);
    console.log("👉 Now ask your users to restart their app to generate new tokens.");

  } catch (error) {
    console.error("❌ Error importing users:", error);
  }
}

importUsers();