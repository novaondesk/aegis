// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Unverified flash-loan / external callback: a borrower (or any callback receiver like
/// uniswapV2Call / onFlashLoan / receiveFlashLoan) performs privileged mid-operation logic but
/// never checks that `msg.sender` is the expected lender/pool and that `initiator` is itself. An
/// attacker calls the callback directly with crafted parameters — no real loan occurs — and
/// triggers the privileged logic against the contract's own funds. Fix: verify caller + initiator.
///
/// See docs/exploits/unverified-flashloan-callback.md

/// VULNERABLE: trusts whoever calls the callback.
contract VulnerableBorrower {
    IERC20 public immutable token;
    address public immutable lender;

    constructor(IERC20 t, address l) {
        token = t;
        lender = l;
    }

    /// In the intended flow the lender calls this mid-loan; the contract "uses" its working
    /// capital by paying it to a beneficiary encoded in `data`.
    function onFlashLoan(address initiator, address, uint256, uint256, bytes calldata data)
        external
        returns (bytes32)
    {
        // BUG: no require(msg.sender == lender) and no require(initiator == address(this))
        initiator; // unused — the missing check
        address beneficiary = abi.decode(data, (address));
        token.transfer(beneficiary, token.balanceOf(address(this)));
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

/// SAFE: only the trusted lender may invoke the callback, and only for a loan this contract itself
/// initiated.
contract SafeBorrower {
    IERC20 public immutable token;
    address public immutable lender;

    constructor(IERC20 t, address l) {
        token = t;
        lender = l;
    }

    function onFlashLoan(address initiator, address, uint256, uint256, bytes calldata data)
        external
        returns (bytes32)
    {
        require(msg.sender == lender, "untrusted lender");
        require(initiator == address(this), "untrusted initiator");
        address beneficiary = abi.decode(data, (address));
        token.transfer(beneficiary, token.balanceOf(address(this)));
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
