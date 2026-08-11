import { Link } from 'react-router-dom';
import { Moon, Sun, Smartphone, ArrowLeft, RefreshCw, AlertTriangle, CheckCircle, Database } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';

interface Props { state: IOSStateReturn }

export function IOSTestToolbar({ state }: Props) {
  const { prototypeMode, setPrototypeMode, isDarkMode, toggleDarkMode, viewScale, setViewScale, selectedMonth, setSelectedMonth } = state;

  return (
    <div className="ios-test-panel" style={{ maxWidth: 480, marginBottom: 16 }}>
      {/* Top row: back link + identity + controls */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 10, borderBottom: '1px solid rgba(0,0,0,0.06)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Link
            to="/dashboard"
            style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 12, fontWeight: 600, color: '#555', textDecoration: 'none', padding: '5px 9px', background: '#F4F4F8', borderRadius: 9, border: '1px solid rgba(0,0,0,0.07)', transition: 'background 0.15s' }}
          >
            <ArrowLeft width={13} height={13} />
            WebApp
          </Link>
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11, fontWeight: 700, color: '#7C5CFF', padding: '5px 9px', background: 'rgba(124,92,255,0.08)', borderRadius: 9 }}>
            <Smartphone width={12} height={12} />
            iOS Prototype (393×852)
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <button
            onClick={toggleDarkMode}
            style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11.5, fontWeight: 600, color: '#555', padding: '5px 9px', background: '#F4F4F8', borderRadius: 9, border: '1px solid rgba(0,0,0,0.07)', cursor: 'pointer' }}
          >
            {isDarkMode ? <Sun width={13} height={13} color="#F59E0B" /> : <Moon width={13} height={13} color="#6366F1" />}
            {isDarkMode ? 'Dark' : 'Light'}
          </button>
          <button
            onClick={() => setViewScale(viewScale === 'normal' ? 'fit' : 'normal')}
            style={{ fontSize: 11.5, fontWeight: 600, color: '#555', padding: '5px 9px', background: '#F4F4F8', borderRadius: 9, border: '1px solid rgba(0,0,0,0.07)', cursor: 'pointer' }}
          >
            {viewScale === 'normal' ? '90%' : '100%'}
          </button>
        </div>
      </div>

      {/* State test row */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, fontWeight: 700, color: '#9AA0B2', textTransform: 'uppercase', letterSpacing: 0.4 }}>
          <RefreshCw width={11} height={11} /> State:
        </span>
        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
          {[
            { id: 'default', label: 'Default', icon: <CheckCircle width={11} height={11} /> },
            { id: 'loading', label: 'Loading', icon: null },
            { id: 'empty', label: 'Empty', icon: null },
            { id: 'error', label: 'Error', icon: <AlertTriangle width={11} height={11} /> },
          ].map((m) => (
            <button
              key={m.id}
              onClick={() => setPrototypeMode(m.id as any)}
              className={`ios-test-chip ${prototypeMode === m.id ? 'active' : ''}`}
              style={m.id === 'error' && prototypeMode === m.id ? { background: '#EF4444', color: '#fff', borderColor: '#EF4444' } : {}}
            >
              {m.icon && <span style={{ marginRight: 3, display: 'inline-flex', verticalAlign: 'middle' }}>{m.icon}</span>}
              {m.label}
            </button>
          ))}
        </div>

        <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, fontWeight: 700, color: '#9AA0B2', textTransform: 'uppercase', letterSpacing: 0.4 }}>
            <Database width={11} height={11} /> Tháng:
          </span>
          <select
            value={selectedMonth}
            onChange={(e) => setSelectedMonth(e.target.value)}
            style={{ fontSize: 11.5, fontWeight: 600, padding: '4px 8px', background: '#F4F4F8', border: '1px solid rgba(0,0,0,0.09)', borderRadius: 8, color: '#333', cursor: 'pointer' }}
          >
            <option value="2026-06">T6/2026</option>
            <option value="2026-07">T7/2026</option>
            <option value="2026-08">T8/2026</option>
          </select>
        </div>
      </div>
    </div>
  );
}
