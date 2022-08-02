pub fn Size3(comptime Type: type) type {
    return struct {
        width: Type,
        height: Type,
        depth: Type,

        const Self = @This();

        pub fn init(width: Type, height: Type, depth: Type) Self {
            return Self{
                .width = width,
                .height = height,
                .depth = depth,
            };
        }
    };
}
