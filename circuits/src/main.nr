use dep::keccak256;

fn main(guess_hash: Field, answer_double_hash: pub Field, address: pub Field) {
    // Guess hash convert to byte array
    let guess_hash_decomposed: [u8; 32] = guess_hash.to_be_bytes();

    // Hashed the decomposed guess hash
    let guess_double_hash_decomposed: [u8; 32] = keccak256::keccak256(guess_hash_decomposed, 32);

    // Convert back to field element
    let guess_double_hash: Field = Field::from_be_bytes(guess_double_hash_decomposed);

    // Assert that the double hash of the guess matches the provided answer double hash
    assert(guess_double_hash == answer_double_hash);

    // constraint to ensure address is part of POC
    // pub inputs should affect the proof system
    // but explicitly using them in constraints is a stronger guarantee
    let addr_pow = address.pow_32(2);
    assert(addr_pow == address.pow_32(2));
}

// #[test]
// fn test_main() {
//     main(1, 2);

//     // Uncomment to make test fail
//     // main(1, 1);
// }
