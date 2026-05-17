import { NextResponse } from "next/server";

export async function GET() {
	try {
		const bffBase =
			process.env.BFF_URL ||
			process.env.NEXT_PUBLIC_BFF_URL ||
			"http://localhost:8080";
		const res = await fetch(`${bffBase}/bff/hello`, { cache: "no-store" });
		const body = await res.text();
		let parsed;
		try {
			parsed = JSON.parse(body);
		} catch {
			parsed = body;
		}
		return NextResponse.json(parsed, { status: res.status });
	} catch (err) {
		// return a 502 with a helpful message
		return NextResponse.json(
			{ error: "failed to proxy to BFF", details: String(err) },
			{ status: 502 },
		);
	}
}
