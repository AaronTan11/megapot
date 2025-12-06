import * as React from "react";
import { cn } from "@/lib/utils";

interface CyberCardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  neonColor?: "pink" | "cyan" | "yellow";
  className?: string;
}

export function CyberCard({ 
  children, 
  neonColor = "cyan", 
  className,
  ...props 
}: CyberCardProps) {
  
  const borderColors = {
    pink: "from-[var(--neon-pink)] to-transparent",
    cyan: "from-[var(--neon-cyan)] to-transparent",
    yellow: "from-[var(--neon-yellow)] to-transparent",
  };

  return (
    <div 
      className={cn(
        "relative p-[1px] rounded-xl overflow-hidden group",
        className
      )}
      {...props}
    >
      {/* Animated Gradient Border */}
      <div className={cn(
        "absolute inset-0 bg-gradient-to-br opacity-50 group-hover:opacity-100 transition-opacity duration-500",
        borderColors[neonColor]
      )} />
      
      {/* Inner Content Card */}
      <div className="relative h-full bg-[var(--cyber-card-bg)] backdrop-blur-md rounded-xl p-6 border border-white/5">
        {children}
      </div>
    </div>
  );
}

