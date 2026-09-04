# Changelog

Every contract version, newest first, with the caller impact of each.

This file is mirrored at [docs.xpectrum.xyz/changelog](https://docs.xpectrum.xyz/changelog). Update both together.

Contracts are immutable once deployed, so any change requires a new deployment under a new version. This file records every version and states the impact on existing callers.

Source and verification certificates: [xpectrum-xyz/xpectrum-contracts](https://github.com/xpectrum-xyz/xpectrum-contracts).

## Versioning

`vMAJOR.MINOR.PATCH`, classified by one question: **does an existing, correct caller keep working, unchanged, with the same result?**

| | Meaning |
|---|---|
| **MAJOR** | The interface changed and calling code must be updated. Renames, signature or return-shape changes, a field that retains its name and changes meaning, or a call that previously succeeded and now reverts. |
| **MINOR** | The interface is unchanged and the observable behaviour differs. New views or events, or a revised constant such as a reserve ceiling or a phase minimum. No code change is required, but values used for planning may differ. |
| **PATCH** | No observable change. Internal hardening only. |

Standards (XNS-1, the Metadata Standard) version separately from the contracts that implement them, as `vMAJOR.MINOR`.

## Deployed now

| Contract | Version | Address |
|---|---|---|
| Xmarket | v3.2.0 | `octGoeTjaF8MiKTP5ad5FJfWMCZmmEdnrfxTow6UUVmBj6h` |
| XuperFactory | v2.0.0 | `octHgTcvueQE5LRb2PYLJqa5T9ypUgBuyY5XyxRstoSdBVN` |
| Xcollection | v4.0.0 | deployed per collection by XuperFactory |
| XpectrumGenesis (Xpectra) | v1.0.1 | `octC4PvHrT8U1vDsZ5ejEBj6UgW2fRoLfohFBSCePdstZfQ` |
| Xincinerator | v1.0.0 | `octGn3QwHTcGjo6Vjz5G9y8Z9hZDsYoA7gbksRqdJoaeg6q` |
| XincineratorLog | v1.0.0 | `oct4u3PmynG2jDJADUF1iVTwPA8oxNy2LQTYNKueGdPN3zh` |

`XNS1.aml` is the reference implementation and is not deployed.

---

## XNS1 v4.0.0

**Reference implementation. Verified, not deployed.** Breaking against rev 3.

Rev 3 is withdrawn and is not included in this repository. Existing implementations based on it should migrate to v4.0.0.

### What changes for implementers
- `is_approved_or_owner` returns `u128` (`1` or `0`). **Rev 3 returned `bool`, which `Xmarket.require(approved == 1)` cannot satisfy, so a literal rev-3 implementation is untradeable on Xmarket.** This is the reason for the migration.
- `total_supply()` is live supply. `total_minted()` is the id count. Rev 3 had one counter.
- New: `burn(token_id)` (holder only), `total_minted()`, `burned()`, `is_burned(token_id)`.
- `get_contract_info()` gained `total_minted | burned | events`.
- Mint emits `Transferred(id, 0, to)`; rev 3 emitted `(id, caller, to)`. Burn emits `Transferred(id, owner, 0)`.
- `event_log` and `get_event_log` added, so an XNS-1 contract is visible to an indexer at all.
- `bool` removed from state and from numerically compared parameters.
- `get_token_circle_info` version is now 2: the `active` column is `1`/`0`.

### Hashes

Source `f55d89cd…`, identical on both chains. Bytecode differs per chain, which is expected:

| Chain | bytecode_hash | size |
|---|---|---|
| mainnet | `cabadd61…` | 12172 |
| devnet | `5336acb6…` | 12412 |

Verified true, 0 errors, 7 warnings on both.

---

## XuperFactory v2.0.0

**2026-08-21, mainnet.** Breaking.

Replaces SuperFactory, which was deployed on 2026-07-20 and never used (`count` 0, so nothing was orphaned).

**What changes for callers**
- The contract is renamed `SuperFactory` to `XuperFactory`. Revert strings are prefixed `xuperfactory:`.
- `create_collection` is payable and requires `value >= launch_fee`. A call that sends nothing now reverts. This is the breaking part.
- The `genesis` parameter is renamed `xpectra`. Positional order is unchanged, so the wire format is identical and no signature changes.
- New views `get_launch_fee()` and `get_fee_balance()`.

**What changes for creators**
- Launching costs a **1 OCT** fee, on top of about 0.2 OCT of network fee. The fee is owner-settable and readable on-chain, and zero is legal.

**Hashes**

| Chain | bytecode_hash |
|---|---|
| mainnet | `4fa02e39…` |
| devnet | `af011ece…` |

The mainnet and devnet builds differ because the embedded Xcollection is compiled per chain. Same source, different bytecode, which is expected on this toolchain.

---

## Xcollection v4.0.0

**2026-08-21, mainnet**, embedded in XuperFactory v2.0.0. Breaking.

Folds in an earlier build from 2026-08-12 that was never deployed.

**What changes for callers**
- `genesis_mint(genesis_id)` is now `xholder_mint(xpectra_id)`.
- `get_genesis_status`, `has_claimed_genesis` and `is_genesis_id_used` are now `get_xholder_status`, `has_claimed_xholder` and `is_xpectra_id_used`.
- `genesis_contract`, `genesis_minted_count`, `genesis_claimed` and `used_genesis_ids` are now `xpectra_contract`, `xholder_minted_count`, `xholder_claimed` and `used_xpectra_ids`.
- `event GenesisMint` is now `event XholderMint`. **Indexers must update their filter, otherwise these mints will no longer be observed.**
- `total_supply()` now returns live supply and `total_minted()` returns the id count. Callers reading `total_supply` as the total ever minted will receive a different value.
- `get_contract_info()` gained a trailing `burned` column.
- New: `burn(token_id)`, `total_minted()`, `burned()`, `is_burned(token_id)`.
- `get_provenance_hash` is now a `view fn`. Reading it no longer costs a transaction.

**What changes for creators**
- The Xholder reserve ceiling is **111**, previously 222. For collections above 555 supply this materially changes the reserved allocation.
- The minimum phase length is **240 epochs**, approximately 40 minutes, previously 360. The earlier value assumed exactly ten seconds per epoch, a rate the chain has not sustained. 240 is derived from the fastest rate measured over 160 days.
- Burning is available, holder-only. It never lowers `max_supply` and never reopens a mint slot.

**Hashes**

| Chain | bytecode_hash |
|---|---|
| mainnet | `e097aa4c…` |

---

## Xcollection v3.1.1

**2026-07-20, mainnet**, embedded in SuperFactory. Patch.

Hardening only, no interface change: checked mint-cost multiplication, a bounds check on `get_approved`, dropped vestigial guards, and `xholder_mint` marks claim state before the external `owner_of` call.

---

## Xcollection v3.1.0

**2026-06-26, devnet.** Minor.

**What changes for creators**
- The Xholder claim became **one per wallet** and was decoupled from the Guaranteed allocation. It no longer increments `gtd_minted` or consumes `gtd_cap`/`gtd_wallet_cap`, so the reserve can never erode a creator's own allowlist.
- New view `has_claimed_genesis` (renamed to `has_claimed_xholder` in v4.0.0).

---

## Xincinerator v1.0.0 and XincineratorLog v1.0.0

**2026-07-28, mainnet.** New.

`Xincinerator` is an ownerless sink: no owner, no entry points, no `call()`, two view functions and nothing else. A token sent to it can never be moved again. `XincineratorLog` batches transfers into it and emits `Burned`, and can only ever name the incinerator fixed in its constructor.

Used to burn 111 Xpectra. See [Xpectra](https://docs.xpectrum.xyz/contracts/genesis#supply).

**Hashes**

| Contract | bytecode_hash |
|---|---|
| Xincinerator | `de1ce6aa…` |
| XincineratorLog | `7b12f208…` |

---

## XpectrumGenesis v1.0.1

**2026-07-21, mainnet**, deployed as Xpectra. Patch.

Hardening for parity with Xcollection: checked mint-cost multiplication, a bounds check on `get_approved`, dropped vestigial guards. No interface change.

**Hashes:** bytecode_hash `9e17d6c9…`

---

## Xmarket v3.2.0

**2026-07-20, mainnet.** Breaking, relative to v3.1.

**What changes for callers**
- `make_collection_offer(nft, duration, quantity)` takes a quantity. `get_offer` now returns 9 fields, and the `coffer` event 7.
- Accepting an offer emits an `osale` event rather than `sale`. Previously an offer accept emitted `sale` carrying an offer id in the listing-id field, which corrupted indexer listing tables. **Consumers indexing sales must handle `osale`.**
- A `cancel` event is now logged when an accept auto-closes a listing, with status 0 rather than 2.
- New `cancel_offer` event.
- New `standard_mode` compatibility lane: owner-flagged collections are checked via `owner_of` plus `get_approved`, which lets ERC-721-shaped contracts trade.
- Accepting one's own offer is now rejected.

**Hashes:** bytecode_hash `943cbd42…`

---

## Earlier

Versions preceding this point were deployed to devnet only. The public history begins at mainnet launch on 2026-07-20.
