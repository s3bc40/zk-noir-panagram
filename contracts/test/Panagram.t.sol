// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Panagram} from "../src/Panagram.sol";
import {HonkVerifier, IVerifier} from "../src/Verifier.sol";

contract PanagramTest is Test {
    HonkVerifier public s_verifier;
    Panagram public s_panagram;
    bytes32 public s_answerHash;

    address user = makeAddr("user");

    // Ensure compatibility with the ZK-SNARK circuit (same as in Verifier.sol)
    // Large prime number defines the finite field over which the ZK proof system's arithmetic operates.
    // All calculations within the ZK circuit are performed modulo this prime.
    uint256 public constant FIELD_MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function setUp() public {
        s_verifier = new HonkVerifier();
        s_panagram = new Panagram(IVerifier(s_verifier));

        // Create the answer hash for "panagram"
        bytes32 hashedAnswer = keccak256(bytes("panagram")); // Hash the answer
        // Reduce the hash modulo the field modulus to fit within the SNARK field
        // Necessity of ensuring data passed from Solidity to a Noir circuit
        s_answerHash = bytes32(uint256(hashedAnswer) % FIELD_MODULUS);

        // Start the first round
        s_panagram.newRound(s_answerHash);
    }

    // Test someone receives NFT 0 when they guess correctly first
    function testCorrectFirstGuess() public {
        vm.prank(user);
        s_panagram.makeGuess(proof);
    }

    // Test someone receives NFT 1 when they guess correctly second

    // Test we can start a new round after min duration or conditions met
}
