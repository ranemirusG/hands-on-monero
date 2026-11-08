# Glossary

One line each, in the order you meet them in the exercises.

| Term | Meaning |
|---|---|
| **Stagenet** | Monero's public test network: mainnet's rules and software, worthless coins. |
| **Node** (`monerod`) | Keeps a copy of the blockchain and relays transactions. The lab uses someone else's (a **remote node**). |
| **Seed** | 25 words that encode the wallet's private spend key, from which every other key and address follows. |
| **Restore height** | The block a wallet starts scanning from when restored. Too high misses coins; too low is just slow. |
| **Private spend key** | Signs spends. Whoever has it (or the seed) owns the coins. |
| **Private view key** | Recognises incoming payments and reads their amounts. Can't spend. |
| **Standard address** | The wallet's main address (index 0). Stagenet `5…`, mainnet `4…`. |
| **Subaddress** | Another address of the same wallet, unlinkable to the others. Stagenet `7…`, mainnet `8…`. |
| **Account** | A group of subaddresses whose coins are never spent together with another account's. |
| **Integrated address** | Standard address + 8-byte payment ID in one string. Mostly replaced by subaddresses. |
| **Output** | A coin: the result of a payment, owned by exactly one one-time address. |
| **One-time address** (stealth address) | The key an output is sent to, unique per output, derived from the receiver's address and the sender's random tx key. The receiver's address never appears on the chain. |
| **Global output index** | An output's number among all outputs on the chain; rings refer to outputs by it. |
| **Tx key** (`r`) | The sender's random private key for one transaction. Proves a payment to anyone given it; kept only in the sender's wallet cache. |
| **View tag** | One byte per output that lets a wallet skip most outputs that aren't its own without the full check. |
| **RingCT** | Hides amounts with commitments, and proves inputs = outputs + fee without revealing them. |
| **Ring** | The 16 outputs an input points at: the real one and 15 decoys. |
| **Decoy** | A ring member that isn't being spent, picked by the wallet with a bias towards recent outputs. |
| **Key image** | A value computed from a coin's one-time private key. Appears when the coin is spent; the network rejects it a second time. Doesn't reveal which ring member is real. |
| **Lock** | Received coins wait 10 blocks before they can be spent; mined coins wait 60. |
| **View-only wallet** | Address + private view key. Sees incoming coins, can't sign, and can't tell spent coins without imported key images. |
| **Cold wallet** | A wallet with the spend key that never connects to a network; signs transactions built elsewhere. |
| **Multisig** | A wallet whose spends need M of N parties to sign. |
| **Restricted RPC** | The read-only mode public nodes run in: wallets and scripts can ask, but not administer. |
