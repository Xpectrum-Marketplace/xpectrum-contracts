# xpectrum-contracts

smart contracts for [Xpectrum](https://xpectrum.xyz), the first NFT marketplace on [Octra](https://octra.org).

written in AML (AppliedML), Octra's native contract language. all contracts are formally verified using the AML AST verifier (`aml_safety_report_v1`).

---

## contracts

### XNS-1 rev 3: Xpectrum NFT Standard
base non-fungible token contract. defines the standard interface all NFTs on Xpectrum conform to.

- mint, transfer, approve, operator pattern
- royalty support (up to 10%)
- provenance hash (one-way, owner-set)
- per-token and contract-level circle resource pointers
- `get_token_info`, `get_contract_info`, `get_token_circle_info` for indexer/wallet compatibility
- verified: true / errors: 0 / warnings: 5 (all documented false positives)

### Xcollection v3: drop contract
full launch contract. implements XNS-1 and handles the entire collection lifecycle. deployed and linked by SuperFactory.

- three-phase minting: GTD (guaranteed) >> FCFS >> public
- per-phase wallet caps + global wallet cap
- genesis injection: up to 20% of supply (max 222) reserved for XpectrumGenesis holders
  - each genesis token ID usable once per collection (`genesis_claimed` map)
  - `trigger_sweep()` is permissionless; anyone may call once GTD ends to return unclaimed slots to the public cap
- airdrop (up to 20 addresses per call, all-or-nothing)
- pull-based proceeds split: 97.5% creator / 2.5% platform
- reveal / unrevealed URI pattern
- one-way provenance hash (`set_provenance_hash`)
- holder enumeration index (`get_holders_page`)
- `trusted_factory` auth: factory address may be granted the same permissions as owner/admin
- pause/unpause, phase override for admin control
- on-chain event log
- verified: true / errors: 0 / warnings: 5 (all documented false positives)

### Xmarket v3: secondary marketplace
secondary marketplace. works with any XNS-1 compatible contract.

- list, buy, cancel listings
- token offers and collection-wide offers (`offer_is_collection` flag)
- royalties enforced on every sale
- all proceeds pull-based via `claim_proceeds()`
- 2.5% marketplace fee
- swap-and-pop index with stale-entry zeroing
- self-buy guard, immediate overpayment refund
- verified: true / errors: 0 / warnings: 0

### XlistFactory: whitelist manager factory
deploys Xlist instances for collections. call `create_xlist(collection_addr)` to deploy and initialize an Xlist in one transaction.

- one Xlist per collection, bound at deploy time
- phase 0 = GTD, phase 1 = FCFS
- `add_batch` / `remove_batch` for bulk updates (20 addresses per call)
- `is_whitelisted` only responds to calls from the registered collection

### SuperFactory: permissionless collection launcher
deploys a fully linked Xcollection v3 + Xlist pair in a single transaction. no owner gate on `create_collection`; any wallet may deploy.

- embeds the verified Xcollection v3 bytecode (bytecode_hash `5f946123...`)
- deploys Xlist via XlistFactory and links both to the new collection
- `get_collection(idx)` and `get_count()` for enumeration

### XpectrumGenesis: Beta Genesis
root genesis collection. 3-phase mint with no parent injection dependency. holding a Beta Genesis token grants GTD access on future Xcollection drops.

- standard 3-phase mint (GTD/FCFS/public), no genesis_mint/injection mechanics
- collection-level circle resources (metadata circle for token assets)
- verified: true / errors: 0 / warnings: 4 (all documented false positives)

---

## formal verification

all contracts are verified using the AML AST verifier (`aml_safety_report_v1`, Coq-backed model). verification reports and bytecode certificates are in [`verification/`](./verification/).

| contract | verified | errors | warnings |
|---|---|---|---|
| XNS1.aml | true | 0 | 5 |
| Xcollection_v3.aml | true | 0 | 5 |
| Xmarket_v3.aml | true | 0 | 0 |
| XpectrumGenesis.aml | true | 0 | 4 |

warnings are `unsigned_parameter_without_positive_guard` on token IDs and royalty. documented false positives: zero is a valid token ID (0-indexed) and royalty_bps = 0 means royalty-free.

---

## devnet addresses

| contract | address |
|---|---|
| XNS-1 rev 3 | `octE3czdARy1cLMcaJgXzDQ8mvjLpDWRMLCzuCP8CjniLxf` |
| Xcollection v3 | `octG9g7GBNRbnTiiZy7pdvyAh1VgJ8QRuZG4hKiiLvp3HSj` |
| Xmarket v3 | `octBQG94WAh4dqwtp3dBSMdd7RqL5oBQG74t6nxLzGaYK2m` |
| XlistFactory | `octFUYZEhtiUBZ7PUJr4Nj8ZoCKkNkh6mTYgE5nD6iyqYGq` |
| SuperFactory | `octCrVxhxVz8uWCbC1j6wg1Y1Fn8MvdTwc6AgVgxiC1rQgx` |
| XpectrumGenesis (Beta Genesis) | `octC2SvevEnrXwr2zBrHzhmjeY3p8Y4dEPmRzG9MdEgeZEY` |

explorer: [devnet.octrascan.io](https://devnet.octrascan.io/)

---

## interface notes

all amounts are in raw micro-OCT (ou). 1 OCT = 1,000,000 ou.

pipe-delimited view functions:

- `XNS1.get_token_info(id)` >> `id | owner | creator | name | royalty_bps | minted_epoch | uri`
- `XNS1.get_token_circle_info(id, resource_id)` >> `token_id | resource_id | uri | access | active | version`
- `XNS1.get_contract_info()` >> `name | symbol | total_supply | owner`
- `Xcollection.get_contract_info()` >> `name | symbol | total_minted | max_supply | royalty_bps | owner | revealed`
- `Xcollection.get_phase_info()` >> `gtd_price | gtd_start | gtd_end | gtd_cap | gtd_minted | gtd_wallet_cap | fcfs_price | fcfs_start | fcfs_end | fcfs_cap | fcfs_minted | fcfs_wallet_cap | pub_price | pub_start | pub_end | pub_cap | pub_minted | pub_wallet_cap | injection_cap | genesis_minted_count`
- `Xcollection.get_genesis_status()` >> `genesis_minted_count | injection_cap | genesis_contract | injection_swept`
- `Xcollection.get_wallet_state(wallet)` >> `paused | phase | minted_by_wallet | wl_gtd | wl_fcfs | pending_proceeds`
- `Xcollection.get_collection_circle_info(resource_id)` >> `resource_id | base_uri | suffix | unrevealed_uri | access | active | version`
- `Xcollection.get_holders_page(offset, limit)` >> `total_holders | addr0 | addr1 | ...`
- `Xmarket.get_listing(id)` >> `listing_id | seller | nft_contract | token_id | price | status | listed_epoch`
- `Xmarket.get_offer(id)` >> `offer_id | offerer | nft_contract | token_id | offer_is_collection | amount | expires_epoch | active`
- `Xmarket.get_market_info()` >> `listing_count | offer_count | total_volume | fee_balance | reserve | offer_reserve`

### circle resources

XNS-1-compatible contracts may expose circle resource pointers alongside `token_uri`.

- `token_circle_count(token_id)` returns the number of circle refs attached to a token.
- `token_circle_uri(token_id, resource_id)` returns a circle ref, usually an `oct://...` uri.
- iterate `0` to `token_circle_count(token_id)-1`, then use `get_token_circle_info` to read `active`.
- `access` is a non-authoritative client hint, currently `public` or `sealed_read`.
- circle refs are pointers only. contracts do not enforce circle access policy.

Xcollection stores collection-level circle templates: each resource resolves as `base_uri + token_id + suffix` after reveal, or `unrevealed_uri` before reveal when set.

---

## abi changes vs previous versions

**Xmarket v3 vs v2:**
- `offer_is_collection` flag (1/0) replaces the `token_id == -1` sentinel. u128 cannot represent -1. `get_offer` returns an extra field.
- collection-offer events tagged `coffer|` instead of `offer|`

**Xcollection v3 vs v2:**
- `trigger_sweep()` replaces `sweep_injection()` and is now permissionless (anyone may call once GTD ends)
- new entry points: `set_trusted_factory`, `get_holders_page`, `has_claimed_genesis`
- `genesis_mint` is 1-per-wallet tracked via `genesis_claimed` map, decoupled from gtd allocation
- all money/count fields use u128 (breaking struct/event layout change from v2)

---

## rpc

devnet: `https://devnet.octrascan.io/rpc`

---

built by [Hermit](t.me/h8rmitt)
