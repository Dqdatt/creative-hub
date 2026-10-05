import { Camera, ChevronRight, Clapperboard, ClipboardList, UserPlus } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { BottomSheet } from './BottomSheet';
import type { CreateKind } from './mobileChrome';

const OPTIONS: Record<CreateKind, { icon: LucideIcon; title: string; hint: string; tone: string }> = {
  task: { icon: Clapperboard, title: 'Video task', hint: 'Task thủ công trong Video tháng', tone: 'blue' },
  shoot: { icon: Camera, title: 'Lịch quay', hint: 'Lịch quay, livestream, on set', tone: 'violet' },
  content: { icon: ClipboardList, title: 'Dòng Content Plan', hint: 'Lịch air, có thể phân công editor', tone: 'green' },
  user: { icon: UserPlus, title: 'Thành viên', hint: 'Tạo tài khoản cho team', tone: 'blue' },
};

interface QuickAddSheetProps {
  kinds: CreateKind[] | null;
  onPick: (kind: CreateKind) => void;
  onClose: () => void;
}

export function QuickAddSheet({ kinds, onPick, onClose }: QuickAddSheetProps) {
  return (
    <BottomSheet open={Boolean(kinds?.length)} title="Thêm nhanh" onClose={onClose}>
      <div className="m-option-list">
        {(kinds ?? []).map((kind) => {
          const option = OPTIONS[kind];
          const Icon = option.icon;
          return (
            <button key={kind} type="button" className="m-option" onClick={() => onPick(kind)}>
              <span className={`m-option-icon m-tone-${option.tone}`}><Icon aria-hidden="true" /></span>
              <span className="m-option-copy">
                <b>{option.title}</b>
                <span>{option.hint}</span>
              </span>
              <ChevronRight className="m-option-chevron" aria-hidden="true" />
            </button>
          );
        })}
      </div>
    </BottomSheet>
  );
}
