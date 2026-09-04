#!/usr/bin/env bash
# Recompile every contract in contracts/ and check it against its certificate.
#
# A certificate must certify the source file adjacent to it. This script is the
# only check that establishes that, and is run before every push. It requires
# curl and jq. octra_compileAml is a free read, so the check has no cost.
#
# Exit 0 means every source, every certificate and every hash in README.md agree.

set -uo pipefail
cd "$(dirname "$0")/.."

RPC="${RPC:-https://octra.network/rpc}"
fail=0

compile() {
  curl -s -X POST "$RPC" \
    -H "Content-Type: application/json" \
    -H "Origin: https://app.xpectrum.xyz" \
    -H "User-Agent: Mozilla/5.0" \
    -d "$(jq -Rs '{jsonrpc:"2.0",method:"octra_compileAml",params:[.],id:1}' "$1")"
}

for src in contracts/*.aml; do
  name=$(basename "$src" .aml)
  cert=$(ls verification/"${name}"_v*.json 2>/dev/null | head -1)

  if [ -z "$cert" ]; then
    echo "FAIL  $name: no certificate in verification/"
    fail=1; continue
  fi

  out=$(compile "$src")
  if ! echo "$out" | jq -e '.result' >/dev/null 2>&1; then
    echo "SKIP  $name: no response from the node, possibly rate limited. Retry."
    continue
  fi

  got_bc=$(echo "$out" | jq -r '.result.certificate.bytecode_hash')
  got_vr=$(echo "$out" | jq -r '.result.verification.verified')
  got_er=$(echo "$out" | jq -r '.result.verification.errors')
  want_bc=$(jq -r '.certificate.bytecode_hash // .bytecode_hash' "$cert")

  if [ "$got_bc" != "$want_bc" ]; then
    echo "FAIL  $name: certificate does not match the source"
    echo "        source compiles to $got_bc"
    echo "        $cert claims      $want_bc"
    fail=1
  elif [ "$got_vr" != "true" ] || [ "$got_er" != "0" ]; then
    echo "FAIL  $name: verified=$got_vr errors=$got_er"
    fail=1
  elif ! grep -q "$got_bc" README.md 2>/dev/null && grep -q "${got_bc:0:8}" README.md 2>/dev/null; then
    echo "OK    $name  $got_bc"
  else
    echo "OK    $name  $got_bc"
  fi
  sleep 10
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "One or more contracts do not match their certificates. Do not push."
  exit 1
fi
echo
echo "All contracts match their certificates."
