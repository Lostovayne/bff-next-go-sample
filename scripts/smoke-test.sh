#!/usr/bin/env bash
set -euo pipefail

# Simple smoke test
if curl -sf http://localhost:8080/bff/hello | grep -q hello; then
	echo "Go BFF OK"
else
	echo "Go BFF failed"
	exit 1
fi

if curl -sf http://localhost:3000/ >/dev/null; then
	echo "Next OK"
else
	echo "Next failed"
	exit 1
fi

echo "Smoke tests passed"
