// Seeds a teacher, an assistant user, 4 groups with ~40 students each,
// a few finished sessions with records, and some payments.
//
// Emulator:  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node seed.mjs
// Real project: set GOOGLE_APPLICATION_CREDENTIALS to a service-account key, then
//               SEED_EMAIL=assistant@example.com SEED_PASSWORD=... node seed.mjs
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT || 'mnara-dev';
initializeApp({ projectId });
const db = getFirestore();
const auth = getAuth();

const email = process.env.SEED_EMAIL || 'assistant@example.com';
const password = process.env.SEED_PASSWORD || 'ChangeMe123';
const tid = 'teacher1';

const names = ['أحمد', 'محمد', 'يوسف', 'عمر', 'كريم', 'مصطفى', 'سلمى', 'منى', 'نور', 'مريم', 'هنا', 'ليلى', 'آية', 'فاطمة', 'حسن', 'علي'];
const lasts = ['علي', 'حسن', 'محمود', 'عادل', 'سمير', 'إبراهيم', 'خالد', 'سعيد'];
const phone = (i) => `010${String(10000000 + i * 7919).slice(-8)}`;
const iso = (d) => d.toISOString().slice(0, 10);

let uid;
try {
  uid = (await auth.getUserByEmail(email)).uid;
} catch {
  uid = (await auth.createUser({ email, password })).uid;
}

await db.doc(`users/${uid}`).set({ role: 'assistant', teacherId: tid, displayName: 'الأسيستنت' });
await db.doc(`teachers/${tid}`).set({
  name: 'مستر أحمد',
  counters: { student: 1000 },
  pricing: { session: 175, month: 700 },
  editWindowDays: 10,
  maxPinAttempts: 10,
  idleLockMinutes: 5,
  sessionsPerMonth: 4,
});

const groupDefs = [
  ['لغات أولى الأربعاء', 'أولى ثانوي', 3, '6:00 م'],
  ['لغات أولى السبت', 'أولى ثانوي', 6, '4:00 م'],
  ['لغات تانية الأحد', 'تانية ثانوي', 7, '5:00 م'],
  ['لغات تالتة الاتنين', 'تالتة ثانوي', 1, '7:00 م'],
];

let counter = 1000;
const today = new Date();
for (const [gi, [name, gradeLabel, dayOfWeek, timeLabel]] of groupDefs.entries()) {
  const gid = `g${gi + 1}`;
  await db.doc(`${'teachers'}/${tid}/groups/${gid}`).set({ name, gradeLabel, dayOfWeek, timeLabel, order: gi, active: true });
  const studentIds = [];
  for (let i = 0; i < 40; i++) {
    counter += 1;
    const sid = `${gid}-s${i + 1}`;
    studentIds.push(sid);
    await db.doc(`teachers/${tid}/students/${sid}`).set({
      code: `S${counter}`,
      isTempCode: false,
      name: `${names[(i + gi) % names.length]} ${lasts[(i * 3 + gi) % lasts.length]}`,
      phone: phone(counter),
      parentPhone: phone(counter + 5000),
      groupId: gid,
      status: 'active',
      createdBy: uid,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      updatedBy: uid,
    });
  }
  // Three finished sessions per group, one week apart.
  for (let k = 3; k >= 1; k--) {
    const d = new Date(today.getTime() - k * 7 * 86400000);
    const date = iso(d);
    const xid = `${gid}-x${4 - k}`;
    await db.doc(`teachers/${tid}/sessions/${xid}`).set({
      groupId: gid, date, number: 4 - k, monthNumber: 1, status: 'finished',
      maxExam: 20, noExam: false, notes: '',
      startedAt: Timestamp.fromDate(d), finishedAt: Timestamp.fromDate(d),
      editableUntil: Timestamp.fromDate(new Date(d.getTime() + 10 * 86400000)),
      createdBy: uid, updatedAt: Timestamp.now(), updatedBy: uid,
    });
    for (const [i, sid] of studentIds.entries()) {
      const present = (i + k) % 7 !== 0;
      await db.doc(`teachers/${tid}/sessions/${xid}/records/${sid}`).set({
        studentId: sid, teacherId: tid,
        attendance: present ? 'present' : 'absent',
        homework: present ? ['excellent', 'very_good', 'good', 'acceptable', 'weak', 'not_submitted'][(i + k) % 6] : null,
        examScore: present ? (i * 3 + k) % 21 : null,
        note: '', kind: 'regular', updatedAt: Timestamp.now(), updatedBy: uid,
      });
    }
  }
  // Payments for the first month: full, partial, or none.
  for (const [i, sid] of studentIds.entries()) {
    if (i % 3 === 2) continue;
    await db.collection(`teachers/${tid}/payments`).add({
      studentId: sid, groupId: gid, month: 1,
      amountEgp: i % 3 === 0 ? 700 : 350,
      method: ['cash', 'instapay', 'vodafone_cash'][i % 3],
      paidOn: iso(today), createdBy: uid, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), updatedBy: uid,
    });
  }
}
await db.doc(`teachers/${tid}`).update({ 'counters.student': counter });
console.log(`Seeded teacher ${tid}; sign in as ${email}.`);
