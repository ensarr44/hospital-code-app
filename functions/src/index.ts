import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * codes/{docId} içine yeni belge eklenince tetiklenir.
 * tokens koleksiyonundaki belge id'lerini (FCM token) toplayıp bildirim yollar.
 */
export const onCodeCreated = onDocumentCreated("codes/{docId}", async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log("Event data yok.");
    return;
  }

  const data = snap.data() as {
    color?: string;
    message?: string;
    createdAt?: FirebaseFirestore.FieldValue;
  };

  const kodRengi = (data?.color ?? "bilinmiyor").toString();
  const mesaj = (data?.message ?? "Yeni kod bildirimi!").toString();

  // tokens koleksiyonundan tüm tokenları çek
  const tokensSnap = await admin.firestore().collection("tokens").get();
  const tokens: string[] = tokensSnap.docs.map((d) => d.id);

  if (tokens.length === 0) {
    console.log("Gönderilecek token yok (tokens koleksiyonu boş).");
    return;
  }

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: `🚨 ${kodRengi.toUpperCase()} KOD`,
      body: mesaj,
    },
    data: {
      kind: "code",
      color: kodRengi,
    },
  });

  console.log(`Bildirim ${tokens.length} cihaza gönderildi.`);
});
