export type ShootType = 'livestream' | 'lichquay' | 'onset' | 'other';

export interface ShootSchedule {
  id: string;        // UUID or simple string for mock
  date: string;      // YYYY-MM-DD
  type: ShootType;
  crew: string;      // Free text e.g. "KHANG + ĐẠT"
  editorIds: string[];
  editorProfileIds: string[];
  editorLabels: string[];
  displayCrew: string;
  place: string;     // e.g. "LIVESTREAM SHOPEE"
  time: string;      // e.g. "BUỔI TỐI" or "ALL MORNING"
  note: string;
}

export interface ShootFormData {
  date: string;
  type: ShootType;
  crew: string;
  editorIds: string[];
  place: string;
  time: string;
  note: string;
}
