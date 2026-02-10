const admin = require('firebase-admin');
const fs = require('fs');

// 1. Initialize (Use the same serviceAccountKey.json you used before)
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function importAuth() {
  try {
    // 2. Read the file
    if (!fs.existsSync('users.json')) {
      console.error("❌ Error: 'users.json' file not found.");
      return;
    }

    const rawData = fs.readFileSync('users.json', 'utf8');
    const jsonData = JSON.parse(rawData);

    console.log("🚀 Starting Authentication Import...");

    let usersArray = [];

    // Handle Format
    if (Array.isArray(jsonData)) {
      usersArray = jsonData;
    } else if (jsonData.users && Array.isArray(jsonData.users)) {
      usersArray = jsonData.users;
    } else {
      usersArray = Object.keys(jsonData).map(key => {
        let user = jsonData[key];
        user.uid = key;
        return user;
      });
    }

    let successCount = 0;
    let errorCount = 0;

    // 3. Loop through users and create Auth Accounts
    for (const user of usersArray) {
      const uid = user.uid || user.id || user.localId;
      const email = user.email;

      if (!uid || !email) {
        console.log(`⚠️ Skipping user without UID or Email: ${user.firstName || 'Unknown'}`);
        continue;
      }

      try {
        // Check if user already exists
        try {
          await admin.auth().getUser(uid);
          console.log(`ℹ️ User already exists: ${email}`);
          continue; // Skip if exists
        } catch (e) {
          // User doesn't exist, proceed to create
        }

        // CREATE THE USER
        await admin.auth().createUser({
          uid: uid, // ⚡ IMPORTANT: Keeps the same ID as Firestore
          email: email,
          emailVerified: true,
          password: "boitex2026", // 🔐 TEMPORARY PASSWORD
          displayName: `${user.firstName || ''} ${user.lastName || ''}`.trim(),
          disabled: false
        });

        console.log(`✅ Created Auth for: ${email}`);
        successCount++;

      } catch (error) {
        console.error(`❌ Failed to create ${email}:`, error.message);
        errorCount++;
      }
    }

    console.log(`\n🎉 SUMMARY:`);
    console.log(`✅ Successfully Created: ${successCount}`);
    console.log(`❌ Failed/Skipped: ${errorCount}`);
    console.log(`🔐 Default Password set to: "boitex2026"`);

  } catch (error) {
    console.error("❌ Critical Error:", error);
  }
}

importAuth();