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
    await setDoc(
      doc(db, 'tickets/completed'),
      waitingTicket({
        ticketNumber: 'HD-COMPLE',
        status: 'Selesai',
      }),
    );
    await setDoc(doc(db, 'tickets/ABC123waiting/updates/delete-history'), {
      adminId: 'admin-1',
      adminName: 'Budi Santoso',
      oldStatus: 'Menunggu',
      newStatus: 'Diproses',
      note: 'Sedang ditangani',
      createdAt: new Date(),
    });
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

test('employees can delete their own waiting ticket only', async () => {
  const employeeDb = environment.authenticatedContext('employee-1').firestore();
  await assertSucceeds(deleteDoc(doc(employeeDb, 'tickets/ABC123waiting')));
  await assertFails(deleteDoc(doc(employeeDb, 'tickets/processing')));
  await assertFails(deleteDoc(doc(employeeDb, 'tickets/other-employee-ticket')));
});

test('employees can atomically delete their own ticket and update history', async () => {
  const db = environment.authenticatedContext('employee-1').firestore();
  const batch = writeBatch(db);
  const ticket = doc(db, 'tickets/ABC123waiting');
  batch.delete(doc(ticket, 'updates/delete-history'));
  batch.delete(ticket);
  await assertSucceeds(batch.commit());
});

test('admins can delete waiting and cancelled tickets in their company', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertSucceeds(deleteDoc(doc(db, 'tickets/ABC123waiting')));
  await assertSucceeds(deleteDoc(doc(db, 'tickets/cancelled')));
});

test('admins cannot delete processing or completed tickets', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertFails(deleteDoc(doc(db, 'tickets/processing')));
  await assertFails(deleteDoc(doc(db, 'tickets/completed')));
});

test('admins cannot delete tickets from another company', async () => {
  const db = environment.authenticatedContext('admin-2').firestore();
  await assertFails(deleteDoc(doc(db, 'tickets/ABC123waiting')));
});

test('guests cannot delete tickets', async () => {
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(deleteDoc(doc(db, 'tickets/ABC123waiting')));
});

test('admin can atomically delete ticket history and create notification', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  const batch = writeBatch(db);
  const ticket = doc(db, 'tickets/ABC123waiting');
  batch.delete(doc(ticket, 'updates/delete-history'));
  batch.delete(ticket);
  batch.set(doc(db, 'notifications/deletion-1'), {
    userId: 'employee-1',
    companyId: 'company-1',
    type: 'ticket_deleted',
    ticketNumber: 'HD-ABC123',
    ticketTitle: 'Printer tidak mencetak',
    reason: 'Tiket duplikat.',
    adminName: 'Budi Santoso',
    createdAt: serverTimestamp(),
    read: false,
  });
  await assertSucceeds(batch.commit());
});

test('employees cannot create notifications', async () => {
  const db = environment.authenticatedContext('employee-1').firestore();
  await assertFails(
    setDoc(doc(db, 'notifications/fake'), {
      userId: 'employee-1',
      companyId: 'company-1',
      type: 'ticket_deleted',
      ticketNumber: 'HD-ABC123',
      ticketTitle: 'Printer tidak mencetak',
      reason: 'Alasan.',
      adminName: 'Ayu Lestari',
      createdAt: serverTimestamp(),
      read: false,
    }),
  );
});

test('employees can only read and mark their own notifications as read', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'notifications/employee-1-notification'), {
      userId: 'employee-1', companyId: 'company-1', read: false,
    });
    await setDoc(doc(db, 'notifications/employee-2-notification'), {
      userId: 'employee-2', companyId: 'company-1', read: false,
    });
  });
  const db = environment.authenticatedContext('employee-1').firestore();
  await assertSucceeds(getDoc(doc(db, 'notifications/employee-1-notification')));
  await assertFails(getDoc(doc(db, 'notifications/employee-2-notification')));
  await assertSucceeds(
    updateDoc(doc(db, 'notifications/employee-1-notification'), { read: true }),
  );
  await assertFails(
    updateDoc(doc(db, 'notifications/employee-2-notification'), { read: true }),
  );
});

test('admin notifications require a reason from 1 to 300 characters', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  const notification = (reason) => ({
    userId: 'employee-1',
    companyId: 'company-1',
    type: 'ticket_deleted',
    ticketNumber: 'HD-ABC123',
    ticketTitle: 'Printer tidak mencetak',
    reason,
    adminName: 'Budi Santoso',
    createdAt: serverTimestamp(),
    read: false,
  });
  await assertFails(setDoc(doc(db, 'notifications/empty-reason'), notification('')));
  await assertFails(
    setDoc(doc(db, 'notifications/long-reason'), notification('x'.repeat(301))),
  );
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
