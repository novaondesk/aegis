// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Denial-of-service via a reverting recipient (push-payment griefing) (SC10/SC02).
///
/// Any flow that *pushes* ETH to an externally-chosen address and treats the send as a hard
/// requirement can be bricked: a malicious recipient with a reverting (or gas-burning) `receive`
/// makes the whole transaction revert, locking out everyone else. Classic shapes: auction refunds
/// to the previous bidder, "king of the hill" throne refunds, dividend/airdrop loops over a list.
/// (Ethernaut "King"/"Denial".)
///
/// Fix: pull payments. Credit a `pending[recipient]` ledger and let each party `withdraw()`; never
/// let one recipient's failure block another's progress.
///
/// See docs/exploits/dos-griefing-revert.md

/// VULNERABLE: must refund the previous top bidder before accepting a new one.
contract VulnerableAuction {
    address public highestBidder;
    uint256 public highestBid;

    function bid() external payable {
        require(msg.value > highestBid, "bid too low");
        if (highestBidder != address(0)) {
            // BUG: a refund that MUST succeed hands a veto to the current leader.
            (bool ok,) = payable(highestBidder).call{value: highestBid}("");
            require(ok, "refund failed");
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
    }
}

/// SAFE: pull-payment. Outbid funds are credited, not pushed; failures can't block new bids.
contract SafeAuction {
    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public pendingReturns;

    function bid() external payable {
        require(msg.value > highestBid, "bid too low");
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid; // credit, don't push
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "nothing to withdraw");
        pendingReturns[msg.sender] = 0;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "withdraw failed");
    }
}

/// Malicious leader: refuses every refund, so no one can ever outbid it.
contract RevertingBidder {
    function bid(address auction) external payable {
        (bool ok,) = auction.call{value: msg.value}(abi.encodeWithSignature("bid()"));
        require(ok, "bid failed");
    }

    receive() external payable {
        revert("no refunds for you");
    }
}
