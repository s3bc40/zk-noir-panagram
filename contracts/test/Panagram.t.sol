// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Panagram} from "../src/Panagram.sol";
import {HonkVerifier, IVerifier} from "../src/Verifier.sol";

contract PanagramTest is Test {
    HonkVerifier public s_verifier;
    Panagram public s_panagram;
    bytes32 public s_answerHash;

    address s_user = makeAddr("user");

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
        vm.prank(s_user);
        bytes memory proof = _getProof(s_answerHash, s_answerHash);
        s_panagram.makeGuess(proof);
        vm.assertEq(s_panagram.balanceOf(s_user, 0), 1);
        vm.assertEq(s_panagram.balanceOf(s_user, 1), 0);

        vm.prank(s_user);
        vm.expectRevert();
        s_panagram.makeGuess(proof);
    }

    // Test someone receives NFT 1 when they guess correctly second

    // Test we can start a new round after min duration or conditions met

    // Get proof generation working with FFI
    function _getProof(
        bytes32 guess,
        bytes32 correctAnswer
    ) internal returns (bytes memory _proof) {
        uint256 NUM_ARGS = 5;
        string[] memory inputs = new string[](NUM_ARGS);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "../scripts/generateProof.ts";
        inputs[3] = vm.toString(guess);
        inputs[4] = vm.toString(correctAnswer);

        // Call the script via FFI
        bytes memory encodedProof = vm.ffi(inputs);

        // Decode thhe ABI-encoded proof bytes
        (_proof) = abi.decode(encodedProof, (bytes));

        console.log("Decoded proof for contract:");
        console.logBytes(_proof);
        return _proof;
    }
}
