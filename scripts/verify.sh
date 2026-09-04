#!/usr/bin/env bash
# Verify every contract in contracts/ against its certificate in verification/.
#
# Each certificate records the bytecode hash its source compiles to.
# This script recompiles each source against an Octra node and checks the two agree, so the certificates can be confirmed rather than taken on trust.
#
# Requires curl and jq.
# octra_compileAml is a read-only call and costs nothing.
# Set RPC to use a different node.
# Exit 0 means everything agrees.

set -uo pipefail
cd "$(dirname "$0")/.."

RPC="${RPC:-https://octra.network/rpc}"
fail=0
checked=0
skipped=0

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
    echo "FAIL  $name: no certificate found in verification/"
    fail=1; continue
  fi

  out=$(compile "$src")
  if ! echo "$out" | jq -e '.result' >/dev/null 2>&1; then
    echo "SKIP  $name: no usable response from the node, possibly rate limited"
    skipped=$((skipped + 1)); continue
  fi

  got_bc=$(echo "$out" | jq -r '.result.certificate.bytecode_hash')
  got_vr=$(echo "$out" | jq -r '.result.verification.verified')
  got_er=$(echo "$out" | jq -r '.result.verification.errors')
  want_bc=$(jq -r '.certificate.bytecode_hash // .bytecode_hash' "$cert")

  if [ "$got_bc" != "$want_bc" ]; then
    echo "FAIL  $name: the certificate does not match the source"
    echo "        source compiles to  $got_bc"
    echo "        $cert records $want_bc"
    fail=1
  elif [ "$got_vr" != "true" ] || [ "$got_er" != "0" ]; then
    echo "FAIL  $name: verified=$got_vr errors=$got_er"
    fail=1
  else
    echo "OK    $name  $got_bc"
    checked=$((checked + 1))
  fi
  sleep 10
done

echo
if [ "$fail" -ne 0 ]; then
  echo "One or more contracts do not match their certificates."
  exit 1
fi
if [ "$skipped" -ne 0 ]; then
  echo "$checked verified, $skipped not checked. Re-run to cover the remainder."
  exit 1
fi
echo "$checked contracts match their certificates."
