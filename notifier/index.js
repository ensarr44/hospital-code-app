const admin = require("firebase-admin");
const fs = require("fs");

// Aynı klasördeki hizmet hesabı anahtarı:
const serviceAccount = require("./service-account.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();
const messaging = admin.messaging();

console.log("Yerel bildirim servisi başlıyor...");

// YYYY-MM-DD
function todayId() {
  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

const SEEN_FILE = "seen.json";
let seen = new Set();
try {
  if (fs.existsSync(SEEN_FILE)) {
    const raw = JSON.parse(fs.readFileSync(SEEN_FILE, "utf8"));
    seen = new Set(raw);
  }
} catch {}

db.collection("codes")
  .orderBy("createdAt", "desc")
  .limit(50)
  .onSnapshot(
    async (snap) => {
      for (const change of snap.docChanges()) {
        if (change.type !== "added") continue;

        const id = change.doc.id;
        if (seen.has(id)) continue;

        const data = change.doc.data() || {};
        const color = (data.color || "kod").toString();
        const message = (data.message || "Yeni kod bildirimi!").toString();

        // Bugünün nöbet listesi: shifts/YYYY-MM-DD
        const shiftDoc = await db.doc(`shifts/${todayId()}`).get();
        const staff = (shiftDoc.exists && shiftDoc.get("staff")) || [];
        if (!Array.isArray(staff) || staff.length === 0) {
          console.log("Bugün için shift bulunamadı veya personel listesi boş.");
          continue;
        }

        // personelId'lere göre token'ları 10'arlı IN sorgusuyla çek
        const allTokens = [];
        for (let i = 0; i < staff.length; i += 10) {
          const chunk = staff.slice(i, i + 10);
          const qs = await db
            .collection("tokens")
            .where("personelId", "in", chunk)
            .get();
          qs.forEach((d) => allTokens.push(d.id));
        }

        if (allTokens.length === 0) {
          console.log("Token bulunamadı (tokens koleksiyonu boş olabilir).");
          continue;
        }

        await messaging.sendEachForMulticast({
          tokens: allTokens,
          notification: {
            title: `🚨 ${color.toUpperCase()} KOD`,
            body: message,
          },
          data: { kind: "code", color, date: todayId() },
        });

        console.log(`Bildirim gönderildi: ${color} • ${allTokens.length} cihaza`);

        seen.add(id);
        fs.writeFileSync(SEEN_FILE, JSON.stringify([...seen], null, 2));
      }
    },
    (err) => console.error("Dinleme hatası:", err)
  );
