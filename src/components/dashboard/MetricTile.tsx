import type { ComponentType } from 'react';
import { Info, MoveDownRight, MoveUpRight } from 'lucide-react';

export type DeltaTone = 'up-is-good' | 'down-is-good' | 'neutral';

interface MetricTileProps {
  icon: ComponentType<{ className?: string }>;
  value: string | number;
  label: string;
  hint?: string;
  delta?: number;
  deltaTone?: DeltaTone;
  deltaLabel?: string;
  /** Ô có thể bấm để mở danh sách việc tương ứng. */
  onClick?: () => void;
}

function deltaClass(delta: number, tone: DeltaTone) {
  if (delta === 0 || tone === 'neutral') return 'tile-delta';
  const isGood = tone === 'up-is-good' ? delta > 0 : delta < 0;
  return `tile-delta ${isGood ? 'tile-delta--good' : 'tile-delta--bad'}`;
}

export function MetricTile({
  icon: Icon,
  value,
  label,
  hint,
  delta,
  deltaTone = 'neutral',
  deltaLabel,
  onClick,
}: MetricTileProps) {
  const className = `tile ${onClick ? 'tile--action' : ''}`.trim();

  const body = (
    <>
      <Icon className="tile-ic" />
      <div className="tile-value">
        <b>{value}</b>
        {delta === undefined ? null : (
          <span className={deltaClass(delta, deltaTone)} title={deltaLabel}>
            {delta === 0 ? null : delta > 0 ? <MoveUpRight /> : <MoveDownRight />}
            {delta === 0 ? 'không đổi' : `${delta > 0 ? '+' : '−'}${Math.abs(delta)}`}
          </span>
        )}
      </div>
      <span className="tile-label">
        {label}
        {hint ? <Info aria-hidden="true" /> : null}
      </span>
    </>
  );

  if (onClick) {
    return (
      <button type="button" className={className} onClick={onClick} title={hint}>
        {body}
      </button>
    );
  }

  return <div className={className} title={hint}>{body}</div>;
}
