# xpectrum-contracts

Smart contracts for [Xpectrum](https://xpectrum.xyz), the ownership layer for on-chain objects on [Octra](https://octra.org).

Written in AML (Applied Meta Language), Octra's native contract language. Every contract here is formally verified with the AML AST verifier (`aml_safety_report_v1`, Coq-backed model) before deployment, and the full report for each is in [`verification/`](./verification/).

Versions follow [CHANGELOG.md](./CHANGELOG.md), which says what changed and whether callers have to do anything.

---

## Deployed on Octra mainnet

| Contract | Version | Address |
|---|---|---|
| Xmarket | v3.2.0 | `octGoeTjaF8MiKTP5ad5FJfWMCZmmEdnrfxTow6UUVmBj6h` |
| XuperFactory | v2.0.0 | `octHgTcvueQE5LRb2PYLJqa5T9ypUgBuyY5XyxRstoSdBVN` |
| Xcollection | v4.0.0 | deployed per collection by XuperFactory |
| Xlist | v2.0.0 | deployed per collection by XuperFactory, from embedded bytecode |
| XpectrumGenesis (Xpectra) | v1.0.1 | `octC4PvHrT8U1vDsZ5ejEBj6UgW2fRoLfohFBSCePdstZfQ` |
| Xincinerator | v1.0.0 | `octGn3QwHTcGjo6Vjz5G9y8Z9hZDsYoA7gbksRqdJoaeg6q` |
| XincineratorLog | v1.0.0 | `oct4u3PmynG2jDJADUF1iVTwPA8oxNy2LQTYNKueGdPN3zh` |

RPC `https://octra.network/rpc`, explorer [octrascan.io](https://octrascan.io). Mainnet expects browser-shaped requests, so send an `Origin` and a `User-Agent` header or you get an HTML error page instead of JSON.

---

## Contracts

### XNS-1: the Xpectrum NFT standard

XNS-1 is the token interface every NFT on Xpectrum implements, and the one a third party implements to trade on Xmarket without asking anyone.

There is no standalone reference implementation in this repo yet. The two complete, deployed implementations are here instead: `Xcollection.aml` and `XpectrumGenesis.aml`. Read either for the full surface.

Xmarket relies on five entry points. These are the ones that must match exactly:

| Entry point | Signature | Returns |
|---|---|---|
| `owner_of` | `(token_id: u128)` | `address` |
| `is_approved_or_owner` | `(token_id: u128, addr: address)` | `u128`, `1` or `0` |
| `creator_of` | `(token_id: u128)` | `address` |
| `royalty_of` | `(token_id: u128)` | `u128`, basis points, max 1000 |
| `transfer_from` | `(from: address, to: address, token_id: u128)` | moves the token |

Two things bite here.

`is_approved_or_owner` must return **`u128`**, not `bool`. Xmarket settles on `require(approved == 1)`, which a `bool` return can never satisfy, so a contract that returns `bool` compiles, verifies, and is then silently untradeable.

It also takes `token_id` first and the address second. Reversing them fails at settlement rather than at the call.

The rest of the interface: mint, transfer, approve and the operator pattern; a one-way provenance hash; per-token and contract-level circle resource pointers; and `get_token_info`, `get_contract_info`, `get_token_circle_info` for indexers and wallets.

### Xcollection: the drop contract

The full launch contract. Implements XNS-1 and handles the whole collection lifecycle. Deployed and linked by XuperFactory.

- three-phase minting: guaranteed, first come, public, each a time window in epochs with a 240-epoch minimum
- per-phase caps, per-phase wallet caps, and a global wallet cap
- xholder reserve: `min(floor(max_supply * 0.2), 111)` held for Xpectra holders, its own pool, decoupled from the guaranteed allocation so it can never erode a creator's allowlist. One claim per wallet.
- `trigger_sweep()` is permissionless: once guaranteed ends, anyone may return unclaimed reserve slots to the public pool
- `burn(token_id)`, callable only by the current holder. `max_supply` never moves, ids are never reused, live supply is derived as `total_minted - burned`
- airdrop, up to 20 addresses per call, all or nothing
- pull-based proceeds, split 97.5% creator / 2.5% platform
- reveal, with an unrevealed URI before it
- one-way provenance hash
- holder enumeration index, `get_holders_page`
- `trusted_factory` auth, pause/unpause, phase override

### Xmarket: secondary trading

Works with any XNS-1 contract, and with contracts shaped like ERC-721 through the standard-mode lane.

- list, buy, cancel
- single-token offers and collection-wide offers, the latter carrying a quantity
- royalties enforced on every sale
- all proceeds pull-based, through `claim_proceeds()`
- 2.5% fee
- no self-buy, no accepting your own offer
- swap-and-pop index with stale-entry zeroing

### Xlist: allowlists

One Xlist is deployed per collection and bound to it at creation. XuperFactory deploys it from embedded bytecode as part of the same transaction, so there is no separate factory call.

- phase 0 is guaranteed, phase 1 is first come
- `add_batch` / `remove_batch`, 20 addresses per call
- `is_whitelisted` answers only the collection it is registered to

Its source is not in this repo yet. It is deployed as embedded bytecode inside `XuperFactory.aml`, which is published here, so the bytecode is public even though the source is not. That gap is being closed.

### XuperFactory: permissionless launcher

Deploys a linked Xcollection and Xlist in a single transaction. No owner gate on `create_collection`: any wallet may launch.

- embeds the verified Xcollection bytecode
- deploys the Xlist from embedded bytecode and links both, in the same transaction
- the platform wallet is held in factory state, never taken from the caller
- `create_collection` requires a launch fee, currently 1 OCT, readable with `get_launch_fee()`. The fee accrues in the contract and is withdrawn separately, so the launch path contains no external transfer that could revert a deploy.
- `get_collection(idx)` and `get_count()` enumerate

### XpectrumGenesis: the founding collection

The root collection, deployed once as **Xpectra**. Three-phase mint with no parent reserve of its own, because holding Xpectra is what grants the reserve on other collections.

No `xholder_mint`, no reserve, and no `burn`: its supply is fixed at what was minted.

### Xincinerator and XincineratorLog: burning by retirement

`XpectrumGenesis` has no burn function, so 111 Xpectra were burned by sending them somewhere nothing can send them back from.

`Xincinerator` is the sink. It has no owner, no entry points, no `call()`, and nothing but two view functions. Its ABI is the argument: `octra_contractAbi(<Xincinerator>)` returns two functions, both `view: true`, and there is no code path that can move a token out.

`XincineratorLog` batches transfers into the sink and emits `Burned`. It can only ever name the incinerator fixed in its constructor, and only touches tokens whose owner is the caller.

---

## Naming

A source file is named for its contract, with no version in the filename. The version lives in [CHANGELOG.md](./CHANGELOG.md) and in the certificate name, and nowhere else.

One exception you will notice reading the source: `Xmarket.aml` declares `contract Xmarket_v3`, while the contract is at v3.2.0. The contract identifier is compiled into the bytecode, so renaming it would mean redeploying a live marketplace to fix a cosmetic mismatch. It stays as it is. Nothing else carries a version in its identifier, and nothing new will.

## Formal verification

| Contract | Version | Verified | Errors | Warnings | bytecode_hash |
|---|---|---|---|---|---|
| Xcollection | v4.0.0 | true | 0 | 7 | `e097aa4c…` |
| Xmarket | v3.2.0 | true | 0 | 0 | `943cbd42…` |
| XuperFactory | v2.0.0 | true | 0 | 1 | `4fa02e39…` |
| XpectrumGenesis | v1.0.1 | true | 0 | 4 | `9e17d6c9…` |
| Xincinerator | v1.0.0 | true | 0 | 0 | `de1ce6aa…` |
| XincineratorLog | v1.0.0 | true | 0 | 2 | `7b12f208…` |

Every warning is `unsigned_parameter_without_positive_guard`, on token ids, royalty, and the launch fee. They are documented false positives: zero is a valid token id because ids are 0-indexed, `royalty_bps = 0` means royalty-free, and a launch fee of 0 is deliberately allowed so launching can be made free.

Every certificate in `verification/` was generated on 2026-09-04 by compiling the source file beside it, so each one certifies that exact file and nothing else. `scripts/verify.sh` recompiles everything and checks it, and is what we run before pushing.

Each report in `verification/` carries the `bytecode_hash`, `source_hash` and `verification_hash` for that build. Compare a fresh compile against `bytecode_hash`, not `source_hash`: comments do not change bytecode, so `source_hash` moves on a comment edit while `bytecode_hash` does not.

The same source compiles to different bytecode on devnet and mainnet. That is a property of the toolchain, not a mismatch, so a per-chain build has its own `bytecode_hash`.

`XuperFactory.aml` here is the **mainnet** build. The factory embeds compiled Xcollection bytecode, and that blob is compiled per chain, so the devnet build differs from this file in exactly one constant (`XCOLLECTION_BYTECODE`) and nowhere else.

## Reproducing a hash

Compile a source file straight off the node and compare. No wallet, no tooling, no cost:

```bash
curl -s -X POST https://octra.network/rpc \
  -H "Content-Type: application/json" \
  -H "Origin: https://app.xpectrum.xyz" \
  -H "User-Agent: Mozilla/5.0" \
  -d "$(jq -Rs '{jsonrpc:"2.0",method:"octra_compileAml",params:[.],id:1}' contracts/Xmarket.aml)" \
  | jq -r '.result.certificate.bytecode_hash'
```

Known good, verified 2026-09-04:

| File | bytecode_hash |
|---|---|
| `contracts/Xmarket.aml` | `943cbd42f67c2d704c1ec7b1f01facc1a59024a4ce79db7afc8686baeec60e66` |
| `contracts/XuperFactory.aml` | `4fa02e39bd1c3f2e78f4dba2bb34a6882a3d910a2213e3f6af73c8a9d4228e6a` |

Both match what is deployed at the addresses in the table above.

---

## Interface notes

Amounts are in micro-OCT (`ou`). 1 OCT = 1,000,000 ou.

Pipe-delimited views:

- `get_token_info(id)` >> `id | owner | creator | name | royalty_bps | minted_epoch | uri`
- `get_token_circle_info(id, resource_id)` >> `token_id | resource_id | uri | access | active | version`
- `Xcollection.get_contract_info()` >> `name | symbol | total_minted | max_supply | royalty_bps | owner | revealed | burned`
- `Xcollection.get_phase_info()` >> `gtd_price | gtd_start | gtd_end | gtd_cap | gtd_minted | gtd_wallet_cap | fcfs_price | fcfs_start | fcfs_end | fcfs_cap | fcfs_minted | fcfs_wallet_cap | pub_price | pub_start | pub_end | pub_cap | pub_minted | pub_wallet_cap | injection_cap | xholder_minted_count`
- `Xcollection.get_xholder_status()` >> `xholder_minted_count | injection_cap | xpectra_contract | injection_swept`
- `Xcollection.get_wallet_state(wallet)` >> `paused | phase | minted_by_wallet | wl_gtd | wl_fcfs | pending_proceeds`
- `Xcollection.get_collection_circle_info(resource_id)` >> `resource_id | base_uri | suffix | unrevealed_uri | access | active | version`
- `Xcollection.get_holders_page(offset, limit)` >> `total_holders | addr0 | addr1 | ...`
- `Xmarket.get_listing(id)` >> `listing_id | seller | nft_contract | token_id | price | status | listed_epoch`
- `Xmarket.get_offer(id)` >> `offer_id | offerer | nft_contract | token_id | offer_is_collection | amount | quantity | expires_epoch | active`
- `Xmarket.get_market_info()` >> `listing_count | offer_count | total_volume | fee_balance | reserve | offer_reserve`

`XpectrumGenesis` predates the burn work, so its `get_contract_info` ends at `revealed` and it has no `total_minted`, `burned`, `is_burned` or `xholder_*` views. Check which contract you are reading before indexing into a pipe split.

### Circle resources

XNS-1 contracts may expose circle resource pointers alongside `token_uri`.

- `token_circle_count(token_id)` returns how many circle refs a token has
- `token_circle_uri(token_id, resource_id)` returns a ref, usually an `oct://...` uri
- iterate `0` to `token_circle_count(token_id) - 1`, then read `get_token_circle_info` for `active`
- `access` is a client hint and is not authoritative
- circle refs are pointers only. Contracts do not enforce circle access policy.

Xcollection stores collection-level templates: each resource resolves as `base_uri + token_id + suffix` after reveal, or `unrevealed_uri` before it.

---

## Building on this

Implement the five entry points above and your contract trades on Xmarket with no permission from us. Match the types exactly: a `bool` return on `is_approved_or_owner` is the one mistake that costs a redeploy, because the contract will verify cleanly and then refuse every sale.

Full integration guide: [docs.xpectrum.xyz](https://docs.xpectrum.xyz/developers/integrate).

---

## Licence

MIT. See [LICENSE](./LICENSE).
