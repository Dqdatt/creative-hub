import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';

export default function AppLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="app-shell app-bg">
      <Sidebar mobileOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="app-main">
        <Header onOpenSidebar={() => setSidebarOpen(true)} />
        <main id="view" className="app-content">
          <Outlet />
        </main>
        <footer className="app-footer" style={{ borderTop: '1px solid var(--border)' }}>
          CreativeHub | Developed by Doan Quoc Dat | v1.0.0
        </footer>
      </div>
      <div
        id="sbBackdrop"
        className={`fixed inset-0 z-30 xl:hidden ${sidebarOpen ? 'block' : 'hidden'}`}
        style={{ background: 'rgba(10,10,18,.5)', backdropFilter: 'blur(4px)' }}
        onClick={() => setSidebarOpen(false)}
      />
    </div>
  );
}
