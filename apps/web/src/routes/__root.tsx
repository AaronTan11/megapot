import Header from "@/components/header";
import { ThemeProvider } from "@/components/theme-provider";
import { Toaster } from "@/components/ui/sonner";
import { CyberLayout } from "@/components/CyberLayout";
import {
	HeadContent,
	Outlet,
	createRootRouteWithContext,
} from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/react-router-devtools";
import "../index.css";

export interface RouterAppContext {}

export const Route = createRootRouteWithContext<RouterAppContext>()({
	component: RootComponent,
	head: () => ({
		meta: [
			{
				title: "MEGAPOT | Cyberpunk Lottery",
			},
			{
				name: "description",
				content:
					"Enter the Grid. Win the Pot. The future of decentralized gambling on MegaETH.",
			},
		],
		links: [
			{
				rel: "icon",
				href: "/favicon.ico",
			},
		],
	}),
});

function RootComponent() {
	return (
		<>
			<HeadContent />
			<ThemeProvider
				attribute="class"
				defaultTheme="dark"
				forcedTheme="dark" // Enforce dark mode for the cyber theme
				disableTransitionOnChange
				storageKey="vite-ui-theme">
				<CyberLayout>
					<div className="grid grid-rows-[auto_1fr] min-h-screen">
						<Header />
						<Outlet />
					</div>
					<Toaster
						richColors
						theme="dark"
					/>
				</CyberLayout>
			</ThemeProvider>
			<TanStackRouterDevtools position="bottom-left" />
		</>
	);
}
