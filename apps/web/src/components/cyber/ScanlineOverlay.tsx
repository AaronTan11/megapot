export function ScanlineOverlay() {
  return (
    <>
      <div className="fixed inset-0 pointer-events-none z-50 mix-blend-overlay opacity-30 crt-overlay animate-[scanline_8s_linear_infinite]" />
      <div className="fixed inset-0 pointer-events-none z-40 bg-[radial-gradient(circle_at_center,transparent_0%,rgba(0,0,0,0.4)_100%)]" />
    </>
  );
}

