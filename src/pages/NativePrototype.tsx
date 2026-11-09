import { useEffect, useMemo, useState } from 'react';
import {
  ArrowLeft,
  Bell,
  CalendarDays,
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  Clapperboard,
  ClipboardList,
  Clock3,
  Download,
  Home,
  KeyRound,
  Link2,
  LogOut,
  Moon,
  Palette,
  Plus,
  Search,
  SlidersHorizontal,
  Sun,
  UserRound,
  UsersRound,
  X,
} from 'lucide-react';
import logo from '../assets/logo.png';
import { useAuth } from '../context/authContext';
import { useMonth } from '../context/monthContext';
import { useContentPlan } from '../hooks/useContentPlan';
import { useDashboard } from '../hooks/useDashboard';
import { useNotifications } from '../hooks/useNotifications';
import type { ShootSchedule } from '../types/shoot';
import { formatVietnameseMonth } from '../utils/month';
import './NativePrototype.css';

type PrototypeView = 'overview' | 'tasks' | 'calendar' | 'content';
type CreateKind = 'task' | 'shoot' | 'content';
type UtilityView = 'search' | 'notifications' | 'account';
type DetailKind = 'task' | 'shoot' | 'content';

type DetailItem = {
  kind: DetailKind;
  title: string;
  status: string;
  owner: string;
  due: string;
  meta: string;
  link?: string;
  note?: string;
};

type PrototypeTask = {
  id: string;
  title: string;
  owner: string;
  meta: string;
  due: string;
  urgent: boolean;
  status: string;
  link?: string;
  note?: string;
};

type PrototypeContent = {
  id: string;
  date: string;
  month: string;
  title: string;
  category: string;
  owner: string;
  status: string;
  link?: string;
  note?: string;
};

type PrototypeNotification = {
  id: string;
  title: string;
  body: string;
  time: string;
  unread: boolean;
  icon: typeof Clapperboard;
};

const NAV_ITEMS = [
  { id: 'overview' as const, label: 'Tổng quan', icon: Home },
  { id: 'tasks' as const, label: 'Video', icon: Clapperboard },
  { id: 'calendar' as const, label: 'Lịch', icon: CalendarDays },
  { id: 'content' as const, label: 'Content', icon: ClipboardList },
];

const WEEKDAY_LABELS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

const FALLBACK_TASKS: PrototypeTask[] = [
  { id: 'task-1', title: 'BST Sofa Modular', owner: 'Đạt', meta: 'Hòa Bình', due: 'Hôm nay', urgent: true, status: 'Đang làm' },
  { id: 'task-2', title: 'Reels hậu trường showroom', owner: 'Huyền', meta: 'Digital', due: '28/10', urgent: false, status: 'Đang làm' },
  { id: 'task-3', title: 'Video hướng dẫn lắp đặt', owner: 'My', meta: 'Retail', due: '30/10', urgent: false, status: 'Đang làm' },
  { id: 'task-4', title: 'TVC chiến dịch cuối năm', owner: 'Minh', meta: 'Brand', due: '02/11', urgent: false, status: 'Chờ' },
];

const FALLBACK_CONTENT: PrototypeContent[] = [
  { id: 'content-1', date: '28', month: 'TH10', title: 'Sofa đẹp bắt đầu từ trải nghiệm', category: 'Video dài', owner: 'Đạt', status: 'Đã phân công' },
  { id: 'content-2', date: '30', month: 'TH10', title: 'Ba cách phối phòng khách nhỏ', category: 'Short/Reels', owner: 'Huyền', status: 'Đang làm' },
  { id: 'content-3', date: '02', month: 'TH11', title: 'Behind the scenes showroom', category: 'Short/Reels', owner: 'My', status: 'Chưa phân công' },
];

const FALLBACK_NOTIFICATIONS: PrototypeNotification[] = [
  { id: 'notice-1', title: 'Video chờ bạn duyệt', body: 'BST Sofa Modular đã có link thành phẩm.', time: '8 phút', unread: true, icon: Clapperboard },
  { id: 'notice-2', title: 'Lịch quay được cập nhật', body: 'Giờ quay showroom đổi sang 09:00 ngày 28/10.', time: '1 giờ', unread: true, icon: Camera },
  { id: 'notice-3', title: 'Bạn được gắn vào Content', body: 'Huyền đã phân công “Ba cách phối phòng khách nhỏ”.', time: 'Hôm qua', unread: true, icon: ClipboardList },
  { id: 'notice-4', title: 'Task đã hoàn thành', body: 'Video Nệm Cloud đã được Minh xác nhận.', time: '25/10', unread: false, icon: Check },
];

const CREATE_COPY: Record<CreateKind, { title: string; subtitle: string; icon: typeof Clapperboard }> = {
  task: { title: 'Task mới', subtitle: 'Video tháng', icon: Clapperboard },
  shoot: { title: 'Lịch quay mới', subtitle: 'Lịch sản xuất', icon: Camera },
  content: { title: 'Content mới', subtitle: 'Content Plan', icon: ClipboardList },
};

const FALLBACK_SHOOTS: ShootSchedule[] = [
  {
    id: 'shoot-1',
    date: '2026-10-28',
    type: 'lichquay',
    crew: 'ĐẠT - HUYỀN - BUMI',
    editorIds: [],
    editorProfileIds: [],
    editorLabels: ['Đạt', 'Huyền'],
    displayCrew: 'Đạt, Huyền và Bumi',
    place: 'Showroom Hòa Bình',
    content: 'BST Sofa Modular',
    time: '09:00',
    note: '',
  },
  {
    id: 'shoot-2',
    date: '2026-10-30',
    type: 'onset',
    crew: 'MY - MINH',
    editorIds: [],
    editorProfileIds: [],
    editorLabels: ['My', 'Minh'],
    displayCrew: 'My và Minh',
    place: 'Studio Tido',
    content: 'Duyệt Content Plan',
    time: '15:30',
    note: '',
  },
];

function compactDate(value: string) {
  if (!value) return 'Chưa đặt';
  const iso = value.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return `${iso[3]}/${iso[2]}`;
  return value;
}

function relativeTime(value: string) {
  const createdAt = new Date(value);
  if (!Number.isFinite(createdAt.getTime())) return compactDate(value);
  const minutes = Math.max(0, Math.round((Date.now() - createdAt.getTime()) / 60000));
  if (minutes < 60) return `${Math.max(1, minutes)} phút`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)} giờ`;
  if (minutes < 2880) return 'Hôm qua';
  return createdAt.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' });
}

function notificationIcon(type: string) {
  if (type.startsWith('shoot_')) return Camera;
  if (type.startsWith('content_plan_')) return ClipboardList;
  return Clapperboard;
}

function usePrototypeData() {
  const { user, profile, roleLabel } = useAuth();
  const { selectedMonth, goToPreviousMonth, goToNextMonth } = useMonth();
  const dashboard = useDashboard(selectedMonth);
  const contentPlan = useContentPlan(selectedMonth);
  const notificationState = useNotifications(profile?.id, 12);
  const isLive = Boolean(user);
  const refetchDashboard = dashboard.refetch;
  const refetchContentPlan = contentPlan.refetch;

  useEffect(() => {
    if (!user?.id) return;
    void refetchDashboard();
    void refetchContentPlan();
  }, [refetchContentPlan, refetchDashboard, user?.id]);

  const tasks = useMemo<PrototypeTask[]>(() => {
    if (!isLive) return FALLBACK_TASKS;
    return dashboard.tasks.map((task) => {
      const editor = dashboard.editors.find((candidate) => candidate.id === task.editorId);
      return {
        id: task.dbId ?? `task-${task.id}`,
        title: task.name,
        owner: editor?.short || editor?.name || 'Chưa gán',
        meta: [task.orderTeam, task.category].filter(Boolean).join(' · ') || task.category,
        due: compactDate(task.returnDate || task.airDate),
        urgent: task.priority === 'Gấp',
        status: task.status,
        link: task.link,
        note: task.note,
      };
    });
  }, [dashboard.editors, dashboard.tasks, isLive]);

  const content = useMemo<PrototypeContent[]>(() => {
    if (!isLive) return FALLBACK_CONTENT;
    return contentPlan.items.map((item) => {
      const editor = contentPlan.editorOptions.find((candidate) => candidate.id === item.editor_id);
      const [, month = '', day = ''] = item.air_date.split('-');
      return {
        id: item.id,
        date: day || '--',
        month: month ? `TH${month}` : 'CHƯA',
        title: item.video_name,
        category: item.category,
        owner: editor?.short || editor?.name || 'Chưa gán',
        status: item.editor_id ? item.link ? 'Đã có link' : item.linkedTaskStatus || 'Đã phân công' : 'Chưa phân công',
        link: item.link,
        note: item.note,
      };
    });
  }, [contentPlan.editorOptions, contentPlan.items, isLive]);

  const notices = useMemo<PrototypeNotification[]>(() => {
    if (!isLive) return FALLBACK_NOTIFICATIONS;
    return notificationState.notifications.map((notice) => ({
      id: notice.id,
      title: notice.title,
      body: notice.body,
      time: relativeTime(notice.createdAt),
      unread: !notice.readAt,
      icon: notificationIcon(notice.type),
    }));
  }, [isLive, notificationState.notifications]);

  const shoots = isLive ? dashboard.shoots : FALLBACK_SHOOTS;
  const editors = isLive
    ? dashboard.editors.map((editor) => ({ id: editor.id, name: editor.short || editor.name }))
    : [{ id: 'dat', name: 'Đạt' }, { id: 'huyen', name: 'Huyền' }, { id: 'my', name: 'My' }, { id: 'minh', name: 'Minh' }];

  return {
    isLive,
    selectedMonth,
    monthLabel: formatVietnameseMonth(selectedMonth),
    previousMonth: goToPreviousMonth,
    nextMonth: goToNextMonth,
    tasks,
    content,
    shoots,
    editors,
    notices,
    unreadCount: isLive ? notificationState.unreadCount : FALLBACK_NOTIFICATIONS.filter((notice) => notice.unread).length,
    profileName: profile?.displayName || profile?.fullName || 'Đạt Nguyễn',
    profileMeta: `${roleLabel} · ${profile?.department || 'Team Marketing'}`,
    isLoading: isLive && (dashboard.isLoading || contentPlan.isLoading || notificationState.isLoading),
    loadError: isLive ? dashboard.loadError || contentPlan.loadError || notificationState.loadError : null,
    markAllRead: notificationState.markAllRead,
    markOneRead: notificationState.markOneRead,
  };
}

function InitialAvatar({ name, tone = 'blue' }: { name: string; tone?: 'blue' | 'green' | 'amber' | 'rose' }) {
  return <span className={`np-avatar np-avatar--${tone}`}>{name.slice(0, 1).toUpperCase()}</span>;
}

function toTaskDetail(task: PrototypeTask): DetailItem {
  return { kind: 'task', title: task.title, status: task.status, owner: task.owner, due: task.due, meta: task.meta, link: task.link, note: task.note };
}

function toContentDetail(item: PrototypeContent): DetailItem {
  return { kind: 'content', title: item.title, status: item.status, owner: item.owner, due: `${item.date}/${item.month.replace('TH', '')}`, meta: item.category, link: item.link, note: item.note };
}

function OverviewScreen({ tasks, shoots, onTask, onAllTasks, onShoot }: { tasks: PrototypeTask[]; shoots: ShootSchedule[]; onTask: (item: DetailItem) => void; onAllTasks: () => void; onShoot: (shoot: ShootSchedule) => void }) {
  const activeTasks = tasks.filter((task) => task.status !== 'Đã xong');
  const missingLinks = tasks.filter((task) => task.status === 'Đã xong' && !task.link).length;
  const nextShoot = shoots[0];
  return (
    <div className="np-screen-stack">
      <section className="np-focus-card">
        <div className="np-focus-copy">
          <span>Ưu tiên hôm nay</span>
          <strong>{activeTasks.length} task cần xử lý</strong>
          <p>{missingLinks ? `${missingLinks} video đã xong nhưng chưa có link.` : 'Không có video hoàn thành thiếu link.'}</p>
        </div>
        <div className="np-focus-count" aria-label={`${activeTasks.length} task`}>{String(activeTasks.length).padStart(2, '0')}</div>
      </section>

      <section className="np-metrics" aria-label="Tổng quan công việc">
        <div><strong>{tasks.filter((task) => task.status === 'Đang làm').length}</strong><span>Đang làm</span></div>
        <div><strong>{shoots.length}</strong><span>Lịch tháng này</span></div>
        <div><strong>{tasks.filter((task) => task.status === 'Chờ').length}</strong><span>Đang chờ</span></div>
      </section>

      <section className="np-section">
        <div className="np-section-head">
          <h2>Cần xử lý</h2>
          <button type="button" onClick={onAllTasks}>Xem tất cả</button>
        </div>
        <div className="np-list-card">
          {activeTasks.slice(0, 3).map((task, index) => (
            <button type="button" className="np-task-row" key={task.title} onClick={() => onTask(toTaskDetail(task))}>
              <InitialAvatar name={task.owner} tone={index === 1 ? 'green' : index === 2 ? 'amber' : 'blue'} />
              <span className="np-row-copy">
                <strong>{task.title}</strong>
                <small>{task.owner} · {task.meta}</small>
              </span>
              <span className={`np-due ${task.urgent ? 'is-urgent' : ''}`}>{task.due}</span>
              <ChevronRight aria-hidden="true" />
            </button>
          ))}
          {!activeTasks.length ? <div className="np-inline-empty">Không có task cần xử lý.</div> : null}
        </div>
      </section>

      <section className="np-section">
        <div className="np-section-head"><h2>Lịch tiếp theo</h2><span>{nextShoot ? compactDate(nextShoot.date) : 'Chưa có'}</span></div>
        {nextShoot ? (
          <button type="button" className="np-event-card" onClick={() => onShoot(nextShoot)}>
            <span className="np-event-time"><strong>{nextShoot.time || 'Cả ngày'}</strong><small>{compactDate(nextShoot.date)}</small></span>
            <span className="np-event-rule" />
            <span className="np-row-copy">
              <strong>{nextShoot.content || nextShoot.place}</strong>
              <small>{[nextShoot.place, nextShoot.displayCrew || nextShoot.crew].filter(Boolean).join(' · ')}</small>
            </span>
            <ChevronRight aria-hidden="true" />
          </button>
        ) : <div className="np-inline-empty">Chưa có lịch quay trong tháng này.</div>}
      </section>
    </div>
  );
}

function TasksScreen({ tasks, monthLabel, onTask }: { tasks: PrototypeTask[]; monthLabel: string; onTask: (item: DetailItem) => void }) {
  const [filter, setFilter] = useState<'all' | 'working' | 'waiting'>('all');
  const [showFilters, setShowFilters] = useState(false);
  const visibleTasks = tasks.filter((task) => filter === 'all' || (filter === 'waiting' ? task.status === 'Chờ' : task.status === 'Đang làm'));

  return (
    <div className="np-screen-stack">
      <div className="np-filter-line">
        <div className="np-segment" role="tablist" aria-label="Trạng thái task">
          <button className={filter === 'all' ? 'is-active' : ''} type="button" onClick={() => setFilter('all')}>Tất cả</button>
          <button className={filter === 'working' ? 'is-active' : ''} type="button" onClick={() => setFilter('working')}>Đang làm</button>
          <button className={filter === 'waiting' ? 'is-active' : ''} type="button" onClick={() => setFilter('waiting')}>Chờ</button>
        </div>
        <button type="button" className={`np-filter-button ${showFilters ? 'is-active' : ''}`} onClick={() => setShowFilters((current) => !current)} aria-label="Bộ lọc"><SlidersHorizontal /></button>
      </div>
      {showFilters ? (
        <div className="np-filter-chips" aria-label="Bộ lọc nhanh">
          <button className="is-active" type="button">Mọi editor</button>
          <button type="button">Video dài</button>
          <button type="button">Motion</button>
          <button type="button">Có order</button>
        </div>
      ) : null}
      <section className="np-section">
        <div className="np-section-head"><h2>{monthLabel}</h2><span>{visibleTasks.length} / {tasks.length} task</span></div>
        <div className="np-task-stack">
          {visibleTasks.map((task, index) => (
            <button type="button" className="np-task-card" key={task.title} onClick={() => onTask(toTaskDetail(task))}>
              <div className="np-task-card-top">
                <span className={`np-status ${task.urgent ? 'is-urgent' : ''}`}>{task.urgent ? 'Gấp' : task.status}</span>
                <span className="np-task-number">{String(tasks.indexOf(task) + 1).padStart(2, '0')}</span>
              </div>
              <h3>{task.title}</h3>
              <div className="np-task-card-foot">
                <InitialAvatar name={task.owner} tone={index % 2 ? 'green' : 'blue'} />
                <span>{task.owner}</span>
                <span className="np-task-meta">{task.meta}</span>
                <span className="np-due">{task.due}</span>
              </div>
            </button>
          ))}
          {!visibleTasks.length ? <div className="np-inline-empty">Không có task phù hợp bộ lọc.</div> : null}
        </div>
      </section>
    </div>
  );
}

function CalendarScreen({ shoots, tasks, editors, monthLabel, onShoot, previousMonth, nextMonth }: { shoots: ShootSchedule[]; tasks: PrototypeTask[]; editors: Array<{ id: string; name: string }>; monthLabel: string; onShoot: (shoot: ShootSchedule) => void; previousMonth: () => void; nextMonth: () => void }) {
  const [mode, setMode] = useState<'shoot' | 'workload'>('shoot');
  const days = useMemo(() => {
    const focus = shoots[0]?.date ? new Date(`${shoots[0].date}T00:00:00`) : new Date();
    const mondayOffset = focus.getDay() === 0 ? -6 : 1 - focus.getDay();
    return Array.from({ length: 7 }, (_, index) => {
      const date = new Date(focus);
      date.setDate(focus.getDate() + mondayOffset + index);
      return [WEEKDAY_LABELS[date.getDay()], String(date.getDate()).padStart(2, '0'), date.toISOString().slice(0, 10)] as const;
    });
  }, [shoots]);
  const workload = editors.map((editor) => ({
    ...editor,
    tasks: tasks.filter((task) => task.owner === editor.name).length,
    shoots: shoots.filter((shoot) => shoot.editorLabels.includes(editor.name) || shoot.displayCrew.toLowerCase().includes(editor.name.toLowerCase())).length,
  })).sort((a, b) => (b.tasks + b.shoots) - (a.tasks + a.shoots));

  return (
    <div className="np-screen-stack">
      <div className="np-calendar-toolbar">
        <button type="button" aria-label="Tháng trước" onClick={previousMonth}><ChevronLeft /></button>
        <strong>{monthLabel}</strong>
        <button type="button" aria-label="Tháng sau" onClick={nextMonth}><ChevronRight /></button>
      </div>
      <div className="np-segment np-segment--two" role="tablist" aria-label="Chế độ lịch">
        <button className={mode === 'shoot' ? 'is-active' : ''} type="button" onClick={() => setMode('shoot')}>Lịch quay</button>
        <button className={mode === 'workload' ? 'is-active' : ''} type="button" onClick={() => setMode('workload')}>Workload</button>
      </div>
      {mode === 'shoot' ? (
        <>
          <div className="np-week-strip" aria-label="Tuần hiện tại">
            {days.map(([weekday, day, iso], index) => (
              <button type="button" className={index === Math.min(1, days.length - 1) ? 'is-active' : ''} key={iso}>
                <span>{weekday}</span><strong>{day}</strong>
              </button>
            ))}
          </div>
          <section className="np-section">
            <div className="np-section-head"><h2>Lịch trong tháng</h2><span>{shoots.length} lịch</span></div>
            <div className="np-timeline">
              {shoots.slice(0, 4).map((shoot) => (
                <button type="button" className="np-timeline-item" onClick={() => onShoot(shoot)} key={shoot.id}>
                  <time>{shoot.time || compactDate(shoot.date)}</time>
                  <span className="np-timeline-line" />
                  <span>
                    <span className="np-type"><Camera /> {compactDate(shoot.date)}</span>
                    <strong>{shoot.content || shoot.place}</strong>
                    <small>{shoot.place}</small>
                    {shoot.editorLabels.length ? (
                      <span className="np-people">
                        {shoot.editorLabels.slice(0, 2).map((name, index) => <InitialAvatar key={name} name={name} tone={index ? 'green' : 'blue'} />)}
                        {shoot.editorLabels.length > 2 ? <em>+{shoot.editorLabels.length - 2}</em> : null}
                      </span>
                    ) : null}
                  </span>
                </button>
              ))}
              {!shoots.length ? <div className="np-inline-empty">Chưa có lịch quay trong tháng này.</div> : null}
            </div>
          </section>
        </>
      ) : (
        <section className="np-section">
          <div className="np-section-head"><h2>Khối lượng tháng</h2><span>{monthLabel}</span></div>
          <div className="np-workload-card">
            {workload.map((editor, index) => (
              <button type="button" key={editor.id}>
                <InitialAvatar name={editor.name} tone={(['blue', 'green', 'amber', 'rose'] as const)[index % 4]} />
                <span><strong>{editor.name}</strong><small>{editor.shoots} lịch quay</small></span>
                <em>{editor.tasks} task</em><ChevronRight />
              </button>
            ))}
            {!workload.length ? <div className="np-inline-empty">Chưa có editor trong dữ liệu tháng này.</div> : null}
          </div>
          <div className="np-capacity-note"><CircleAlert /><span><strong>Tổng khối lượng</strong><small>{tasks.length} task và {shoots.length} lịch quay trong tháng.</small></span></div>
        </section>
      )}
    </div>
  );
}

function ContentScreen({ items, onContent }: { items: PrototypeContent[]; onContent: (item: DetailItem) => void }) {
  const [contentMode, setContentMode] = useState<'upcoming' | 'unassigned'>('upcoming');
  const visibleItems = contentMode === 'upcoming' ? items : items.filter((item) => item.status === 'Chưa phân công');
  return (
    <div className="np-screen-stack">
      <div className="np-segment np-segment--two" role="tablist" aria-label="Trạng thái content">
        <button className={contentMode === 'upcoming' ? 'is-active' : ''} type="button" onClick={() => setContentMode('upcoming')}>Sắp tới</button>
        <button className={contentMode === 'unassigned' ? 'is-active' : ''} type="button" onClick={() => setContentMode('unassigned')}>Chưa phân công</button>
      </div>
      <label className="np-search-field">
        <Search aria-hidden="true" />
        <input aria-label="Tìm content" placeholder="Tìm content" />
      </label>
      <section className="np-section">
        <div className="np-section-head"><h2>Content Plan</h2><span>{visibleItems.length} nội dung</span></div>
        <div className="np-content-list">
          {visibleItems.map((item, index) => (
            <button type="button" className="np-content-row" key={item.id} onClick={() => onContent(toContentDetail(item))}>
              <span className="np-date-block"><strong>{item.date}</strong><small>{item.month}</small></span>
              <span className="np-row-copy">
                <strong>{item.title}</strong>
                <small>{item.category} · {item.status}</small>
              </span>
              <InitialAvatar name={item.owner} tone={index === 1 ? 'green' : index === 2 ? 'amber' : 'blue'} />
              <ChevronRight aria-hidden="true" />
            </button>
          ))}
          {!visibleItems.length ? <div className="np-inline-empty">Không có Content phù hợp bộ lọc.</div> : null}
        </div>
      </section>
      {contentMode === 'upcoming' ? (
        <section className="np-empty-card">
          <Check aria-hidden="true" />
          <div><strong>Đã lên lịch đầy đủ</strong><p>Không có nội dung trễ hạn trong tuần này.</p></div>
        </section>
      ) : null}
    </div>
  );
}

function QuickCreate({ onClose, onPick }: { onClose: () => void; onPick: (kind: CreateKind) => void }) {
  const actions = [
    { id: 'task' as const, label: 'Thêm Task', hint: 'Giao việc cho editor', icon: Clapperboard },
    { id: 'shoot' as const, label: 'Thêm lịch quay', hint: 'Lên lịch sản xuất', icon: Camera },
    { id: 'content' as const, label: 'Thêm Content', hint: 'Tạo nội dung mới', icon: ClipboardList },
  ];
  return (
    <div className="np-sheet-layer" role="presentation" onClick={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section className="np-sheet np-glass" role="dialog" aria-modal="true" aria-labelledby="quickCreateTitle">
        <div className="np-sheet-grabber" />
        <header><h2 id="quickCreateTitle">Tạo mới</h2><button type="button" onClick={onClose} aria-label="Đóng"><X /></button></header>
        <div className="np-sheet-actions">
          {actions.map((action) => {
            const Icon = action.icon;
            return (
              <button type="button" key={action.id} onClick={() => onPick(action.id)}>
                <span><Icon /></span>
                <span><strong>{action.label}</strong><small>{action.hint}</small></span>
                <ChevronRight />
              </button>
            );
          })}
        </div>
      </section>
    </div>
  );
}

function CreateScreen({ kind, onBack, onSave }: { kind: CreateKind; onBack: () => void; onSave: () => void }) {
  const copy = CREATE_COPY[kind];
  return (
    <section className="np-native-screen" aria-labelledby="createScreenTitle">
      <header className="np-native-nav">
        <button type="button" className="np-round-control np-glass" onClick={onBack} aria-label="Quay lại"><ArrowLeft /></button>
        <div><h2 id="createScreenTitle">{copy.title}</h2><p>{copy.subtitle}</p></div>
        <button type="button" className="np-save-control np-glass" onClick={onSave}>Lưu</button>
      </header>
      <main className="np-native-content">
        <section className="np-form-group">
          <label><span>{kind === 'shoot' ? 'Nội dung quay' : kind === 'content' ? 'Tên Content' : 'Tên video'}</span><input autoFocus={false} placeholder="Nhập nội dung" /></label>
          <label><span>{kind === 'shoot' ? 'Ngày quay' : 'Ngày thực hiện'}</span><input type="date" /></label>
        </section>
        <section className="np-form-group">
          <button type="button"><span><UsersRound /> Người phụ trách</span><small>Chưa phân công</small><ChevronRight /></button>
          <button type="button"><span><Clock3 /> Thời gian</span><small>{kind === 'shoot' ? '09:00' : 'Chưa chọn'}</small><ChevronRight /></button>
          <button type="button"><span><Link2 /> Link tài liệu</span><small>Không bắt buộc</small><ChevronRight /></button>
        </section>
        <section className="np-form-group">
          <label><span>Ghi chú</span><textarea placeholder="Thêm thông tin cần thiết" /></label>
        </section>
        <p className="np-form-note"><CircleAlert /> Bạn có thể bổ sung thông tin chi tiết sau khi tạo.</p>
      </main>
    </section>
  );
}

function DetailScreen({ item, onBack, onAction }: { item: DetailItem; onBack: () => void; onAction: () => void }) {
  const label = item.kind === 'task' ? 'Chi tiết video' : item.kind === 'shoot' ? 'Chi tiết lịch quay' : 'Chi tiết Content';
  return (
    <section className="np-native-screen" aria-labelledby="detailTitle">
      <header className="np-native-nav">
        <button type="button" className="np-round-control np-glass" onClick={onBack} aria-label="Quay lại"><ArrowLeft /></button>
        <div><h2 id="detailTitle">{label}</h2><p>CreativeHub</p></div>
        <button type="button" className="np-save-control np-glass" onClick={onAction}>Sửa</button>
      </header>
      <main className="np-native-content">
        <section className="np-detail-hero">
          <span className="np-status">{item.status}</span>
          <h1>{item.title}</h1>
          <p>{item.meta}</p>
        </section>
        <section className="np-form-group np-detail-group">
          <div><span>Người phụ trách</span><strong><InitialAvatar name={item.owner} /> {item.owner}</strong></div>
          <div><span>Thời hạn</span><strong>{item.due}</strong></div>
          <div><span>Trạng thái</span><strong>{item.status}</strong></div>
        </section>
        <button type="button" className="np-link-card" onClick={onAction}>
          <span><Link2 /></span><span><strong>Link tài liệu</strong><small>{item.link || 'Chưa có liên kết'}</small></span><ChevronRight />
        </button>
        <section className="np-detail-note"><strong>Ghi chú</strong><p>{item.note || 'Chưa có ghi chú cho nội dung này.'}</p></section>
        <button type="button" className="np-primary-action" onClick={onAction}>Cập nhật tiến độ</button>
      </main>
    </section>
  );
}

function UtilityScreen({ view, dark, tasks, notices, unreadCount, profileName, profileMeta, shootCount, onBack, onTheme, onToast, onMarkAll, onNotice }: { view: UtilityView; dark: boolean; tasks: PrototypeTask[]; notices: PrototypeNotification[]; unreadCount: number; profileName: string; profileMeta: string; shootCount: number; onBack: () => void; onTheme: () => void; onToast: (message: string) => void; onMarkAll: () => void; onNotice: (id: string) => void }) {
  const title = view === 'search' ? 'Tìm kiếm' : view === 'notifications' ? 'Thông báo' : 'Tài khoản';
  return (
    <section className="np-native-screen" aria-labelledby="utilityTitle">
      <header className="np-native-nav np-native-nav--simple">
        <button type="button" className="np-round-control np-glass" onClick={onBack} aria-label="Quay lại"><ArrowLeft /></button>
        <h2 id="utilityTitle">{title}</h2>
        {view === 'notifications' ? <button type="button" className="np-text-control" onClick={onMarkAll}>Đã đọc</button> : <span />}
      </header>
      <main className="np-native-content">
        {view === 'search' ? (
          <>
            <label className="np-search-field np-search-field--large">
              <Search aria-hidden="true" />
              <input autoFocus aria-label="Tìm trong CreativeHub" placeholder="Task, content, thành viên..." />
            </label>
            <section className="np-section">
              <div className="np-section-head"><h2>Tìm gần đây</h2><button type="button">Xóa</button></div>
              <div className="np-search-results">
                {tasks.slice(0, 2).map((task) => <button type="button" key={task.id}><Search /><span><strong>{task.title}</strong><small>Video tháng · {task.owner}</small></span><ChevronRight /></button>)}
                <button type="button"><Search /><span><strong>Lịch quay tháng này</strong><small>{shootCount} kết quả</small></span><ChevronRight /></button>
              </div>
            </section>
            <section className="np-filter-chips np-filter-chips--wrap"><button type="button">Video</button><button type="button">Content</button><button type="button">Lịch quay</button><button type="button">Thành viên</button></section>
          </>
        ) : null}

        {view === 'notifications' ? (
          <div className="np-notification-list">
            <div className="np-section-head"><h2>Mới</h2><span>{unreadCount} chưa đọc</span></div>
            {notices.map((notice) => {
              const Icon = notice.icon;
              return (
                <button type="button" key={notice.id} className={notice.unread ? 'is-unread' : ''} onClick={() => onNotice(notice.id)}>
                  <span className="np-notice-icon"><Icon /></span>
                  <span><strong>{notice.title}</strong><small>{notice.body}</small><time>{notice.time}</time></span>
                  {notice.unread ? <i aria-label="Chưa đọc" /> : null}
                </button>
              );
            })}
            {!notices.length ? <div className="np-inline-empty">Bạn chưa có thông báo nào.</div> : null}
          </div>
        ) : null}

        {view === 'account' ? (
          <>
            <section className="np-profile-card">
              <div className="np-profile-avatar"><img src={logo} alt="" /></div>
              <div><h1>{profileName}</h1><p>{profileMeta}</p></div>
            </section>
            <section className="np-account-stats"><div><strong>{tasks.length}</strong><span>Video tháng</span></div><div><strong>{shootCount}</strong><span>Lịch tháng</span></div></section>
            <section className="np-form-group np-account-menu">
              <button type="button" onClick={() => onToast('Hồ sơ cá nhân')}><span><UserRound /> Hồ sơ cá nhân</span><ChevronRight /></button>
              <button type="button" onClick={() => onToast('Danh sách thành viên')}><span><UsersRound /> Thành viên</span><ChevronRight /></button>
              <button type="button" onClick={() => onToast('Đã chuẩn bị cài đặt PWA')}><span><Download /> Cài CreativeHub</span><ChevronRight /></button>
              <button type="button" onClick={onTheme}><span>{dark ? <Sun /> : <Moon />} Giao diện</span><small>{dark ? 'Tối' : 'Sáng'}</small><ChevronRight /></button>
            </section>
            <section className="np-form-group np-account-menu">
              <button type="button" onClick={() => onToast('Bảo mật tài khoản')}><span><KeyRound /> Bảo mật</span><ChevronRight /></button>
              <button type="button" onClick={() => onToast('Tùy chỉnh giao diện')}><span><Palette /> Tùy chỉnh</span><ChevronRight /></button>
              <button type="button" className="is-danger" onClick={() => onToast('Prototype không đăng xuất')}><span><LogOut /> Đăng xuất</span></button>
            </section>
          </>
        ) : null}
      </main>
    </section>
  );
}

export default function NativePrototype() {
  const data = usePrototypeData();
  const [view, setView] = useState<PrototypeView>('overview');
  const [quickOpen, setQuickOpen] = useState(false);
  const [createKind, setCreateKind] = useState<CreateKind | null>(null);
  const [utilityView, setUtilityView] = useState<UtilityView | null>(null);
  const [detailItem, setDetailItem] = useState<DetailItem | null>(null);
  const [toast, setToast] = useState('');
  const [dark, setDark] = useState(() => window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false);

  useEffect(() => {
    if (!toast) return undefined;
    const timer = window.setTimeout(() => setToast(''), 2200);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const openShoot = (shoot: ShootSchedule) => setDetailItem({
    kind: 'shoot',
    title: shoot.content || shoot.place,
    status: 'Đã lên lịch',
    owner: shoot.editorLabels[0] || shoot.displayCrew || shoot.crew || 'Chưa gán',
    due: [shoot.time, compactDate(shoot.date)].filter(Boolean).join(' · '),
    meta: [shoot.place, shoot.displayCrew || shoot.crew].filter(Boolean).join(' · '),
    note: shoot.note,
  });
  const content = view === 'overview'
    ? <OverviewScreen tasks={data.tasks} shoots={data.shoots} onTask={setDetailItem} onAllTasks={() => setView('tasks')} onShoot={openShoot} />
    : view === 'tasks'
      ? <TasksScreen tasks={data.tasks} monthLabel={data.monthLabel} onTask={setDetailItem} />
      : view === 'calendar'
        ? <CalendarScreen shoots={data.shoots} tasks={data.tasks} editors={data.editors} monthLabel={data.monthLabel} onShoot={openShoot} previousMonth={data.previousMonth} nextMonth={data.nextMonth} />
        : <ContentScreen items={data.content} onContent={setDetailItem} />;

  return (
    <div className="np-stage" data-theme={dark ? 'dark' : 'light'}>
      <div className="np-device">
        <div className="np-color-field" aria-hidden="true" />
        <header className="np-topbar">
          <button type="button" className="np-profile-control np-glass" onClick={() => setUtilityView('account')} aria-label="Tài khoản"><img src={logo} alt="" /></button>
          <div className="np-toolbar">
            <button type="button" className="np-round-control np-glass" onClick={() => setDark((current) => !current)} aria-label={dark ? 'Dùng giao diện sáng' : 'Dùng giao diện tối'}>
              {dark ? <Sun /> : <Moon />}
            </button>
            <button type="button" className="np-round-control np-glass" onClick={() => setUtilityView('search')} aria-label="Tìm kiếm"><Search /></button>
            <span className="np-notification-control">
              <button type="button" className="np-round-control np-glass" onClick={() => setUtilityView('notifications')} aria-label="Thông báo"><Bell /></button>
              {data.unreadCount ? <span className="np-notification-badge">{Math.min(data.unreadCount, 99)}</span> : null}
            </span>
          </div>
        </header>

        <main className="np-scroll" key={view}>
          {data.isLoading ? <div className="np-sync-state"><span /><span /><span /></div> : null}
          {data.loadError ? <div className="np-data-error"><CircleAlert /><span>{data.loadError}</span></div> : null}
          {content}
        </main>

        <div className="np-bottom-layer">
          <nav className="np-tabbar np-glass" aria-label="Điều hướng prototype">
            {NAV_ITEMS.map((item) => {
              const Icon = item.icon;
              return (
                <button type="button" key={item.id} className={view === item.id ? 'is-active' : ''} onClick={() => setView(item.id)}>
                  <Icon /><span>{item.label}</span>
                </button>
              );
            })}
          </nav>
          <button type="button" className="np-add-button np-glass" onClick={() => setQuickOpen(true)} aria-label="Tạo mới"><Plus /></button>
        </div>

        {quickOpen ? <QuickCreate onClose={() => setQuickOpen(false)} onPick={(kind) => { setQuickOpen(false); setCreateKind(kind); }} /> : null}
        {createKind ? <CreateScreen kind={createKind} onBack={() => setCreateKind(null)} onSave={() => { setCreateKind(null); setToast('Đã lưu bản nháp'); }} /> : null}
        {detailItem ? <DetailScreen item={detailItem} onBack={() => setDetailItem(null)} onAction={() => setToast('Đây là bản prototype')} /> : null}
        {utilityView ? (
          <UtilityScreen
            view={utilityView}
            dark={dark}
            tasks={data.tasks}
            notices={data.notices}
            unreadCount={data.unreadCount}
            profileName={data.profileName}
            profileMeta={data.profileMeta}
            shootCount={data.shoots.length}
            onBack={() => setUtilityView(null)}
            onTheme={() => setDark((current) => !current)}
            onToast={setToast}
            onMarkAll={() => {
              if (data.isLive) void data.markAllRead();
              setToast('Đã đánh dấu đã đọc');
            }}
            onNotice={(id) => {
              if (data.isLive) void data.markOneRead(id);
              setToast('Đã mở thông báo');
            }}
          />
        ) : null}
        {toast ? <div className="np-toast np-glass" role="status"><Check />{toast}</div> : null}
      </div>
    </div>
  );
}
