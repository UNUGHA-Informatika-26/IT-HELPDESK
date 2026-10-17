import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test, { after, before, beforeEach } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const projectId = 'demo-it-helpdesk';
let environment;

const waitingTicket = (overrides = {}) => ({
  ticketNumber: 'HD-ABC123',
  title: 'Printer tidak mencetak',
  description: 'Printer ruang operasional tidak merespons.',
  category: 'Printer',
  priority: 'Segera',
  status: 'Menunggu',
  userId: 'employee-1',
  userName: 'Ayu Lestari',
  companyId: 'company-1',
  createdAt: new Date(),
  updatedAt: new Date(),
  resolvedAt: null,
  ...overrides,
});

before(async () => {
  const rules = await readFile(path.join(root, 'firestore.rules'), 'utf8');
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'company_codes/ABC123'), {
      companyId: 'company-1',
      active: true,
    });
    await setDoc(doc(db, 'users/employee-1'), {
      name: 'Ayu Lestari',
      email: 'ayu@example.com',
      role: 'user',
      companyId: 'company-1',
      companyCode: 'ABC123',
      status: 'active',
      department: 'Operasional',
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'users/employee-2'), {
      name: 'Bima Putra',
      email: 'bima@example.com',
      role: 'user',
      companyId: 'company-1',
      companyCode: 'ABC123',
      status: 'active',
      department: 'Keuangan',
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'users/admin-1'), {
      name: 'Budi Santoso',
      email: 'budi@example.com',
      role: 'admin',
      companyId: 'company-1',
      companyCode: 'ABC123',
      status: 'active',
      department: '',
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'users/admin-2'), {
      name: 'Admin Dua',
      email: 'admin2@example.com',
      role: 'admin',
      companyId: 'company-2',
      companyCode: 'UJI-2026',
      status: 'active',
      department: '',
      createdAt: new Date(),
    });
    await setDoc(
      doc(db, 'tickets/ABC123waiting'),
      waitingTicket({ ticketNumber: 'HD-ABC123' }),
    );
    await setDoc(
      doc(db, 'tickets/processing'),
      waitingTicket({
        ticketNumber: 'HD-PROCES',
        status: 'Diproses',
      }),
    );
    await setDoc(
      doc(db, 'tickets/cancelled'),
      waitingTicket({
        ticketNumber: 'HD-CANCEL',
        status: 'Dibatalkan',
      }),
    );
    await setDoc(
      doc(db, 'tickets/other-employee-ticket'),
      waitingTicket({
        ticketNumber: 'HD-OTHER2',
        userId: 'employee-2',
      }),
    );
    await setDoc(
      doc(db, 'tickets/other-company'),
      waitingTicket({
        ticketNumber: 'HD-OTHER1',
        userId: 'somebody',
        companyId: 'company-2',
      }),
    );
  });
});

after(async () => {
  await environment?.cleanup();
});

test('employees cannot change their role or company ID', async () => {
  const db = environment.authenticatedContext('employee-1').firestore();
  await assertFails(
    updateDoc(doc(db, 'users/employee-1'), {
      role: 'admin',
      companyId: 'company-2',
    }),
  );
});

test('employees cannot read another employee ticket', async () => {
  const db = environment.authenticatedContext('employee-1').firestore();
  await assertFails(getDoc(doc(db, 'tickets/other-employee-ticket')));
});

test('admins cannot read tickets from another company', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertFails(getDoc(doc(db, 'tickets/other-company')));
});

test('employees cannot edit tickets that are already processing', async () => {
  const db = environment.authenticatedContext('employee-1').firestore();
  await assertFails(
    updateDoc(doc(db, 'tickets/processing'), {
      title: 'Judul baru',
      updatedAt: new Date(),
    }),
  );
  await assertFails(
    updateDoc(doc(db, 'tickets/processing'), {
      status: 'Dibatalkan',
      updatedAt: new Date(),
    }),
  );
});

test('admins cannot change cancelled tickets', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertFails(
    updateDoc(doc(db, 'tickets/cancelled'), {
      status: 'Diproses',
      updatedAt: new Date(),
      resolvedAt: null,
    }),
  );
});

test('guests may get a single company code but cannot list codes', async () => {
  const db = environment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(db, 'company_codes/ABC123')));
  await assertFails(getDocs(collection(db, 'company_codes')));
});

test('employees cannot write ticket status updates', async () => {
  const db = environment.authenticatedContext('employee-1').firestore();
  await assertFails(
    setDoc(doc(db, 'tickets/ABC123waiting/updates/update-1'), {
      adminId: 'employee-1',
      adminName: 'Ayu Lestari',
      oldStatus: 'Menunggu',
      newStatus: 'Diproses',
      note: 'Sedang ditangani',
      createdAt: new Date(),
    }),
  );
});

test('no one can delete tickets', async () => {
  const employeeDb = environment.authenticatedContext('employee-1').firestore();
  const adminDb = environment.authenticatedContext('admin-1').firestore();
  const guestDb = environment.unauthenticatedContext().firestore();

  await assertFails(deleteDoc(doc(employeeDb, 'tickets/ABC123waiting')));
  await assertFails(deleteDoc(doc(adminDb, 'tickets/ABC123waiting')));
  await assertFails(deleteDoc(doc(guestDb, 'tickets/ABC123waiting')));
});

test('employees cannot create a profile with the admin role', async () => {
  const db = environment.authenticatedContext('new-user').firestore();
  await assertFails(
    setDoc(doc(db, 'users/new-user'), {
      name: 'Akun Palsu',
      email: 'fake@example.com',
      role: 'admin',
      companyId: 'company-1',
      companyCode: 'ABC123',
      status: 'active',
      department: 'IT',
      createdAt: new Date(),
    }),
  );
});

test('admin status and update history are authorized together in a batch', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  const batch = writeBatch(db);
  const ticket = doc(db, 'tickets/ABC123waiting');
  batch.update(ticket, {
    status: 'Diproses',
    updatedAt: serverTimestamp(),
    resolvedAt: null,
  });
  batch.set(doc(ticket, 'updates/update-1'), {
    adminId: 'admin-1',
    adminName: 'Budi Santoso',
    oldStatus: 'Menunggu',
    newStatus: 'Diproses',
    note: 'Sedang ditangani',
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
});

test('employees can create a valid profile from an active company code', async () => {
  const db = environment.authenticatedContext('new-employee').firestore();
  await assertSucceeds(
    setDoc(doc(db, 'users/new-employee'), {
      name: 'Citra Putri',
      email: 'citra@example.com',
      role: 'user',
      companyId: 'company-1',
      companyCode: 'ABC123',
      status: 'active',
      department: 'Akuntansi',
      createdAt: new Date(),
    }),
  );
});
