pub fn Size3(comptime Type: type) type {
    return struct {
        width: Type,
        height: Type,
        depth: Type,
    };
}
