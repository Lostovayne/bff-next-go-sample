const { spawn } = require("child_process");

const cmd = "docker-compose";
const args = ["-f", "docker-compose.dev.yml", "up", "--build"];

const child = spawn(cmd, args, { stdio: "inherit", shell: true });

process.on("SIGINT", () => {
	console.log("Received SIGINT, forwarding to docker-compose...");
	child.kill("SIGINT");
	process.exit();
});

child.on("exit", (code, signal) => {
	if (signal) process.exit(1);
	process.exit(code);
});
