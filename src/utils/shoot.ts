import type { ShootSchedule } from '../types/shoot';
import type { Editor } from '../types/task';

// Buổi quay chỉ gồm Lịch quay và On set. Livestream và loại "Khác" là việc trên
// lịch nhưng không phải khối lượng quay, nên đứng ngoài mọi con số buổi quay.
export function isCountedShoot(shoot: Pick<ShootSchedule, 'type'>) {
  return shoot.type === 'lichquay' || shoot.type === 'onset';
}

// Buổi quay gắn editor qua profile id; editorIds là đường cũ nên vẫn phải dò cả hai.
export function countShootsOfEditor(shoots: ShootSchedule[], editor: Editor) {
  const profileKey = editor.profileId || editor.id;
  return shoots.filter((shoot) =>
    isCountedShoot(shoot) &&
    (shoot.editorProfileIds.includes(profileKey) || shoot.editorIds.includes(editor.id))
  ).length;
}
