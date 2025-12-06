import { Link } from "@tanstack/react-router";
import { useState } from "react";
import { NeonText } from "./cyber/NeonText";
import { CyberButton } from "./cyber/CyberButton";

export default function Header() {
	const [walletModalOpen, setWalletModalOpen] = useState(false);
	const [connecting, setConnecting] = useState(false);
	const [connectedWallet, setConnectedWallet] = useState<string | null>(null);
	const [connectedAddr, setConnectedAddr] = useState<string | null>(null);

	const wallets = ["MetaMask", "Rabby", "Rainbow"];

	function handleWalletChoice(name: string) {
		if (connecting) return;
		setConnecting(true);
		setTimeout(() => {
			setConnectedWallet(name);
			setConnectedAddr("0x12...34");
			setConnecting(false);
			setWalletModalOpen(false);
		}, 1100);
	}

	const buttonLabel = connecting
		? "Connecting..."
		: connectedAddr
			? `Connected · ${connectedAddr}`
			: "Connect Wallet";

	return (
		<header className="border-b border-white/10 bg-black/40 backdrop-blur-sm sticky top-0 z-50">
			<div className="container mx-auto px-4 py-3 flex items-center justify-between">
				<Link to="/" className="flex items-center gap-2 group hover:opacity-80 transition-opacity">
					<div className="w-8 h-8 bg-[var(--neon-pink)] transform rotate-45 group-hover:rotate-90 transition-transform duration-500 flex items-center justify-center">
						<div className="w-4 h-4 bg-black transform -rotate-45" />
					</div>
					<NeonText as="h1" color="pink" className="text-2xl font-bold tracking-widest">
						MEGAPOT
					</NeonText>
				</Link>

				<nav className="flex items-center gap-6">
					<div className="hidden md:flex items-center gap-6">
						<Link to="/" className="text-sm font-mono text-[var(--neon-cyan)] hover:text-white transition-colors uppercase tracking-widest flex items-center gap-2">
							<span className="w-1 h-1 bg-[var(--neon-cyan)] animate-pulse" />
							Dashboard
						</Link>
						<Link to="/" className="text-sm font-mono text-gray-400 hover:text-[var(--neon-yellow)] transition-colors uppercase tracking-widest">
							History
						</Link>
						<Link to="/" className="text-sm font-mono text-gray-400 hover:text-[var(--neon-pink)] transition-colors uppercase tracking-widest">
							Rules
						</Link>
					</div>

					<div className="flex items-center gap-4">
						<div className="hidden sm:block text-xs font-mono text-gray-500 border border-gray-800 px-2 py-1 rounded bg-black/50">
							<span className="w-2 h-2 inline-block bg-green-500 rounded-full mr-2 animate-pulse" />
							MEGAETH TESTNET
						</div>
						<CyberButton
							size="sm"
							neonColor={connectedAddr ? "pink" : "cyan"}
							className="hidden sm:flex min-w-[170px]"
							onClick={() => setWalletModalOpen(true)}
							disabled={connecting}
						>
							{connecting && (
								<span className="mr-2 inline-flex items-center">
									<span className="w-3 h-3 rounded-full border-2 border-[var(--neon-cyan)] border-t-transparent animate-spin" />
								</span>
							)}
							{buttonLabel}
						</CyberButton>
					</div>
				</nav>
			</div>

			{walletModalOpen && (
				<div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm px-4">
					<div className="relative w-full max-w-sm rounded-xl border border-white/10 bg-black/80 p-6 shadow-2xl">
						<div className="flex items-center justify-between mb-4">
							<NeonText as="h3" color="cyan" className="text-lg font-bold">
								Choose a wallet
							</NeonText>
							<button
								aria-label="Close"
								className="text-gray-400 hover:text-white"
								onClick={() => !connecting && setWalletModalOpen(false)}
							>
								✕
							</button>
						</div>
						<div className="space-y-3">
							{wallets.map((wallet) => (
								<button
									key={wallet}
									onClick={() => handleWalletChoice(wallet)}
									disabled={connecting}
									className="w-full flex items-center justify-between rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-left hover:border-[var(--neon-cyan)] transition-colors"
								>
									<div>
										<div className="font-mono text-white">{wallet}</div>
										<div className="text-xs text-gray-500">Instant connect</div>
									</div>
									{connecting && (
										<span className="w-4 h-4 rounded-full border-2 border-[var(--neon-cyan)] border-t-transparent animate-spin" />
									)}
								</button>
							))}
						</div>
						{connectedWallet && (
							<div className="mt-4 text-xs text-gray-400 font-mono">
								Last connected: {connectedWallet} {connectedAddr ? `(${connectedAddr})` : ""}
							</div>
						)}
					</div>
				</div>
			)}
		</header>
	);
}
