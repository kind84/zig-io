pub fn Point3(comptime Type: type) type {
    return struct {
        x: Type,
        y: Type,
        z: Type,

        const Self = @This();

        pub fn init(x: Type, y: Type, z: Type) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
            };
        }
    };
}
