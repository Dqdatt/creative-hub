import { useState } from "react";
import { Outlet } from "react-router-dom";
import Sidebar from "./Sidebar";
import Header from "./Header";
import { useAuth } from "../../context/authContext";
import { useNotifications } from "../../hooks/useNotifications";
import { useIsMobile, useMobileDocumentFlag } from "../../hooks/useIsMobile";
import { MobileShell } from "../mobile/MobileShell";
import type { AppOutletContext } from "../mobile/outletContext";

export default function AppLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { profile } = useAuth();
  const notifications = useNotifications(profile?.id);
  const isMobile = useIsMobile();
  useMobileDocumentFlag(isMobile);

  if (isMobile) {
    return (
      <MobileShell notifications={notifications} />
    );
  }

  const outletContext: AppOutletContext = {
    notifications,
    openInstall: () => {},
  };

  return (
    <div className="app-shell app-bg">
      <Sidebar mobileOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="app-main">
        <Header
          onOpenSidebar={() => setSidebarOpen(true)}
          notifications={notifications}
        />
        <main id="view" className="app-content">
          <Outlet context={outletContext} />
        </main>
        <footer
          className="app-footer"
          style={{ borderTop: "1px solid var(--border)" }}
        >
          CreativeHub | Developed by Doan Quoc Dat | v2.1.0
        </footer>
      </div>
      <div
        id="sbBackdrop"
        className={`fixed inset-0 z-30 xl:hidden ${sidebarOpen ? "block" : "hidden"}`}
        style={{ background: "rgba(10,10,18,.5)", backdropFilter: "blur(4px)" }}
        onClick={() => setSidebarOpen(false)}
      />
    </div>
  );
}
