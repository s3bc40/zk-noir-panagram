import path from "path";
import { fileURLToPath } from "url";
import fs from "fs";

import { Noir } from "@noir-lang/noir_js";
import { ethers } from "ethers";
import { UltraHonkBackend } from "@aztec/bb.js";

// Get the directory of the script
const currentScriptDir = path.dirname(fileURLToPath(import.meta.url));

// Compute relative path to the circuit file
const relativeCircuitPath = "../circuits/target/zk_panagram.json";

// Resolve the absolute path to the circuit file
const circuitFilePath = path.resolve(currentScriptDir, relativeCircuitPath);

// Read the circuit file
const circuitFile = fs.readFileSync(circuitFilePath, "utf-8");

// Parse the circuit JSON
const circuit = JSON.parse(circuitFile);
// console.log("Circuit loaded successfully:", circuit.bytecode);

export default async function generateProof() {
  // Get arg from command line
  const inputsArray = process.argv.slice(2);

  try {
    const noir = new Noir(circuit);
    await noir.init();

    const backend = new UltraHonkBackend(circuit.bytecode, { threads: 1 });

    const inputs = {
      guess_hash: inputsArray[0],
      answer_hash: inputsArray[1],
    };

    const { witness } = await noir.execute(inputs);

    // Temporarily suppress console.log output from the backend
    const originalLog = console.log;
    console.log = () => {}; // Override with an empty function

    const { proof } = await backend.generateProof(witness, { keccakZK: true });

    // Restore original console.log
    console.log = originalLog;

    // Encode proof for smart contract
    const encodedProof = ethers.AbiCoder.defaultAbiCoder().encode(
      ["bytes"], // Solidity types
      [proof] // Values to encode
    );

    return encodedProof;
  } catch (error) {
    console.error("Error generating proof:", error);
    throw error;
  }
}

// Invoked Function Expression (IIFE) to run the proof generation when the script is executed directly
(async () => {
  try {
    const proof = await generateProof();
    // Output the proof to stdout for FFI capture
    process.stdout.write(proof);
    process.exit(0);
  } catch (error) {
    // If there's an error, exit with a non-zero code
    process.exit(1);
  }
})();
