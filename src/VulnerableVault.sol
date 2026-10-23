// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VulnerableVault
/// @notice A deliberately INSECURE ETH vault, for demonstration only.
/// @dev The bug: `withdraw` sends ETH to the caller BEFORE it zeroes the
///      caller's balance. A malicious contract can re-enter `withdraw` from
///      its `receive()` callback while its recorded balance is still set,
///      and drain every deposit in the vault. This is the classic
///      reentrancy bug (the same class as the 2016 "The DAO" hack).
contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");

        // BUG: external call happens BEFORE the state update. There is no
        // reentrancy guard and no checks-effects-interactions ordering, so
        // the callee can call back into withdraw() with its balance intact.
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");

        balances[msg.sender] = 0; // too late — funds are already gone
    }

    function totalAssets() external view returns (uint256) {
        return address(this).balance;
    }
}
