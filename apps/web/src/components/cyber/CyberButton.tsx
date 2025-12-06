import * as React from "react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type ButtonBaseProps = React.ComponentProps<typeof Button>;

interface CyberButtonProps extends ButtonBaseProps {
  neonColor?: "pink" | "cyan" | "yellow";
  cyberShape?: boolean;
}

const CyberButton = React.forwardRef<HTMLButtonElement, CyberButtonProps>(
  ({ className, variant = "default", neonColor = "pink", cyberShape = false, ...props }, ref) => {
    const neonStyles = {
      pink: "hover:shadow-[0_0_15px_var(--neon-pink)] hover:border-[var(--neon-pink)] border-transparent",
      cyan: "hover:shadow-[0_0_15px_var(--neon-cyan)] hover:border-[var(--neon-cyan)] border-transparent",
      yellow: "hover:shadow-[0_0_15px_var(--neon-yellow)] hover:border-[var(--neon-yellow)] border-transparent",
    };

    const shapeClass = cyberShape
      ? "clip-path-polygon-[10px_0,100%_0,100%_calc(100%-10px),calc(100%-10px)_100%,0_100%,0_10px]"
      : "";

    return (
      <Button
        ref={ref}
        className={cn(
          "font-orbitron tracking-wider transition-all duration-300 border",
          neonStyles[neonColor],
          shapeClass,
          // Custom override for primary variant to be black with colored border/text on hover or inverse
          variant === "default" && "bg-black/50 text-white border-white/20 hover:bg-black/80",
          variant === "outline" && "bg-transparent border-white/20 hover:bg-white/5",
          className,
        )}
        variant={variant}
        {...props}
      />
    );
  },
);
CyberButton.displayName = "CyberButton";

export { CyberButton };

