import Papa from 'papaparse';
import {studentRow, teacherRow} from './domain.js';

// Remove only a balanced text wrapper. Never coerce identifiers to numbers
// or strip arbitrary non-digit characters: malformed data must still fail.
export function csvIdentifier(value) {
  const text = String(value ?? '').trim();
  return text.length >= 2 && text.startsWith('"') && text.endsWith('"')
    ? text.slice(1, -1).trim() : text;
}

function csvBirthDate(value) {
  const text = String(value ?? '').trim();
  if (!text) return null;
  const match = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(text);
  // Slash dates explicitly mean month/day/year, as in the supplied CSV.
  // studentRow subsequently checks that the date really exists.
  return match ? `${match[3]}-${match[1].padStart(2, '0')}-${match[2].padStart(2, '0')}` : text;
}

export function parseImportCsv(text, {students = true, classId = ''} = {}) {
  const parsed = Papa.parse(text, {
    header: true, dynamicTyping: false, skipEmptyLines: 'greedy',
    transformHeader: h => h.replace(/^\ufeff/, '').trim()
  });
  const errors = parsed.errors.map(e => `${Number.isInteger(e.row) ? `Baris ${e.row + 2}: ` : ''}${e.message}`);
  const rows = [], seen = new Set(), qrSeen = new Set();
  const limit = students ? 200 : 100;
  if (!parsed.data.length || parsed.data.length > limit) errors.push(`Isi 1–${limit} baris per file`);
  parsed.data.forEach((r, i) => {
    try {
      const row = students ? studentRow({
        ...r, nisn: csvIdentifier(r.nisn),
        contact: csvIdentifier(r.contact || r.parentPhone || r.parent_phone),
        birthDate: csvBirthDate(r.birthDate || r.birth_date)
      }, classId) : teacherRow({...r, phone: csvIdentifier(r.phone)});
      const key = students ? row.nisn : row.username;
      if (seen.has(key)) throw new Error('NISN/username berulang di file');
      seen.add(key);
      if (row.qr) {
        if (qrSeen.has(row.qr)) throw new Error('QR berulang di file');
        qrSeen.add(row.qr);
      }
      rows.push(row);
    } catch (e) { errors.push(`Baris ${i + 2}: ${e.message}`); }
  });
  return {rows: errors.length ? [] : rows, errors};
}
