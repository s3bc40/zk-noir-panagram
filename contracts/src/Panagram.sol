// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVerifier} from "./Verifier.sol";

contract Panagram is ERC1155, Ownable {
    uint256 public constant MIN_DURATION = 3 hours;

    bytes32 public s_answer;
    uint256 public s_roundStartTime;
    address public s_currentRoundWinner;
    uint256 public s_currentRound;
    IVerifier public s_verifier;
    // Track the last round a user guessed correctly (avoid multiple rewards in one round)
    mapping(address => uint256) public s_lastCorrectGuesRound;

    // Events
    event Panagram__VerifierUpdated(address newVerifier);
    event Panagram__NewRoundStarted(bytes32 answerHash);
    // First user to guess correctly
    event Panagram__WinnerCrowned(address indexed winner, uint256 round);
    // Subsequent users to guess correctly
    event Panagram__RunnerUpCrowned(address indexed runnerUp, uint256 round);

    // Errors
    error Panagram__MinTimeNotPassed(uint256 minDuration, uint256 timePassed);
    error Panagram__NoRoundWinner();
    error Panagram__FirstPanagramNotSet(); // when attempting to guess on an uninitialized round
    error Panagram__AlreadyGuessedCorrectly(address user, uint256 round);
    error Panagram__InvalidProof();

    constructor(
        IVerifier _verifier
    )
        ERC1155(
            "ipfs://bafybeicqfc4ipkle34tgqv3gh7gccwhmr22qdg7p6k6oxon255mnwb6csi/{id}.json"
        )
        Ownable(msg.sender)
    {
        s_verifier = _verifier;
    }

    // function to create a new round
    function newRound(bytes32 _answer) external onlyOwner {
        if (s_roundStartTime == 0) {
            s_roundStartTime = block.timestamp;
            s_answer = _answer;
        } else {
            if (block.timestamp < s_roundStartTime + MIN_DURATION) {
                revert Panagram__MinTimeNotPassed({
                    minDuration: MIN_DURATION,
                    timePassed: block.timestamp - s_roundStartTime
                });
            }
            if (s_currentRoundWinner == address(0)) {
                revert Panagram__NoRoundWinner();
            }
            // Reset for new round
            s_roundStartTime = block.timestamp;
            s_currentRoundWinner = address(0);
            s_answer = _answer;
        }
        s_currentRound++;
        emit Panagram__NewRoundStarted(_answer);
    }

    // function to allow users to submit a guess
    function makeGuess(bytes memory _proof) external returns (bool) {
        if (s_currentRound == 0) {
            revert Panagram__FirstPanagramNotSet();
        }
        if (s_lastCorrectGuesRound[msg.sender] == s_currentRound) {
            revert Panagram__AlreadyGuessedCorrectly({
                user: msg.sender,
                round: s_currentRound
            });
        }
        // Prepare public inputs for verifier
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = s_answer;
        publicInputs[1] = bytes32(uint256(uint160(msg.sender))); // cast to bytes32

        // Verify the proof
        try s_verifier.verify(_proof, publicInputs) returns (bool proofResult) {
            if (!proofResult) {
                revert Panagram__InvalidProof();
            }
        } catch {
            // Any revert from the verifier means invalid proof
            revert Panagram__InvalidProof();
        }
        // Proof is valid - reward the user
        s_lastCorrectGuesRound[msg.sender] = s_currentRound;
        if (s_currentRoundWinner == address(0)) {
            s_currentRoundWinner = msg.sender;
            _mint(msg.sender, 0, 1, ""); // Mint winner token (id 0)
            emit Panagram__WinnerCrowned(msg.sender, s_currentRound);
        } else {
            _mint(msg.sender, 1, 1, ""); // Mint runner-up token (id 1)
            emit Panagram__RunnerUpCrowned(msg.sender, s_currentRound);
        }

        return true;
    }

    // set a new verifier
    function setVerifier(IVerifier _verifier) external onlyOwner {
        s_verifier = _verifier;
        emit Panagram__VerifierUpdated(address(_verifier));
    }
}
