fn main(guess_hash: Field, answer_hash: pub Field, address: pub Field) {
    assert(guess_hash == answer_hash);
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
