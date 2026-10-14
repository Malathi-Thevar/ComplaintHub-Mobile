import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
  collection,
  query,
  where,
  getDocs,
} from 'firebase/firestore';

const PROJECT_ID = 'complainthub-tce-test';
const RULES_PATH = path.resolve('./firestore.rules');

let testEnv;

before(async () => {
  const rules = fs.readFileSync(RULES_PATH, 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Helper identities
const studentA = { uid: 'studentA', token: { email: '820621104001@student.tce.edu' } };
const studentB = { uid: 'studentB', token: { email: '820621104002@student.tce.edu' } };

// -------------------------------------------------------------
// 1. Unauthenticated Access
// -------------------------------------------------------------
test('1. Unauthenticated access is completely blocked across all paths', async () => {
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(unauthDb, 'users/studentA')));
  await assertFails(getDoc(doc(unauthDb, 'complaints/ch100')));
  await assertFails(getDoc(doc(unauthDb, 'registerNumbers/820621104001')));
  await assertFails(
    setDoc(doc(unauthDb, 'complaints/ch100'), {
      id: '#CH100',
      userId: 'anonymous',
      status: 'pending',
    })
  );
});

// -------------------------------------------------------------
// 2. Atomic Student Registration & Unique Register Numbers
// -------------------------------------------------------------
test('2.1 Student A can register atomically with unique register number and profile', async () => {
  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();
  const batch = writeBatch(dbA);

  const regRef = doc(dbA, 'registerNumbers/820621104001');
  batch.set(regRef, {
    uid: studentA.uid,
    createdAt: new Date(),
  });

  const userRef = doc(dbA, `users/${studentA.uid}`);
  batch.set(userRef, {
    uid: studentA.uid,
    registerNumber: '820621104001',
    fullName: 'Arun Kumar S',
    department: 'Computer Science',
    email: studentA.token.email,
    academicYear: 'IV Year',
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  await assertSucceeds(batch.commit());
});

test('2.2 Student B cannot claim an already reserved register number', async () => {
  // Setup: Student A owns 820621104001
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'registerNumbers/820621104001'), {
      uid: studentA.uid,
      createdAt: new Date(),
    });
    await setDoc(doc(adminDb, `users/${studentA.uid}`), {
      uid: studentA.uid,
      registerNumber: '820621104001',
      fullName: 'Arun Kumar S',
      department: 'Computer Science',
      email: studentA.token.email,
      academicYear: 'IV Year',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  // Student B tries to claim 820621104001 in their batch
  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();
  const batch = writeBatch(dbB);

  const regRef = doc(dbB, 'registerNumbers/820621104001');
  batch.set(regRef, {
    uid: studentB.uid,
    createdAt: new Date(),
  });

  const userRef = doc(dbB, `users/${studentB.uid}`);
  batch.set(userRef, {
    uid: studentB.uid,
    registerNumber: '820621104001',
    fullName: 'Bala M',
    department: 'Mechanical',
    email: studentB.token.email,
    academicYear: 'IV Year',
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  await assertFails(batch.commit());
});

test('2.3 Student B cannot read Student A register number reservation (Zero Cross-Student Exposure)', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'registerNumbers/820621104001'), {
      uid: studentA.uid,
      createdAt: new Date(),
    });
  });

  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();
  await assertFails(getDoc(doc(dbB, 'registerNumbers/820621104001')));

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();
  await assertSucceeds(getDoc(doc(dbA, 'registerNumbers/820621104001')));
});

// -------------------------------------------------------------
// 3. Profile Identity Protection & Immutability
// -------------------------------------------------------------
test('3.1 Student can update allowed profile fields (fullName, department)', async () => {
  const createdAt = new Date();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, `users/${studentA.uid}`), {
      uid: studentA.uid,
      registerNumber: '820621104001',
      fullName: 'Arun Kumar S',
      department: 'Computer Science',
      email: studentA.token.email,
      academicYear: 'IV Year',
      createdAt,
      updatedAt: createdAt,
    });
  });

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();
  await assertSucceeds(
    updateDoc(doc(dbA, `users/${studentA.uid}`), {
      fullName: 'Arun Kumar Senior',
      department: 'Data Science',
      updatedAt: new Date(),
    })
  );
});

test('3.2 Student cannot alter immutable identity fields (registerNumber, email, uid, createdAt)', async () => {
  const createdAt = new Date();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, `users/${studentA.uid}`), {
      uid: studentA.uid,
      registerNumber: '820621104001',
      fullName: 'Arun Kumar S',
      department: 'Computer Science',
      email: studentA.token.email,
      academicYear: 'IV Year',
      createdAt,
      updatedAt: createdAt,
    });
  });

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();

  // Attempting to change registerNumber
  await assertFails(
    updateDoc(doc(dbA, `users/${studentA.uid}`), {
      registerNumber: '820621104999',
      updatedAt: new Date(),
    })
  );

  // Attempting to change email
  await assertFails(
    updateDoc(doc(dbA, `users/${studentA.uid}`), {
      email: 'hacker@other.com',
      updatedAt: new Date(),
    })
  );

  // Attempting to delete profile document
  await assertFails(deleteDoc(doc(dbA, `users/${studentA.uid}`)));
});

test('3.3 Student B cannot read or write Student A profile', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, `users/${studentA.uid}`), {
      uid: studentA.uid,
      registerNumber: '820621104001',
      fullName: 'Arun Kumar S',
      department: 'Computer Science',
      email: studentA.token.email,
      academicYear: 'IV Year',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();
  await assertFails(getDoc(doc(dbB, `users/${studentA.uid}`)));
  await assertFails(
    updateDoc(doc(dbB, `users/${studentA.uid}`), {
      fullName: 'Tampered Name',
    })
  );
});

// -------------------------------------------------------------
// 4. Atomic Complaint Creation & Status History Verification
// -------------------------------------------------------------
test('4.1 Student A can submit a complaint with initial status history atomically in one WriteBatch', async () => {
  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();
  const batch = writeBatch(dbA);

  const complaintRef = doc(dbA, 'complaints/comp_001');
  batch.set(complaintRef, {
    id: '#CH1235',
    userId: studentA.uid,
    category: 'Academic',
    concernedDepartment: 'Library',
    subject: 'Books Shortage',
    description: 'Reference books for Semester 7 are unavailable.',
    status: 'pending',
    submittedAt: new Date(),
    updatedAt: new Date(),
  });

  const statusRef = doc(dbA, 'complaints/comp_001/statusHistory/initial');
  batch.set(statusRef, {
    title: 'Complaint Submitted',
    description: 'Complaint submitted successfully.',
    status: 'pending',
    timestamp: new Date(),
    isCompleted: true,
    isActive: false,
    updatedBy: studentA.uid,
  });

  await assertSucceeds(batch.commit());
});

test('4.2 Student A cannot submit a complaint with non-pending status or forged owner UID', async () => {
  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();

  // Non-pending status
  await assertFails(
    setDoc(doc(dbA, 'complaints/comp_bad_status'), {
      id: '#CH1236',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Invalid Status Test',
      description: 'Attempting to self-resolve.',
      status: 'resolved',
      submittedAt: new Date(),
      updatedAt: new Date(),
    })
  );

  // Forged owner UID
  await assertFails(
    setDoc(doc(dbA, 'complaints/comp_forged_owner'), {
      id: '#CH1237',
      userId: studentB.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Forged Owner Test',
      description: 'Attempting to forge owner UID.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    })
  );
});

test('4.3 Student cannot create arbitrary or subsequent statusHistory entries', async () => {
  // Setup: comp_001 already exists
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();

  // Attempting to append a fake transition (e.g. entry_2)
  await assertFails(
    setDoc(doc(dbA, 'complaints/comp_001/statusHistory/entry_2'), {
      title: 'Resolved by Student',
      description: 'Fake self resolution.',
      status: 'resolved',
      timestamp: new Date(),
      isCompleted: true,
      isActive: false,
      updatedBy: studentA.uid,
    })
  );

  // Attempting to create 'initial' after complaint doc is already existing
  await assertFails(
    setDoc(doc(dbA, 'complaints/comp_001/statusHistory/initial'), {
      title: 'Complaint Submitted',
      description: 'Belated initial entry.',
      status: 'pending',
      timestamp: new Date(),
      isCompleted: true,
      isActive: false,
      updatedBy: studentA.uid,
    })
  );
});

test('4.4 Student cannot update or delete existing complaints or status history', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/statusHistory/initial'), {
      title: 'Complaint Submitted',
      description: 'Complaint submitted successfully.',
      status: 'pending',
      timestamp: new Date(),
      isCompleted: true,
      isActive: false,
      updatedBy: studentA.uid,
    });
  });

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();

  // Try updating complaint status
  await assertFails(
    updateDoc(doc(dbA, 'complaints/comp_001'), {
      status: 'resolved',
    })
  );

  // Try deleting complaint
  await assertFails(deleteDoc(doc(dbA, 'complaints/comp_001')));

  // Try updating status history
  await assertFails(
    updateDoc(doc(dbA, 'complaints/comp_001/statusHistory/initial'), {
      status: 'resolved',
    })
  );

  // Try deleting status history
  await assertFails(deleteDoc(doc(dbA, 'complaints/comp_001/statusHistory/initial')));
});

test('4.5 Student B cannot read Student A complaint or status history by direct document read', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/statusHistory/initial'), {
      title: 'Complaint Submitted',
      description: 'Complaint submitted successfully.',
      status: 'pending',
      timestamp: new Date(),
      isCompleted: true,
      isActive: false,
      updatedBy: studentA.uid,
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/followUps/fu_1'), {
      userId: studentA.uid,
      authorName: 'Arun Kumar S',
      description: 'Follow-up regarding book status.',
      timestamp: new Date(),
    });
  });

  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();
  // Direct document read of complaint
  await assertFails(getDoc(doc(dbB, 'complaints/comp_001')));
  // Direct document read of status history
  await assertFails(getDoc(doc(dbB, 'complaints/comp_001/statusHistory/initial')));
  // Direct document read of follow-ups
  await assertFails(getDoc(doc(dbB, 'complaints/comp_001/followUps/fu_1')));
});

test('4.6 Student B cannot discover Student A complaints via queries (unrestricted or filtered)', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();

  // Unrestricted collection query must fail
  await assertFails(getDocs(collection(dbB, 'complaints')));

  // Query filtering for student A's UID must fail
  await assertFails(
    getDocs(query(collection(dbB, 'complaints'), where('userId', '==', studentA.uid)))
  );

  // Subcollection queries must fail
  await assertFails(getDocs(collection(dbB, 'complaints/comp_001/statusHistory')));
  await assertFails(getDocs(collection(dbB, 'complaints/comp_001/followUps')));
});

test('4.7 Unauthenticated user cannot read complaints, status history, or follow-ups', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/statusHistory/initial'), {
      title: 'Complaint Submitted',
      description: 'Complaint submitted successfully.',
      status: 'pending',
      timestamp: new Date(),
      isCompleted: true,
      isActive: false,
      updatedBy: studentA.uid,
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/followUps/fu_1'), {
      userId: studentA.uid,
      authorName: 'Arun Kumar S',
      description: 'Follow-up regarding book status.',
      timestamp: new Date(),
    });
  });

  const unauthDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(unauthDb, 'complaints/comp_001')));
  await assertFails(getDocs(collection(unauthDb, 'complaints')));
  await assertFails(getDoc(doc(unauthDb, 'complaints/comp_001/statusHistory/initial')));
  await assertFails(getDocs(collection(unauthDb, 'complaints/comp_001/statusHistory')));
  await assertFails(getDoc(doc(unauthDb, 'complaints/comp_001/followUps/fu_1')));
  await assertFails(getDocs(collection(unauthDb, 'complaints/comp_001/followUps')));
});

test('4.8 Legitimate owner (Student A) can read their own complaint, status history, follow-ups, and run owner-filtered queries', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/statusHistory/initial'), {
      title: 'Complaint Submitted',
      description: 'Complaint submitted successfully.',
      status: 'pending',
      timestamp: new Date(),
      isCompleted: true,
      isActive: false,
      updatedBy: studentA.uid,
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/followUps/fu_1'), {
      userId: studentA.uid,
      authorName: 'Arun Kumar S',
      description: 'Follow-up note.',
      timestamp: new Date(),
    });
  });

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();

  // Legitimate owner direct read
  await assertSucceeds(getDoc(doc(dbA, 'complaints/comp_001')));

  // Legitimate owner status history read
  await assertSucceeds(getDoc(doc(dbA, 'complaints/comp_001/statusHistory/initial')));
  await assertSucceeds(getDocs(collection(dbA, 'complaints/comp_001/statusHistory')));

  // Legitimate owner follow-ups read
  await assertSucceeds(getDoc(doc(dbA, 'complaints/comp_001/followUps/fu_1')));
  await assertSucceeds(getDocs(collection(dbA, 'complaints/comp_001/followUps')));

  // Legitimate owner query filtered by their own userId
  await assertSucceeds(
    getDocs(query(collection(dbA, 'complaints'), where('userId', '==', studentA.uid)))
  );
});

// -------------------------------------------------------------
// 5. Follow-Up Notes
// -------------------------------------------------------------
test('5.1 Complaint owner can append follow-up note, but cannot edit or delete it', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();
  const fuRef = doc(dbA, 'complaints/comp_001/followUps/fu_1');

  // Allowed create
  await assertSucceeds(
    setDoc(fuRef, {
      userId: studentA.uid,
      authorName: 'Arun Kumar S',
      description: 'Please expedite book ordering.',
      timestamp: new Date(),
    })
  );

  // Denied update
  await assertFails(
    updateDoc(fuRef, {
      description: 'Tampered follow up.',
    })
  );

  // Denied delete
  await assertFails(deleteDoc(fuRef));
});

test('5.2 Non-owner cannot add follow-up to another student complaint', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();
  await assertFails(
    setDoc(doc(dbB, 'complaints/comp_001/followUps/fu_b'), {
      userId: studentB.uid,
      authorName: 'Bala M',
      description: 'Unauthorized comment.',
      timestamp: new Date(),
    })
  );
});

test('5.3 Student B cannot read Student A follow-up subcollection', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'complaints/comp_001'), {
      id: '#CH1235',
      userId: studentA.uid,
      category: 'Academic',
      concernedDepartment: 'Library',
      subject: 'Books Shortage',
      description: 'Reference books for Semester 7 are unavailable.',
      status: 'pending',
      submittedAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(adminDb, 'complaints/comp_001/followUps/fu_1'), {
      userId: studentA.uid,
      authorName: 'Arun Kumar S',
      description: 'Confidential follow-up.',
      timestamp: new Date(),
    });
  });

  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();
  await assertFails(getDoc(doc(dbB, 'complaints/comp_001/followUps/fu_1')));
  await assertFails(getDocs(collection(dbB, 'complaints/comp_001/followUps')));
});

// -------------------------------------------------------------
// 6. Notification Lockdown & Read-State Mutations
// -------------------------------------------------------------
test('6.1 Student cannot create notifications or fake announcements (Anti-Forgery)', async () => {
  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();

  await assertFails(
    setDoc(doc(dbA, `users/${studentA.uid}/notifications/notif_fake`), {
      id: 'notif_fake',
      title: 'Fake Official Announcement: College Closed',
      description: 'Forged message.',
      timestamp: new Date(),
      isRead: false,
      isNew: true,
      isAnnouncement: true,
    })
  );
});

test('6.2 Student can read their own notifications and update only read-state flags', async () => {
  // System creates notification
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, `users/${studentA.uid}/notifications/notif_1`), {
      id: 'notif_1',
      title: 'Your complaint was received',
      description: 'Library is reviewing it.',
      timestamp: new Date(),
      isRead: false,
      isNew: true,
      complaintId: '#CH1235',
      isAnnouncement: false,
    });
  });

  const dbA = testEnv.authenticatedContext(studentA.uid, studentA.token).firestore();
  const notifRef = doc(dbA, `users/${studentA.uid}/notifications/notif_1`);

  // Student can read
  await assertSucceeds(getDoc(notifRef));

  // Student can update isRead and isNew
  await assertSucceeds(
    updateDoc(notifRef, {
      isRead: true,
      isNew: false,
    })
  );

  // Student cannot tamper with notification text or announcement status
  await assertFails(
    updateDoc(notifRef, {
      title: 'Hacked Title',
    })
  );

  await assertFails(
    updateDoc(notifRef, {
      isAnnouncement: true,
    })
  );
});

test('6.3 Student B cannot read Student A notifications', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, `users/${studentA.uid}/notifications/notif_1`), {
      id: 'notif_1',
      title: 'Private Alert',
      description: 'Confidential.',
      timestamp: new Date(),
      isRead: false,
      isNew: true,
      isAnnouncement: false,
    });
  });

  const dbB = testEnv.authenticatedContext(studentB.uid, studentB.token).firestore();
  await assertFails(getDoc(doc(dbB, `users/${studentA.uid}/notifications/notif_1`)));
});
