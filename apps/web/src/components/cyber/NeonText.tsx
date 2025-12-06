import { cn } from "@/lib/utils";
import React from "react";

type NeonColor = "pink" | "cyan" | "yellow" | "white";

interface NeonTextProps extends React.HTMLAttributes<HTMLSpanElement> {
  children: React.ReactNode;
  color?: NeonColor;
  glow?: boolean;
  className?: string;
  as?: "span" | "p" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6";
}

export function NeonText({ 
  children, 
  color = "pink", 
  glow = true, 
  className,
  as: Component = "span",
  ...props 
}: NeonTextProps) {
  
  const colorMap = {
    pink: "text-[var(--neon-pink)]",
    cyan: "text-[var(--neon-cyan)]",
    yellow: "text-[var(--neon-yellow)]",
    white: "text-white"
  };

  const glowMap = {
    pink: "drop-shadow-[0_0_5px_var(--neon-pink)]",
    cyan: "drop-shadow-[0_0_5px_var(--neon-cyan)]",
    yellow: "drop-shadow-[0_0_5px_var(--neon-yellow)]",
    white: "drop-shadow-[0_0_5px_rgba(255,255,255,0.8)]"
  };

  return (
    <Component 
      className={cn(
        "font-orbitron transition-all duration-300",
        colorMap[color],
        glow && glowMap[color],
        className
      )}
      {...props}
    >
      {children}
    </Component>
  );
}

