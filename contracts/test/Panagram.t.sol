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
    bytes32 public s_answerDoubleHash;

    address s_user = makeAddr("user");
    address s_user2 = makeAddr("user2");

    // Ensure compatibility with the ZK-SNARK circuit (same as in Verifier.sol)
    // Large prime number defines the finite field over which the ZK proof system's arithmetic operates.
    // All calculations within the ZK circuit are performed modulo this prime.
    uint256 public constant FIELD_MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function setUp() public {
        s_verifier = new HonkVerifier();
        s_panagram = new Panagram(IVerifier(s_verifier));

        // Create the answer hash for "panagram"
        bytes32 hashedAnswer = keccak256(abi.encodePacked("panagram")); // Hash the answer
        // Reduce the hash modulo the field modulus to fit within the SNARK field
        // Necessity of ensuring data passed from Solidity to a Noir circuit
        s_answerHash = bytes32(uint256(hashedAnswer) % FIELD_MODULUS);

        // Double hash for commitment
        bytes32 doubleHashedAnswer = keccak256(abi.encodePacked(s_answerHash));
        s_answerDoubleHash = bytes32(
            uint256(doubleHashedAnswer) % FIELD_MODULUS
        );

        // Start the first round
        s_panagram.newRound(s_answerDoubleHash);
    }

    // Test someone receives NFT 0 when they guess correctly first
    function testCorrectFirstGuess() public {
        vm.prank(s_user);
        bytes memory proof = _getProof(
            s_answerHash,
            s_answerDoubleHash,
            s_user
        );
        s_panagram.makeGuess(proof);
        vm.assertEq(s_panagram.balanceOf(s_user, 0), 1);
        vm.assertEq(s_panagram.balanceOf(s_user, 1), 0);

        vm.prank(s_user);
        vm.expectRevert();
        s_panagram.makeGuess(proof);
    }

    // Test someone receives NFT 1 when they guess correctly second
    function testSecondGuessPasses() public {
        vm.prank(s_user);
        bytes memory proof = _getProof(
            s_answerHash,
            s_answerDoubleHash,
            s_user
        );
        s_panagram.makeGuess(proof);
        vm.assertEq(s_panagram.balanceOf(s_user, 0), 1);
        vm.assertEq(s_panagram.balanceOf(s_user, 1), 0);

        vm.prank(s_user2);
        bytes memory proof2 = _getProof(
            s_answerHash,
            s_answerDoubleHash,
            s_user2
        );
        s_panagram.makeGuess(proof2);
        vm.assertEq(
            s_panagram.balanceOf(s_user2, 0),
            0,
            "User2 should not get NFT 0"
        );
        vm.assertEq(
            s_panagram.balanceOf(s_user2, 1),
            1,
            "User2 should get NFT 1"
        );
    }

    // Test we can start a new round after min duration or conditions met
    function testStartSecondRound() public {
        // First user guesses correctly
        vm.prank(s_user);
        bytes memory proof = _getProof(
            s_answerHash,
            s_answerDoubleHash,
            s_user
        );
        s_panagram.makeGuess(proof);

        // Move time forward by min duration
        vm.warp(s_panagram.MIN_DURATION() + 1);

        // Define new answer
        bytes32 newHashedAnswer = keccak256(abi.encodePacked("newpanagram"));
        bytes32 newAnswerHash = bytes32(
            uint256(newHashedAnswer) % FIELD_MODULUS
        );
        bytes32 newDoubleHashedAnswer = keccak256(
            abi.encodePacked(newAnswerHash)
        );
        newDoubleHashedAnswer = bytes32(
            uint256(newDoubleHashedAnswer) % FIELD_MODULUS
        );
        s_panagram.newRound(newDoubleHashedAnswer);

        vm.assertEq(
            s_panagram.s_currentRound(),
            2,
            "Current round should be 2 after starting new round"
        );
        vm.assertEq(
            s_panagram.s_currentRoundWinner(),
            address(0),
            "Winner should be reset"
        );
        vm.assertEq(
            s_panagram.s_answer(),
            newDoubleHashedAnswer,
            "Answer hash should be updated for new round"
        );
    }

    // Test that an invalid proof is rejected
    function testIncorrectGuessFails() public {
        vm.prank(s_user);
        bytes32 fakeAnswerHash = keccak256(abi.encodePacked("wronganswer"));
        fakeAnswerHash = bytes32(uint256(fakeAnswerHash) % FIELD_MODULUS);
        bytes32 doubleHashedFakeAnswer = keccak256(
            abi.encodePacked(fakeAnswerHash)
        );
        doubleHashedFakeAnswer = bytes32(
            uint256(doubleHashedFakeAnswer) % FIELD_MODULUS
        );
        bytes memory proof = _getProof(
            fakeAnswerHash,
            doubleHashedFakeAnswer,
            s_user
        );

        vm.expectRevert(Panagram.Panagram__InvalidProof.selector);
        s_panagram.makeGuess(proof);
    }

    // Get proof generation working with FFI
    function _getProof(
        bytes32 guess,
        bytes32 correctAnswer,
        address sender
    ) internal returns (bytes memory _proof) {
        uint256 NUM_ARGS = 6;
        string[] memory inputs = new string[](NUM_ARGS);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "../scripts/generateProof.ts";
        inputs[3] = vm.toString(guess);
        inputs[4] = vm.toString(correctAnswer);
        inputs[5] = vm.toString(sender);

        // Call the script via FFI
        bytes memory encodedProof = vm.ffi(inputs);

        // Decode thhe ABI-encoded proof bytes
        (_proof) = abi.decode(encodedProof, (bytes));

        console.log("Decoded proof for contract:");
        console.logBytes(_proof);
        return _proof;
    }
}
