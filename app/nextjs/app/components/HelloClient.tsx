"use client";

import React from "react";
import { useQuery } from "@tanstack/react-query";

async function fetchHello() {
	const res = await fetch("/api/hello");
	if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
	return res.json();
}

export default function HelloClient() {
	const { data, error, isLoading } = useQuery(["hello"], fetchHello);

	if (isLoading) return <p>Loading...</p>;
	if (error) return <p>Error: {String(error)}</p>;

	return (
		<div>
			<h2>Response from BFF</h2>
			<pre style={{ whiteSpace: "pre-wrap" }}>
				{JSON.stringify(data, null, 2)}
			</pre>
		</div>
	);
}
