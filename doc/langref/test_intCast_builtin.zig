test "integer cast panic" {
    var a: u16 = 0xabcd; // runtime-known
    _ = &a;
    const b: u8 = @intCast(a);
    _ = b;
}

// test_error=integer does not fit in destination type
