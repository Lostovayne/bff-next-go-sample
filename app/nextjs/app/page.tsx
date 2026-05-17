import React from "react";
import HelloClient from "./components/HelloClient";

export default function Home() {
	return (
		<main style={{ padding: 24 }}>
			<h1>BFF Next + Go sample</h1>
			<p>
				La app cliente usa TanStack Query para consultar el BFF a través de la
				ruta /api/hello (proxy).
			</p>

			<HelloClient />
		</main>
	);
}
