# 06. Integrated addresses, and why subaddresses replaced them

The older way to tell payments apart — some exchanges still use it. An
**integrated address** = standard address + 8-byte **payment ID**.

## Make one (alice)

```
integrated_address
integrated_address <that integrated address>     # decode it back
```

106 characters instead of 95, with a random payment ID inside.

## Pay it

From bob (GUI), send 0.001 to it. Then in alice:

```
payments <payment ID>
show_transfers in
```

It arrives on index 0: integrated addresses only work with the main address.

## Why subaddresses won

- Every customer pays the **same** public address; two customers comparing
  notes see it's the same shop. Subaddresses are unlinkable.
- Old "long" payment IDs were public on the chain (no longer accepted).
- Subaddresses need nothing special from the sender.

## Highlights

- On the explorer this payment looks like any other: every 2-output tx
  carries an encrypted 8-byte payment ID, real or dummy.
