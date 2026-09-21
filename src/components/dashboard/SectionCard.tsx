import type { ReactNode } from 'react';

interface SectionCardProps {
  title: string;
  subtitle?: string;
  action?: ReactNode;
  /** Bảng dùng flush để đường kẻ chạy sát mép thẻ. */
  flush?: boolean;
  children: ReactNode;
}

// Khối nội dung chuẩn: tiêu đề, một dòng mô tả, hành động nằm bên phải.
export function SectionCard({ title, subtitle, action, flush, children }: SectionCardProps) {
  return (
    <section className={`dsection ${flush ? 'dsection--flush' : ''}`.trim()}>
      <div className="dsection-head">
        <div className="dsection-head-copy">
          <h2>{title}</h2>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
        {action ? <div className="dsection-head-end">{action}</div> : null}
      </div>
      {children}
    </section>
  );
}
