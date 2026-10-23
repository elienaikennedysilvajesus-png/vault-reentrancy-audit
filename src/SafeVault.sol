// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafeVault
/// @notice The fixed version of VulnerableVault. Same feature set.
/// @dev The fix: follow checks-effects-interactions. The balance is zeroed
///      BEFORE the external call, so if the callee re-enters withdraw() it
///      finds a zero balance, the inner call reverts, and the whole attack
///      transaction is rolled back. (A `nonReentrant` mutex would also work;
///      CEI is the cheapest correct fix here.)
contract SafeVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");

        balances[msg.sender] = 0; // effect FIRST

        (bool ok, ) = msg.sender.call{value: amount}(""); // interaction LAST
        require(ok, "transfer failed");
    }

    function totalAssets() external view returns (uint256) {
        return address(this).balance;
    }
}
