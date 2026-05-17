const { spawn } = require("child_process");

function run(cmd, args) {
	return new Promise((resolve, reject) => {
		const p = spawn(cmd, args, { stdio: "inherit", shell: true });
		p.on("close", (code) =>
			code === 0
				? resolve()
				: reject(new Error(`${cmd} ${args.join(" ")} exited ${code}`)),
		);
	});
}

async function main() {
	try {
		await run("docker", ["build", "-t", "bff-nextjs:local", "./app/nextjs"]);
		await run("docker", ["build", "-t", "bff-go:local", "./app/go-service"]);
		console.log("Built images: bff-nextjs:local, bff-go:local");
	} catch (err) {
		console.error("Build failed:", err);
		process.exit(1);
	}
}

main();
