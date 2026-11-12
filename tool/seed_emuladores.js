// Fills the local Firebase EMULATORS with fictitious test data for the lab:
// a declarant ready to declare (campus, career, reviewer, open period and the
// coordinator's course assignment) and the reviewer.
//
// It only talks to emulators on this machine and refuses to run otherwise.
// It erases everything in the emulators first. Usage: tool\emuladores.ps1
// (starts the emulators and runs this script).
//
// The data follows DeclaraHorario's Firestore model exactly (models'
// toMap and firestore.rules), so the reused repositories accept it.
const PROJECT = 'declarahorario-b186f';
const PASSWORD = '123456';

const CAMPUS_ID = 'sede-sur-ficticia';
const UNIT_ID = 'informatica-ficticia';
const PERIOD_ID = 'periodo-2026-ii';
const COURSE = 'Programación Móvil (ficticio)';

/** Host of [name], or exits when it is missing or not this machine. */
function emulatorHost(name) {
  const host = process.env[name];
  if (!host) {
    console.error(`${name} no está definida: este script solo corre contra los emuladores.`);
    process.exit(1);
  }
  const hostname = host.replace(/:\d+$/, '').replace(/^\[|\]$/g, '');
  if (!['localhost', '::1'].includes(hostname) && !/^127\.\d+\.\d+\.\d+$/.test(hostname)) {
    console.error(`${name}=${host} no es un emulador local; no se toca nada.`);
    process.exit(1);
  }
  return `http://${host}`;
}

async function call(method, url, body) {
  const response = await fetch(url, {
    method,
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${method} ${url}: ${response.status} ${await response.text()}`);
  }
  const type = response.headers.get('content-type') || '';
  return type.includes('json') ? response.json() : {};
}

/** Firestore REST value of a JS value (Date -> timestamp, int -> integer). */
function value(v) {
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { integerValue: String(v) };
  if (v !== null && typeof v === 'object') return { mapValue: { fields: fields(v) } };
  return { stringValue: v };
}

function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, v]) => [key, value(v)]));
}

/** Local midnight in Costa Rica (UTC-6). */
const crDate = (y, m, d) => new Date(Date.UTC(y, m - 1, d, 6));

async function main() {
  const firestore = emulatorHost('FIRESTORE_EMULATOR_HOST');
  const auth = emulatorHost('FIREBASE_AUTH_EMULATOR_HOST');
  const documents = `${firestore}/v1/projects/${PROJECT}/databases/(default)/documents`;
  const put = (path, data) => call('PATCH', `${documents}/${path}`, { fields: fields(data) });

  // 1. Everything is erased.
  await call('DELETE', `${auth}/emulator/v1/projects/${PROJECT}/accounts`);
  await call('DELETE', `${firestore}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`);

  // 2. Accounts with their email already verified.
  async function account(email) {
    const created = await call(
      'POST',
      `${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator`,
      { email, password: PASSWORD, returnSecureToken: true },
    );
    await call('POST', `${auth}/identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:update`, {
      localId: created.localId,
      emailVerified: true,
    });
    return created.localId;
  }
  const reviewerUid = await account('revisor@ucr.ac.cr');
  const declarantUid = await account('declarante@ucr.ac.cr');

  // 3. Campus, career and the open period (II Ciclo 2026).
  await put(`campuses/${CAMPUS_ID}`, { name: 'Sede del Sur (ficticia)', active: true });
  await put(`units/${UNIT_ID}`, {
    name: 'Informática Empresarial (ficticia)',
    active: true,
    campusId: CAMPUS_ID,
  });
  await put(`periods/${PERIOD_ID}`, {
    name: 'II Ciclo 2026',
    startDate: crDate(2026, 8, 3),
    endDate: crDate(2026, 12, 12),
    enabled: true,
    createdBy: 'seed',
    cycle: 'II',
    year: 2026,
  });

  // 4. Profiles (AppUser.toMap) and the reservation of each identification.
  async function profile(uid, data) {
    await put(`users/${uid}`, { ...data, identificationType: 'CEDULA', active: true });
    await put(`identifications/CEDULA_${data.identification}`, { uid });
  }
  await profile(reviewerUid, {
    fullName: 'Revisor Ficticio',
    identification: '100000003',
    phone: '88880003',
    email: 'revisor@ucr.ac.cr',
    roles: ['superior'],
    campusId: CAMPUS_ID,
  });
  await profile(declarantUid, {
    fullName: 'Ana Prueba Ficticia',
    identification: '100000002',
    phone: '88880002',
    email: 'declarante@ucr.ac.cr',
    roles: ['declarant'],
    campusId: CAMPUS_ID,
    unitId: UNIT_ID,
    superiorUid: reviewerUid,
  });

  // 5. The coordinator's assignment: one course of 4 lesson hours in a
  // 1/4 TC workday (10 h = 4 lessons + 2 attention + 4 planning), with its
  // lessons on Monday and Wednesday 8:00-10:00.
  await put(`workloadAssignments/${PERIOD_ID}_${declarantUid}`, {
    declarantUid,
    periodId: PERIOD_ID,
    lessonMinutes: 240,
    workloadMinutes: 600,
    assignedBy: 'seed',
    campusId: CAMPUS_ID,
    unitId: UNIT_ID,
    courses: [{ name: COURSE, lessonMinutes: 240, workloadMinutes: 600 }],
    slots: [
      { day: 1, startMinutes: 8 * 60, endMinutes: 10 * 60, course: COURSE },
      { day: 3, startMinutes: 8 * 60, endMinutes: 10 * 60, course: COURSE },
    ],
  });

  console.log('');
  console.log('Emuladores listos con datos ficticios. Cuentas (contraseña 123456):');
  console.log('  declarante@ucr.ac.cr  -> Ana Prueba Ficticia, puede crear su declaración');
  console.log('  revisor@ucr.ac.cr     -> Revisor Ficticio (revisor de Ana)');
  console.log(`Período abierto: II Ciclo 2026. Curso asignado: ${COURSE},`);
  console.log('lecciones lunes y miércoles 8:00-10:00 (1/4 TC = 10 h por semana).');
}

main().catch((error) => {
  console.error('No se pudieron cargar los datos de prueba:', error.message);
  process.exit(1);
});
