import { createFileRoute } from "@tanstack/react-router";
import { GlitchTitle } from "@/components/cyber/GlitchTitle";
import { CyberCard } from "@/components/cyber/CyberCard";
import { NeonText } from "@/components/cyber/NeonText";
import { CyberButton } from "@/components/cyber/CyberButton";
import { Input } from "@/components/ui/input";
import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/")({
	component: HomeComponent,
});

function HomeComponent() {
	const [selectedNumber, setSelectedNumber] = useState("");
	const [submitting, setSubmitting] = useState(false);
	const [roundCountdown, setRoundCountdown] = useState(299); // 4:59
	const [roundStatus, setRoundStatus] = useState<"idle" | "pending" | "fulfilled">("fulfilled");
	const [lastTicket, setLastTicket] = useState<string | null>(null);
	const [flashTicket, setFlashTicket] = useState(false);
	
	// Mock Data
	const currentPot = "1,250,000";
	const recentWinners = [
		{ address: "0x12...34", number: "7777", prize: "50,000" },
		{ address: "0xAB...CD", number: "1234", prize: "25,000" },
		{ address: "0x56...78", number: "9999", prize: "10,000" },
		{ address: "0x99...88", number: "4200", prize: "5,000" },
		{ address: "0xDE...FA", number: "1337", prize: "2,500" },
	];

	// simple local countdown loop for recording
	useEffect(() => {
		const timer = setInterval(() => {
			setRoundCountdown((prev) => {
				if (prev <= 0) return 299;
				return prev - 1;
			});
		}, 1000);
		return () => clearInterval(timer);
	}, []);

	// flip status to look alive when countdown hits certain marks
	useEffect(() => {
		if (roundCountdown === 10) setRoundStatus("pending");
		if (roundCountdown === 7) setRoundStatus("fulfilled");
	}, [roundCountdown]);

	const countdownLabel = `${String(Math.floor(roundCountdown / 60)).padStart(2, "0")}:${String(
		roundCountdown % 60,
	).padStart(2, "0")}`;

	function handleBuy() {
		if (selectedNumber.length !== 4 || submitting) return;
		setSubmitting(true);
		setTimeout(() => {
			setSubmitting(false);
			setLastTicket(selectedNumber);
			setFlashTicket(true);
			setTimeout(() => setFlashTicket(false), 900);
		}, 900);
	}

	return (
		<div className="container mx-auto px-4 py-8 space-y-12">
			
			{/* Section 1: Hero & Pot Display */}
			<section className="text-center space-y-8 animate-[fadeIn_1s_ease-out]">
				<div className="flex justify-center mb-8">
					<GlitchTitle text="MEGA POT" size="xl" className="tracking-[0.2em]" />
				</div>

				<div className="flex justify-center">
					<div className="inline-flex items-center gap-3 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-mono text-gray-200">
						<span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
						<span>Draw in {countdownLabel}</span>
						<span className="text-gray-500">·</span>
						<span>Round #4024</span>
					</div>
				</div>
				
				<div className="relative inline-block group">
					<div className="absolute inset-0 bg-[var(--neon-pink)] blur-[50px] opacity-20 group-hover:opacity-40 transition-opacity duration-500" />
					<h2 className="text-7xl md:text-9xl font-mono font-bold text-transparent bg-clip-text bg-gradient-to-b from-white to-gray-400 drop-shadow-[0_0_15px_rgba(255,0,255,0.5)] relative z-10">
						${currentPot}
					</h2>
					<NeonText color="cyan" className="text-xl mt-4 block tracking-widest uppercase opacity-80">
						Current Prize Pool
					</NeonText>
				</div>
			</section>

			<div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
				
				{/* Section 2: Game Interface */}
				<div className="lg:col-span-7 space-y-8">
					<CyberCard neonColor="pink" className="h-full">
						<div className="space-y-6">
							<div className="flex items-center justify-between border-b border-white/10 pb-4">
								<NeonText as="h3" color="pink" className="text-2xl font-bold">
									ENTER THE GRID
								</NeonText>
							<div className="flex items-center gap-2 text-xs font-mono text-gray-400">
								<span
									className={cn(
										"w-2 h-2 rounded-full animate-pulse",
										roundStatus === "fulfilled"
											? "bg-green-400"
											: roundStatus === "pending"
												? "bg-yellow-400"
												: "bg-red-500",
									)}
								/>
								<span>Entries open</span>
							</div>
							</div>

							<div className="space-y-4">
								<label className="text-sm font-mono text-gray-400 uppercase tracking-wider">
									Select Your Number (0000-9999)
								</label>
								<div className="flex gap-4">
									<Input 
										type="text" 
										placeholder="0000" 
										maxLength={4}
										value={selectedNumber}
										onChange={(e) => setSelectedNumber(e.target.value.replace(/[^0-9]/g, ''))}
										className="h-16 text-4xl font-mono text-center tracking-[0.5em] bg-black/50 border-[var(--neon-pink)] focus:ring-[var(--neon-pink)] focus:border-[var(--neon-pink)] text-[var(--neon-pink)] placeholder:text-gray-800"
									/>
									<CyberButton 
										variant="outline" 
										className="h-16 aspect-square"
										onClick={() => setSelectedNumber(Math.floor(Math.random() * 10000).toString().padStart(4, '0'))}
									>
										🎲
									</CyberButton>
								</div>
							</div>

							<div className="pt-4 space-y-4">
								<div className="flex justify-between items-center text-sm font-mono">
									<span className="text-gray-400">Ticket Price</span>
									<span className="text-white">1 USDm</span>
								</div>
								
								<CyberButton 
									neonColor="pink" 
									cyberShape 
									className="w-full h-14 text-xl mt-4"
									disabled={selectedNumber.length !== 4}
									onClick={handleBuy}
								>
									{submitting && (
										<span className="mr-2 inline-flex items-center">
											<span className="w-4 h-4 rounded-full border-2 border-[var(--neon-pink)] border-t-transparent animate-spin" />
										</span>
									)}
									BUY TICKET
								</CyberButton>
								{lastTicket && (
									<div
										className={cn(
											"mt-3 inline-flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-mono text-[var(--neon-pink)] transition-all",
											flashTicket ? "ring-1 ring-[var(--neon-pink)] shadow-[0_0_15px_var(--neon-pink)]" : "opacity-90",
										)}
									>
										<span className="w-2 h-2 rounded-full bg-[var(--neon-pink)] animate-ping" />
										<span>Ticket #{lastTicket} locked in</span>
									</div>
								)}
							</div>
						</div>
					</CyberCard>
				</div>

				{/* Section 3: Recent Winners */}
				<div className="lg:col-span-5 space-y-8">
					<CyberCard neonColor="cyan" className="h-full min-h-[400px]">
						<div className="space-y-6">
							<div className="flex items-center justify-between border-b border-white/10 pb-4">
								<NeonText as="h3" color="cyan" className="text-2xl font-bold">
									RECENT WINNERS
								</NeonText>
								<span className="text-xs font-mono text-[var(--neon-cyan)]">LIVE FEED</span>
							</div>

							<div className="space-y-0 overflow-hidden relative">
								{/* Gradient Overlay for Fade Effect */}
								<div className="absolute top-0 left-0 right-0 h-4 bg-gradient-to-b from-[var(--cyber-card-bg)] to-transparent z-10 pointer-events-none" />
								<div className="absolute bottom-0 left-0 right-0 h-4 bg-gradient-to-t from-[var(--cyber-card-bg)] to-transparent z-10 pointer-events-none" />
								
								<div className="space-y-2 max-h-[350px] overflow-y-auto pr-2 custom-scrollbar">
									{recentWinners.map((winner, i) => (
										<div 
											key={i} 
											className="flex items-center justify-between p-3 rounded bg-white/5 border border-white/5 hover:border-[var(--neon-cyan)] transition-colors group"
										>
											<div className="flex items-center gap-3">
												<div className="w-8 h-8 rounded-full bg-gradient-to-br from-[var(--neon-cyan)] to-blue-600 flex items-center justify-center text-xs font-bold text-black">
													#{winner.number}
												</div>
												<div className="flex flex-col">
													<span className="text-sm font-mono text-gray-300 group-hover:text-white transition-colors">
														{winner.address}
													</span>
													<span className="text-xs text-gray-500">2 mins ago</span>
												</div>
											</div>
											<NeonText color="yellow" className="font-mono">
												+${winner.prize}
											</NeonText>
										</div>
									))}
								</div>
							</div>
						</div>
					</CyberCard>
				</div>
			</div>

			{/* Footer Stats */}
			<div className="grid grid-cols-2 md:grid-cols-4 gap-4 pt-12 border-t border-white/10">
				{[
					{ label: "Total Players", value: "8,234" },
					{ label: "Total Paid Out", value: "$4.2M" },
					{ label: "Avg. Win Rate", value: "1/100" },
					{ label: "Next Draw", value: "04:59" },
				].map((stat, i) => (
					<div key={i} className="text-center space-y-1">
						<div className="text-gray-500 text-xs font-mono uppercase tracking-widest">{stat.label}</div>
						<div className="text-2xl font-bold font-orbitron text-white">{stat.value}</div>
					</div>
				))}
			</div>
		</div>
	);
}
