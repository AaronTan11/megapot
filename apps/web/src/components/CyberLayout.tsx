import * as React from "react";
import { ScanlineOverlay } from "./cyber/ScanlineOverlay";

export function CyberLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-[var(--cyber-black)] text-white relative font-mono selection:bg-[var(--neon-pink)] selection:text-white">
      {/* Background Effects */}
      <div className="fixed inset-0 cyber-grid opacity-30 pointer-events-none" />
      <div className="fixed inset-0 bg-[radial-gradient(circle_at_center,rgba(255,0,255,0.03),transparent_70%)] pointer-events-none" />
      
      {/* Scanline Overlay */}
      <ScanlineOverlay />
      
      {/* Main Content */}
      <div className="relative z-10">
        {children}
      </div>
    </div>
  );
}

