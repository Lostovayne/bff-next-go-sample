const http = require("http");

function fetchJson(url, timeout = 5000) {
	return new Promise((resolve, reject) => {
		const req = http.get(url, (res) => {
			let data = "";
			res.on("data", (chunk) => (data += chunk));
			res.on("end", () => {
				try {
					const parsed = JSON.parse(data);
					resolve(parsed);
				} catch (e) {
					resolve(data);
				}
			});
		});
		req.on("error", reject);
		req.setTimeout(timeout, () => {
			req.destroy(new Error("Request timed out"));
		});
	});
}

async function main() {
	try {
		const resp = await fetchJson("http://localhost:8080/bff/hello");
		const msg = typeof resp === "object" ? resp.message : resp;
		if (msg && msg.toString().includes("hello")) {
			console.log("Go BFF OK");
		} else {
			console.error("Go BFF unexpected response:", resp);
			process.exit(1);
		}
	} catch (e) {
		console.error("Go BFF failed:", e.message);
		process.exit(1);
	}

	try {
		await new Promise((resolve, reject) => {
			const req = http.get("http://localhost:3000/", (res) => {
				if (res.statusCode >= 200 && res.statusCode < 400) resolve();
				else reject(new Error("Next returned " + res.statusCode));
			});
			req.on("error", reject);
			req.setTimeout(5000, () => req.destroy(new Error("Request timed out")));
		});
		console.log("Next OK");
	} catch (e) {
		console.error("Next failed:", e.message);
		process.exit(1);
	}

	console.log("Smoke tests passed");
}

main();
