import { useState } from "react";
import { Outlet } from "react-router-dom";
import Sidebar from "./Sidebar";
import Header from "./Header";
import { WhatsNewTour } from "../common/WhatsNewTour";
import { useAuth } from "../../context/authContext";
import { useNotifications } from "../../hooks/useNotifications";
import { useWhatsNewOnboarding } from "../../hooks/useWhatsNewOnboarding";

export default function AppLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { profile, role, permissions } = useAuth();
  const notifications = useNotifications(profile?.id);
  const whatsNew = useWhatsNewOnboarding(profile?.id);

  return (
    <div className="app-shell app-bg">
      <Sidebar mobileOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="app-main">
        <Header
          onOpenSidebar={() => setSidebarOpen(true)}
          onOpenWhatsNew={whatsNew.openManually}
          notifications={notifications}
        />
        <main id="view" className="app-content">
          <Outlet />
        </main>
        <footer
          className="app-footer"
          style={{ borderTop: "1px solid var(--border)" }}
        >
          CreativeHub | Developed by Doan Quoc Dat | v1.0.6
        </footer>
      </div>
      <div
        id="sbBackdrop"
        className={`fixed inset-0 z-30 xl:hidden ${sidebarOpen ? "block" : "hidden"}`}
        style={{ background: "rgba(10,10,18,.5)", backdropFilter: "blur(4px)" }}
        onClick={() => setSidebarOpen(false)}
      />
      <WhatsNewTour
        open={whatsNew.isOpen}
        role={role}
        permissions={permissions}
        onClose={whatsNew.close}
      />
    </div>
  );
}
