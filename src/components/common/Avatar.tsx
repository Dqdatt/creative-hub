import { useMemo, useState } from 'react';
import type { CSSProperties } from 'react';

interface AvatarProps {
  src?: string | null;
  name?: string | null;
  color?: string | null;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  shape?: 'circle' | 'rounded';
  className?: string;
  alt?: string;
}

function getInitials(name?: string | null) {
  const source = (name || 'Thành viên').trim();
  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'TV';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();

  return `${parts[0][0] ?? ''}${parts[parts.length - 1][0] ?? ''}`.toUpperCase();
}

function isColor(value?: string | null) {
  return Boolean(value && /^#[0-9a-f]{6}$/i.test(value));
}

export function Avatar({
  src,
  name,
  color,
  size = 'md',
  shape = 'circle',
  className = '',
  alt,
}: AvatarProps) {
  const [imageFailed, setImageFailed] = useState(false);
  const initials = useMemo(() => getInitials(name), [name]);
  const shouldShowImage = Boolean(src && !imageFailed);
  const safeColor = isColor(color) ? color : null;

  return (
    <span
      className={`avatar-ui avatar-ui--${size} avatar-ui--${shape} ${className}`.trim()}
      style={safeColor ? { '--avatar-color': safeColor } as CSSProperties : undefined}
    >
      {shouldShowImage ? (
        <img
          src={src ?? undefined}
          alt={alt ?? name ?? ''}
          onError={() => setImageFailed(true)}
        />
      ) : (
        <span aria-hidden="true">{initials}</span>
      )}
    </span>
  );
}
