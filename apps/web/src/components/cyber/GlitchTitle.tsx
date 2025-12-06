import { cn } from "@/lib/utils";

interface GlitchTitleProps {
  text: string;
  className?: string;
  size?: "sm" | "md" | "lg" | "xl";
}

export function GlitchTitle({ text, className, size = "lg" }: GlitchTitleProps) {
  const sizeClasses = {
    sm: "text-2xl",
    md: "text-4xl",
    lg: "text-6xl",
    xl: "text-8xl",
  };

  return (
    <div className={cn("relative font-orbitron font-bold uppercase tracking-wider", sizeClasses[size], className)}>
      <span className="relative inline-block text-white mix-blend-difference z-10">
        {text}
      </span>
      
      {/* Glitch Layer 1 - Red/Pink shift */}
      <span 
        className="absolute top-0 left-0 w-full h-full text-[var(--neon-pink)] opacity-70 z-0 animate-[glitchTop_1s_infinite_linear_alternate-reverse]"
        aria-hidden="true"
      >
        {text}
      </span>

      {/* Glitch Layer 2 - Cyan/Blue shift */}
      <span 
        className="absolute top-0 left-0 w-full h-full text-[var(--neon-cyan)] opacity-70 z-0 animate-[glitchBottom_1s_infinite_linear_alternate-reverse]"
        aria-hidden="true"
      >
        {text}
      </span>
    </div>
  );
}

