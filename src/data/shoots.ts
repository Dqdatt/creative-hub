import type { ShootSchedule } from '../types/shoot';

export const SHOOT_TYPES_META: Record<ShootSchedule['type'], { label: string; dot: string }> = {
  livestream: { label: 'Livestream', dot: '#F59E0B' },
  lichquay:   { label: 'Lịch quay', dot: '#A855F7' },
  onset:      { label: 'On set', dot: '#2563EB' },
  other:      { label: 'Khác', dot: '#6B7280' },
};

const legacyShoot = (shoot: Omit<ShootSchedule, 'editorIds' | 'editorProfileIds' | 'editorLabels' | 'displayCrew'>): ShootSchedule => ({
  ...shoot,
  editorIds: [],
  editorProfileIds: [],
  editorLabels: [],
  displayCrew: shoot.crew,
});

const MOCK_SHOOTS_BASE: Array<Omit<ShootSchedule, 'editorIds' | 'editorProfileIds' | 'editorLabels' | 'displayCrew'>> = [
  { id: 's1', date: '2026-07-07', type: 'livestream', crew: 'KHANG + ĐẠT',        place: 'LIVESTREAM SHOPEE',   time: 'BUỔI TỐI',    note: '' },
  { id: 's2', date: '2026-07-08', type: 'lichquay',   crew: 'HẰNG - ĐẠT - BUMI',  place: 'SHOWROOM HÒA BÌNH',   time: 'ALL MORNING', note: 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE' },
  { id: 's3', date: '2026-07-09', type: 'lichquay',   crew: 'LINH - MINH - BUMI', place: 'SHOWROOM AN SƯƠNG',   time: 'ALL MORNING', note: 'THEO DẤU GIẤC NGỦ TẬP 2 - SHOWROOM TRƯỜNG CHINH' },
  { id: 's4', date: '2026-07-10', type: 'livestream', crew: 'MINH + HẢI',         place: 'LIVESTREAM SHOPEE',   time: 'BUỔI TỐI',    note: '' },
  { id: 's5', date: '2026-07-10', type: 'onset',      crew: 'ĐẠT - BUMI',         place: 'ONSET TIDO',          time: '',            note: '' },
  { id: 's6', date: '2026-07-13', type: 'other',      crew: '',                   place: 'QUAY CHỤP BELLO',     time: '',            note: '' },
  { id: 's7', date: '2026-07-14', type: 'lichquay',   crew: 'MY - ĐẠT - BUMI',    place: 'SHOWROOM HÒA BÌNH',   time: 'ALL MORNING', note: 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE' },
  { id: 's8', date: '2026-07-15', type: 'livestream', crew: 'KHANG + MINH',       place: 'LIVESTREAM SHOPEE',   time: 'BUỔI TỐI',    note: '' },
  { id: 's9', date: '2026-07-16', type: 'lichquay',   crew: 'MY - ĐẠT - BUMI',    place: 'SHOWROOM AN SƯƠNG',   time: 'ALL MORNING', note: 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE' },
  { id: 's10', date: '2026-07-17', type: 'onset',      crew: 'ĐẠT - BUMI',         place: 'ON SET TIDO',         time: '',            note: '' },
  { id: 's11', date: '2026-07-20', type: 'livestream', crew: 'HẢI + ĐẠT',          place: 'LIVESTREAM SHOPEE',   time: 'BUỔI TỐI',    note: '' },
  { id: 's12', date: '2026-07-21', type: 'lichquay',   crew: 'HẰNG - ĐẠT - BUMI',  place: 'SHOWROOM AN SƯƠNG',   time: 'ALL MORNING', note: 'CONTENT THÁNG 8' },
  { id: 's13', date: '2026-07-22', type: 'lichquay',   crew: 'NHƯ - MINH - BUMI',  place: 'SHOWROOM AN SƯƠNG',   time: 'ALL MORNING', note: 'CONTENT THÁNG 8' },
  { id: 's14', date: '2026-07-24', type: 'onset',      crew: 'ĐẠT - BUMI',         place: 'ON SET TIDO',         time: '',            note: '' },
  { id: 's15', date: '2026-07-25', type: 'lichquay',   crew: 'BUMI - ĐẠT - ÂN',    place: 'SCOUT SHOWROOM CẦN THƠ', time: '',         note: '' },
  { id: 's16', date: '2026-07-28', type: 'lichquay',   crew: 'MY - ĐẠT - BUMI',    place: 'SHOWROOM HÒA BÌNH',   time: 'ALL MORNING', note: 'CONTENT THÁNG 8 HOẶC CHỤP/QUAY DRAP MỚI PHÔNG TRẮNG' },
  { id: 's17', date: '2026-07-29', type: 'lichquay',   crew: 'LONG - ĐẠT - BUMI',  place: 'SHOWROOM AN SƯƠNG',   time: 'ALL MORNING', note: 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE' },
  { id: 's18', date: '2026-07-30', type: 'lichquay',   crew: 'LINH - ĐẠT - BUMI',  place: 'SHOWROOM HÒA BÌNH',   time: 'ALL MORNING', note: 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE' },
  { id: 's19', date: '2026-07-31', type: 'onset',      crew: 'ĐẠT - BUMI',         place: 'ON SET TIDO',         time: '',            note: '' },
  { id: 's20', date: '2026-08-01', type: 'lichquay',   crew: 'BUMI - ĐẠT',         place: 'KHAI TRƯƠNG CẦN THƠ', time: '',            note: '' },
  { id: 's21', date: '2026-08-05', type: 'onset',      crew: 'ĐẠT - BUMI',         place: 'ON SET TIDO',         time: '',            note: '' },
];

export const MOCK_SHOOTS: ShootSchedule[] = MOCK_SHOOTS_BASE.map(legacyShoot);
