# xpectrum-contracts

smart contracts for [Xpectrum](https://x.com/xpectrum_xyz), the first NFT marketplace on [Octra](https://octra.org).

written in AML (AppliedML), Octra's native contract language.

---

## contracts

### XNS-1 — Xpectrum NFT Standard
base non-fungible token contract. defines the standard interface all NFTs on Xpectrum conform to.

- mint, transfer, approve, operator pattern
- royalty support (up to 10%)
- `get_token_info` and `get_contract_info` for indexer/wallet compatibility

### Xcollection
full drop contract. implements XNS-1 and handles the entire collection lifecycle.

- three-phase minting: GTD (guaranteed) >> FCFS >> public
- per-phase wallet caps + global wallet cap
- genesis injection: up to 20% of supply (max 222) reserved for Spectra Genesis holders
  - each genesis token ID usable once per collection
  - `sweep_injection()` closes genesis path and returns unclaimed slots to public cap
- airdrop (up to 20 addresses per call, all-or-nothing)
- pull-based proceeds split: 97.5% creator / 2.5% platform
- reveal/unrevealed URI pattern
- pause/unpause, phase override for admin control

### Xlist
per-collection whitelist manager. one Xlist per collection.

- operator-controlled, bound to a collection address
- phase 0 = GTD, phase 1 = FCFS
- `add_batch()` for bulk uploads (20 addresses per call)
- `is_whitelisted()` only responds to calls from the registered collection

### Xmarket
secondary marketplace. works with any XNS-1 compatible contract.

- list, buy, cancel listings
- token offers and collection-wide offers
- royalties enforced on every sale
- all proceeds pull-based via `claim_proceeds()`
- 2.5% marketplace fee

---

## devnet addresses

| contract | address |
|---|---|
| XNS-1 | `oct87ryv7C6ZzwQ7xnUdPEaY84SAxtA9TKNWugev1dKf7ti` |
| Xcollection v2 | `octzuh9cEUKSd5iieVN8KUe4cdistvEtb3KbcrJLYVGcqL7` |

explorer: [devnet.octrascan.io](https://devnet.octrascan.io/)

---

## interface notes

all amounts are in raw micro-OCT. 1 OCT = 1,000,000.

uris are stored as strings. clients may use `https://`, `ipfs://`, `ar://`, `oct://`, or any other scheme they understand.

pipe-delimited view functions:

- `get_token_info` >> `id | owner | creator | name | royalty_bps | minted_epoch | uri`
- `get_token_circle_info` >> `token_id | resource_id | uri | access | active | version`
- `get_collection_circle_info` >> `resource_id | base_uri | suffix | unrevealed_uri | access | active | version`
- `XNS1.get_contract_info` >> `name | symbol | total_supply | owner`
- `Xcollection.get_contract_info` >> `name | symbol | total_minted | max_supply | royalty_bps | owner | revealed`
- `get_listing` >> `listing_id | seller | nft_contract | token_id | price | status | listed_epoch`
- `get_offer` >> `offer_id | offerer | nft_contract | token_id | amount | expires_epoch | active`
- `get_phase_info` >> `gtd_price | gtd_start | gtd_end | gtd_cap | gtd_minted | gtd_wallet_cap | fcfs_price | fcfs_start | fcfs_end | fcfs_cap | fcfs_minted | fcfs_wallet_cap | pub_price | pub_start | pub_end | pub_cap | pub_minted | pub_wallet_cap | injection_cap | genesis_minted_count`

there is no `get_active_offers`. iterate 0 to `get_offer_count()-1` and filter client-side. collection offers use `token_id = -1` as sentinel.

### circle resources

xns-1-compatible contracts may expose optional circle resource pointers alongside `token_uri`.

- `token_uri(token_id)` remains the compatibility metadata uri for wallets, marketplaces, and indexers.
- `token_circle_count(token_id)` returns the number of circle refs attached to a token.
- `token_circle_uri(token_id, resource_id)` returns a circle ref, usually an `oct://...` uri.
- iterate `0` to `token_circle_count(token_id)-1`, then use `get_token_circle_info` to read `active`.
- `access` is a non-authoritative client hint, currently expected to be `public` or `sealed_read`.
- current `sealed_read` circle content uses client-side passphrases. never put passphrases, keys, or secrets in contract state.
- circle refs are pointers only. contracts do not enforce circle access policy.
- circle policy fields such as `privacy_class`, `resource_mode`, `policy_hash`, `members_root`, and `export_policy` come from circle metadata, not nft contract enforcement.

`XNS1` stores refs per token. `Xcollection` stores collection-level circle templates, so each resource id resolves as `base_uri + token_id + suffix` after reveal, or `unrevealed_uri` before reveal when set.

---

## rpc

devnet: `http://165.227.225.79:8080/rpc`

---

built by [Hermit](t.me/h8rmitt)
