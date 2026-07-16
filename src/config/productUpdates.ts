import type { AppRoute } from './permissions';

export const PRODUCT_UPDATE = {
  key: 'content-plan-video-task-workflow',
  steps: [
    {
      id: 'content-plan-assignment',
      route: '/content-plan',
      targets: [
        '[data-tour="content-plan-editor"]',
        '[data-tour="content-plan-table"]',
      ],
      title: 'Giao việc ngay từ Content Plan',
      body: 'Admin hoặc Creative Manager chọn Editor tại đây.\n\nCreativeHub sẽ tự tạo Task tương ứng trong Video tháng.',
      primaryLabel: 'Tiếp',
    },
    {
      id: 'video-task-accept',
      route: '/tasks',
      targets: [
        '[data-tour="video-task-accept"]',
        '[data-tour="video-task-waiting-row"]',
        '[data-tour="video-task-status-column"]',
        '[data-tour="video-task-table"]',
      ],
      title: 'Editor cần Nhận Task',
      body: 'Task mới sẽ ở trạng thái Chờ.\n\nEditor chọn Ngày nhận, Ngày trả rồi nhấn “Nhận Task”.',
      primaryLabel: 'Tiếp',
    },
    {
      id: 'video-task-complete',
      route: '/tasks',
      targets: [
        '[data-tour="video-task-result-link"]',
        '[data-tour="video-task-complete"]',
        '[data-tour="video-task-link-column"]',
        '[data-tour="video-task-table"]',
      ],
      title: 'Hoàn thành và đồng bộ Link',
      body: 'Khi làm xong, Editor thêm Link thành phẩm và nhấn “Hoàn thành”.\n\nLink sẽ tự đồng bộ về Content Plan và dòng hoàn thành sẽ chuyển sang màu xanh.',
      primaryLabel: 'Bắt đầu sử dụng',
    },
  ] satisfies readonly ProductUpdateStep[],
} as const;

export interface ProductUpdateStep {
  id: string;
  route: AppRoute;
  targets: readonly string[];
  title: string;
  body: string;
  primaryLabel: string;
}
