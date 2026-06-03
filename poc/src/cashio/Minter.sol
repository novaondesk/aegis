// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
    function balanceOf(address who) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// A collateral LP token, modelling Cashio's Saber "Arrow" account. The exploit hinged
/// on the program trusting the LP's *self-reported* relationships (its `bank`) without
/// ever checking the LP's `mint` against a known, trusted token. Here the LP self-reports
/// which `bank` it belongs to — a check the attacker can satisfy with fakes.
interface ICollateralLP {
    function bank() external view returns (address);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// Minimal model of Cashio's `brrr` mint instruction: deposit a collateral LP, mint CASH
/// 1:1. The bug is account validation that only checks accounts *against each other*
/// (relative), never anchoring to a trusted root mint/program.
///
/// See docs/exploits/cashio-infinite-mint-2022-03-23.md
abstract contract MinterBase {
    IERC20Mintable public immutable cash;

    constructor(IERC20Mintable _cash) {
        cash = _cash;
    }

    function mint(ICollateralLP lp, address bank, uint256 amount) external virtual;
}

/// VULNERABLE: validates that the LP's reported bank matches the passed-in `bank`
/// (a relative check between two attacker-supplied accounts) but never checks that
/// `lp` is the real, trusted collateral token. A parallel tree of fakes passes.
contract VulnerableMinter is MinterBase {
    constructor(IERC20Mintable _cash) MinterBase(_cash) {}

    function mint(ICollateralLP lp, address bank, uint256 amount) external override {
        // assert_keys_eq!(lp.bank, bank) — a relative check that anchors to nothing.
        require(lp.bank() == bank, "bank mismatch");
        lp.transferFrom(msg.sender, address(this), amount);
        cash.mint(msg.sender, amount); // backed by whatever `lp` happens to be
    }
}

/// SAFE: the collateral mint is constrained to a hardcoded, trusted LP token (the Anchor
/// `address = TRUSTED` / `mint = ...` anchor). Fake collateral can't reach the mint.
contract SafeMinter is MinterBase {
    ICollateralLP public immutable trustedLP;

    constructor(IERC20Mintable _cash, ICollateralLP _trustedLP) MinterBase(_cash) {
        trustedLP = _trustedLP;
    }

    function mint(ICollateralLP lp, address bank, uint256 amount) external override {
        require(lp == trustedLP, "untrusted collateral mint"); // anchored to a known root
        require(lp.bank() == bank, "bank mismatch");
        lp.transferFrom(msg.sender, address(this), amount);
        cash.mint(msg.sender, amount);
    }
}
