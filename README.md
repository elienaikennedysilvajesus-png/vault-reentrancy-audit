# vault-reentrancy-audit

A small [Foundry](https://book.getfoundry.sh) project that **demonstrates a
reentrancy vulnerability, exploits it in a test, and verifies the fix** — the
way a security review should: with runnable proof, not just prose.

This is the classic reentrancy bug (same class as the 2016 "The DAO" hack),
isolated into a minimal vault so the issue and the fix are easy to see.

## The finding

**`VulnerableVault.withdraw()` is reentrant — an attacker can drain the whole vault.**

| | |
|---|---|
| **Severity** | Critical (direct theft of user funds) |
| **Root cause** | External call before state update; no CEI, no reentrancy guard |
| **Impact** | Any attacker drains 100% of deposited funds |

The vault sends ETH to the caller **before** zeroing the caller's balance:

```solidity
(bool ok, ) = msg.sender.call{value: amount}(""); // interaction
require(ok, "transfer failed");
balances[msg.sender] = 0;                          // effect — too late
```

A malicious contract re-enters `withdraw()` from its `receive()` callback
while its recorded balance is still set, and repeats until the vault is empty.

## Proof of concept

`test/VaultExploit.t.sol` contains three tests:

| Test | What it proves |
|---|---|
| `test_NormalFlowWorks` | The vault works correctly for an honest user. |
| `test_Exploit_DrainsVulnerableVault` | An attacker deposits **1 ETH** and walks away with **6 ETH**, stealing 5 ETH of honest deposits. |
| `test_SameAttackFailsOnSafeVault` | The **same** attack against the fixed vault reverts; honest funds stay safe. |

## The fix

`SafeVault.sol` applies **checks-effects-interactions**: zero the balance
*before* the external call. A re-entrant call then finds a zero balance, the
inner call reverts, and the whole attack transaction is rolled back.

```solidity
balances[msg.sender] = 0;                          // effect FIRST
(bool ok, ) = msg.sender.call{value: amount}("");  // interaction LAST
require(ok, "transfer failed");
```

(A `nonReentrant` mutex, e.g. OpenZeppelin's `ReentrancyGuard`, is an equally
valid fix; CEI is the cheapest correct one here.)

## Run it

```bash
forge install          # pulls forge-std
forge test -vv
```

Expected output:

```
Ran 3 tests for test/VaultExploit.t.sol:VaultExploitTest
[PASS] test_Exploit_DrainsVulnerableVault() (gas: 436896)
[PASS] test_NormalFlowWorks() (gas: 91588)
[PASS] test_SameAttackFailsOnSafeVault() (gas: 413579)
Suite result: ok. 3 passed; 0 failed; 0 skipped
```

## Tech

Solidity · Foundry (forge) · reentrancy / checks-effects-interactions
