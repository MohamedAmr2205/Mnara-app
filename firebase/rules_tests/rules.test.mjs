import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const T = 'teachers/t1';
const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;
let env;

const ts = (offsetMs) => Timestamp.fromMillis(Date.now() + offsetMs);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'mnara-test',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/asst'), { role: 'assistant', teacherId: 't1', displayName: 'A' });
    await setDoc(doc(db, 'users/other'), { role: 'assistant', teacherId: 't2', displayName: 'B' });
    await setDoc(doc(db, 'users/boss'), { role: 'teacher', teacherId: 't1', displayName: 'T' });
    await setDoc(doc(db, T), {
      name: 'T',
      counters: { student: 1000 },
      pricing: { session: 175, month: 700 },
    });
    await setDoc(doc(db, `${T}/groups/g1`), { name: 'G' });
    await setDoc(doc(db, `${T}/students/s1`), student());
    await setDoc(doc(db, `${T}/sessions/open`), session({ editableUntil: ts(5 * DAY) }));
    await setDoc(doc(db, `${T}/sessions/old`), session({ editableUntil: ts(-1 * DAY), status: 'finished' }));
    await setDoc(doc(db, `${T}/sessions/open/records/s1`), record());
    await setDoc(doc(db, `${T}/sessions/old/records/s1`), record());
    await setDoc(doc(db, `${T}/payments/fresh`), payment({ createdAt: ts(-1 * HOUR) }));
    await setDoc(doc(db, `${T}/payments/stale`), payment({ createdAt: ts(-30 * HOUR) }));
  });
});

function student(over = {}) {
  return {
    code: 'S1001',
    isTempCode: false,
    name: 'Ahmed',
    phone: '01012345678',
    parentPhone: '01112345678',
    groupId: 'g1',
    status: 'active',
    createdBy: 'asst',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    updatedBy: 'asst',
    ...over,
  };
}

function session(over = {}) {
  return {
    groupId: 'g1',
    date: '2026-11-25',
    number: 3,
    monthNumber: 2,
    status: 'open',
    maxExam: 20,
    noExam: false,
    notes: '',
    startedAt: Timestamp.now(),
    editableUntil: ts(5 * DAY),
    createdBy: 'asst',
    updatedAt: Timestamp.now(),
    updatedBy: 'asst',
    ...over,
  };
}

function record(over = {}) {
  return {
    studentId: 's1',
    teacherId: 't1',
    attendance: 'present',
    homework: 'good',
    examScore: 17,
    note: '',
    kind: 'regular',
    updatedAt: Timestamp.now(),
    updatedBy: 'asst',
    ...over,
  };
}

function payment(over = {}) {
  return {
    studentId: 's1',
    groupId: 'g1',
    month: 2,
    amountEgp: 300,
    method: 'cash',
    paidOn: '2026-11-25',
    createdBy: 'asst',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    updatedBy: 'asst',
    ...over,
  };
}

const asst = () => env.authenticatedContext('asst').firestore();

describe('access control', () => {
  it('denies unauthenticated reads', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, `${T}/students/s1`)));
  });

  it('denies a different teacher\'s assistant', async () => {
    const db = env.authenticatedContext('other').firestore();
    await assertFails(getDoc(doc(db, `${T}/students/s1`)));
  });

  it('denies users whose role is not assistant', async () => {
    const db = env.authenticatedContext('boss').firestore();
    await assertFails(getDoc(doc(db, `${T}/students/s1`)));
  });

  it('allows the assistant to read own teacher data', async () => {
    await assertSucceeds(getDoc(doc(asst(), `${T}/students/s1`)));
    await assertSucceeds(getDoc(doc(asst(), `${T}/groups/g1`)));
  });

  it('lets a user read only their own profile', async () => {
    await assertSucceeds(getDoc(doc(asst(), 'users/asst')));
    await assertFails(getDoc(doc(asst(), 'users/other')));
  });

  it('denies writes to groups and unknown collections', async () => {
    await assertFails(setDoc(doc(asst(), `${T}/groups/g2`), { name: 'x' }));
    await assertFails(setDoc(doc(asst(), `${T}/secrets/x`), { a: 1 }));
  });
});

describe('students', () => {
  const create = (data) => setDoc(doc(asst(), `${T}/students/new1`), data);

  it('creates a valid student', async () => {
    await assertSucceeds(create(student({ code: 'N-AB12', isTempCode: true })));
  });

  it('rejects an invalid student phone', async () => {
    await assertFails(create(student({ phone: '0123' })));
  });

  it('rejects an invalid parent phone prefix', async () => {
    await assertFails(create(student({ parentPhone: '01312345678' })));
  });

  it('rejects an unknown status', async () => {
    await assertFails(create(student({ status: 'gone' })));
  });

  it('forbids deleting students', async () => {
    await assertFails(deleteDoc(doc(asst(), `${T}/students/s1`)));
  });

  it('allows deactivating a student', async () => {
    await assertSucceeds(
      updateDoc(doc(asst(), `${T}/students/s1`), {
        status: 'inactive',
        updatedAt: serverTimestamp(),
        updatedBy: 'asst',
      }),
    );
  });

  it('forbids moving a student to another group', async () => {
    await assertFails(updateDoc(doc(asst(), `${T}/students/s1`), { groupId: 'g9' }));
  });
});

describe('counters', () => {
  it('allows raising counters.student', async () => {
    await assertSucceeds(
      updateDoc(doc(asst(), T), { counters: { student: 1003 } }),
    );
  });

  it('denies lowering counters.student', async () => {
    await assertFails(updateDoc(doc(asst(), T), { counters: { student: 999 } }));
  });

  it('denies huge jumps', async () => {
    await assertFails(updateDoc(doc(asst(), T), { counters: { student: 5000 } }));
  });

  it('denies changing pricing', async () => {
    await assertFails(updateDoc(doc(asst(), T), { pricing: { session: 1, month: 1 } }));
  });
});

describe('sessions and the edit window', () => {
  it('creates a session with a sane editableUntil', async () => {
    await assertSucceeds(
      setDoc(doc(asst(), `${T}/sessions/new1`), session({ editableUntil: ts(10 * DAY) })),
    );
  });

  it('rejects a session whose window is already closed', async () => {
    await assertFails(
      setDoc(doc(asst(), `${T}/sessions/new2`), session({ editableUntil: ts(-1 * HOUR) })),
    );
  });

  it('rejects a session with an absurd window', async () => {
    await assertFails(
      setDoc(doc(asst(), `${T}/sessions/new3`), session({ editableUntil: ts(40 * DAY) })),
    );
  });

  it('allows updating a session inside the window', async () => {
    await assertSucceeds(
      updateDoc(doc(asst(), `${T}/sessions/open`), { notes: 'ok', status: 'finished' }),
    );
  });

  it('denies updating a session after the window', async () => {
    await assertFails(updateDoc(doc(asst(), `${T}/sessions/old`), { notes: 'late' }));
  });

  it('denies changing editableUntil', async () => {
    await assertFails(
      updateDoc(doc(asst(), `${T}/sessions/open`), { editableUntil: ts(9 * DAY) }),
    );
  });

  it('allows cancelling an open session only', async () => {
    await assertSucceeds(deleteDoc(doc(asst(), `${T}/sessions/open`)));
    await assertFails(deleteDoc(doc(asst(), `${T}/sessions/old`)));
  });

  it('allows record writes inside the window', async () => {
    await assertSucceeds(
      setDoc(doc(asst(), `${T}/sessions/open/records/s2`), record({ studentId: 's2' })),
    );
  });

  it('denies record writes after the window', async () => {
    await assertFails(
      setDoc(doc(asst(), `${T}/sessions/old/records/s1`), record({ attendance: 'absent' })),
    );
    await assertFails(deleteDoc(doc(asst(), `${T}/sessions/old/records/s1`)));
  });

  it('rejects invalid attendance and homework values', async () => {
    const path = `${T}/sessions/open/records/s2`;
    await assertFails(setDoc(doc(asst(), path), record({ attendance: 'sleepy' })));
    await assertFails(setDoc(doc(asst(), path), record({ homework: 'perfect' })));
  });

  it('rejects a negative exam score and a record for another teacher', async () => {
    const path = `${T}/sessions/open/records/s2`;
    await assertFails(setDoc(doc(asst(), path), record({ examScore: -1 })));
    await assertFails(setDoc(doc(asst(), path), record({ teacherId: 't2' })));
  });

  it('lets collection-group reads see own records only', async () => {
    const { collectionGroup, getDocs, query, where } = await import('firebase/firestore');
    const q = query(collectionGroup(asst(), 'records'), where('teacherId', '==', 't1'));
    await assertSucceeds(getDocs(q));
    const otherDb = env.authenticatedContext('other').firestore();
    const q2 = query(collectionGroup(otherDb, 'records'), where('teacherId', '==', 't1'));
    await assertFails(getDocs(q2));
  });
});

describe('payments', () => {
  const create = (data) => setDoc(doc(asst(), `${T}/payments/new1`), data);

  it('creates a valid payment', async () => {
    await assertSucceeds(create(payment({ createdAt: serverTimestamp() })));
  });

  it('rejects a zero or fractional amount', async () => {
    await assertFails(create(payment({ amountEgp: 0, createdAt: serverTimestamp() })));
    await assertFails(create(payment({ amountEgp: 10.5, createdAt: serverTimestamp() })));
  });

  it('rejects an unknown payment method', async () => {
    await assertFails(create(payment({ method: 'bitcoin', createdAt: serverTimestamp() })));
  });

  it('rejects a payment created by someone else', async () => {
    await assertFails(create(payment({ createdBy: 'other', createdAt: serverTimestamp() })));
  });

  it('lets the creator edit within 24 hours', async () => {
    await assertSucceeds(updateDoc(doc(asst(), `${T}/payments/fresh`), { amountEgp: 250 }));
    await assertSucceeds(deleteDoc(doc(asst(), `${T}/payments/fresh`)));
  });

  it('denies edits and deletes after 24 hours', async () => {
    await assertFails(updateDoc(doc(asst(), `${T}/payments/stale`), { amountEgp: 250 }));
    await assertFails(deleteDoc(doc(asst(), `${T}/payments/stale`)));
  });
});

describe('meta', () => {
  it('stores the active session id', async () => {
    await assertSucceeds(setDoc(doc(asst(), `${T}/meta/app`), { activeSessionId: 'open' }));
  });

  it('rejects unknown meta fields', async () => {
    await assert.doesNotReject(async () => {
      await assertFails(setDoc(doc(asst(), `${T}/meta/app`), { admin: true }));
    });
  });
});
