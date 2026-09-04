# draft

Not deployed. Nothing here runs on any chain, and none of it is safe to build against yet.

- **`XNS1_v4.aml`** is XNS-1 v2.0, the next standard revision. It adds burn, splits `total_supply` from `total_minted`, and changes `is_approved_or_owner` to return `u128`. All breaking. The standard revision will be published before this ships.
- **`Xauction.aml`** is sealed-bid auctions, v2.0.0. Commit-reveal, with the token escrowed at creation. Verified, undeployed.

Contracts in `../contracts/` are what is live.
