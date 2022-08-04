const std = @import("std");
const Point3 = @import("point.zig").Point3;
const Rect3 = @import("rect.zig").Rect3;
const Size3 = @import("size.zig").Size3;

const LayoutError = error{
    OutOfRange,
};

const LayoutType = enum {
    RegularNoOverlap,
    IrregularNoOverlap,
    RegularOverlap,
    IrregularOverlap,
};

const Grid = enum {
    Regular,
    Irregular,
};

const Placement = enum {
    Overlap,
    NoOverlap,
};

const Block = union(enum) {
    size: Size3(u32),
    sizes: []Size3(u32),
};

pub const BlockInfo = struct {
    block: u32,
    channel: u32,
    rect: Rect3(u32),
};

pub fn Range(comptime Type: type) type {
    return struct {
        begin: Type,
        end: Type,

        const Self = @This();

        pub fn init(begin: Type, end: Type) Self {
            return .{ .begin = begin, .end = end };
        }
    };
}

pub const Layout = struct {
    allocator: std.mem.Allocator,
    grid: Grid,
    placement: Placement,
    typ: LayoutType,
    size: Size3(u32),
    coords: ?[]Point3(f64),
    gridsize: Size3(u32),
    block: Block,
    blocks: u32,
    channels: u32,
    whc: u32,
    wh: u32,
    cache: std.ArrayList(BlockInfo),
    contiguous: bool,

    pub fn initRegularNoOverlap(
        allocator: std.mem.Allocator,
        size: Size3(u32),
        blocksize: Size3(u32),
        channels: u32,
    ) Layout {
        var gridsize_width = 1 + ((size.width - 1) / blocksize.width);
        var gridsize_height = 1 + ((size.height - 1) / blocksize.height);
        var gridsize_depth = 1 + ((size.depth - 1) / blocksize.depth);

        return Layout{
            .allocator = allocator,
            .grid = Grid.Regular,
            .placement = Placement.NoOverlap,
            .typ = LayoutType.RegularNoOverlap,
            .size = size,
            .coords = null,
            .gridsize = Size3(u32){
                .width = gridsize_width,
                .height = gridsize_height,
                .depth = gridsize_depth,
            },
            .block = Block{ .size = blocksize },
            .blocks = undefined,
            .channels = channels,
            .whc = gridsize_width * gridsize_height * channels,
            .wh = gridsize_width * gridsize_height,
            .cache = std.ArrayList(BlockInfo).init(allocator),
            .contiguous = channels == 0,
        };
    }

    pub fn deinit(self: *Layout) void {
        self.cache.deinit();
    }

    pub fn getIntersect(self: *Layout, region: Rect3(u32), channel: *u32) !Range(*BlockInfo) {
        switch (self.typ) {
            LayoutType.RegularNoOverlap => return self.getIntersectRegularNoOverlap(region, channel),
            LayoutType.IrregularNoOverlap => return self.getIntersectIrregularNoOverlap(region, channel),
            LayoutType.RegularOverlap => return self.getIntersectRegularOverlap(region, channel),
            LayoutType.IrregularOverlap => return self.getIntersectIrregularOverlap(region, channel),
        }
    }

    fn getIntersectRegularNoOverlap(self: *Layout, region: Rect3(u32), channel: *u32) !Range(*BlockInfo) {
        var x1 = region.x / self.block.size.width;
        var y1 = region.y / self.block.size.height;
        var z1 = region.z / self.block.size.depth;

        var x2 = @minimum(self.gridsize.width - 1, (region.x + region.width - 1) / self.block.size.width);
        var y2 = @minimum(self.gridsize.height - 1, (region.y + region.height - 1) / self.block.size.height);
        var z2 = @minimum(self.gridsize.depth - 1, (region.z + region.depth - 1) / self.block.size.depth);

        // self.cache.clearRetainingCapacity();

        var x: u32 = x1;
        var y: u32 = y1;
        var z: u32 = z1;
        while (z <= z2) : (z += 1) {
            while (y <= y2) : (y += 1) {
                while (x <= x2) : (x += 1) {
                    var p = Point3(u32).init(x, y, z);
                    var block = self.toBlock(p, channel);
                    var info = try self.getBlock(block, channel);
                    try self.cache.append(info);
                }
            }
        }

        return Range(*BlockInfo).init(&self.cache.items[0], &self.cache.items[self.cache.items.len - 1]);
    }

    fn getIntersectIrregularNoOverlap(self: *Layout, region: Rect3(u32), channel: *u32) !Range(*BlockInfo) {
        _ = self;
        _ = region;
        _ = channel;

        return undefined;
    }

    fn getIntersectRegularOverlap(self: *Layout, region: Rect3(u32), channel: *u32) !Range(*BlockInfo) {
        _ = self;
        _ = region;
        _ = channel;
        return undefined;
    }

    fn getIntersectIrregularOverlap(self: *Layout, region: Rect3(u32), channel: *u32) !Range(*BlockInfo) {
        _ = self;
        _ = region;
        _ = channel;
        return undefined;
    }

    pub fn getBlock(self: *Layout, block: u32, channel: *u32) LayoutError!BlockInfo {
        switch (self.typ) {
            LayoutType.RegularNoOverlap => return self.getBlockRegularNoOverlap(block, channel),
            LayoutType.IrregularNoOverlap => return self.getBlockIrregularNoOverlap(block, channel),
            LayoutType.RegularOverlap => return self.getBlockRegularOverlap(block, channel),
            LayoutType.IrregularOverlap => return self.getBlockIrregularOverlap(block, channel),
        }
    }

    fn getBlockRegularNoOverlap(self: *Layout, block: u32, channel: *u32) LayoutError!BlockInfo {
        var loc = try self.locFromBlockNoOverlap(block, channel);

        var x = loc.x * self.block.size.width;
        var y = loc.y * self.block.size.height;
        var z = loc.z * self.block.size.depth;
        var width = self.block.size.width;
        var height = self.block.size.height;
        var depth = self.block.size.depth;

        var rect = Rect3(u32).init(x, y, z, width, height, depth);

        return BlockInfo{
            .block = block,
            .channel = channel.*,
            .rect = rect,
        };
    }

    fn getBlockIrregularNoOverlap(self: *Layout, block: u32, channel: *u32) LayoutError!BlockInfo {
        // TODO
        _ = self;
        _ = block;
        _ = channel;
        return BlockInfo{
            .block = block,
            .channel = channel.*,
            .rect = undefined,
        };
    }

    fn getBlockRegularOverlap(self: *Layout, block: u32, channel: *u32) LayoutError!BlockInfo {
        // TODO
        _ = self;
        _ = block;
        _ = channel;
        return BlockInfo{
            .block = block,
            .channel = channel.*,
            .rect = undefined,
        };
    }

    fn getBlockIrregularOverlap(self: *Layout, block: u32, channel: *u32) LayoutError!BlockInfo {
        // TODO
        _ = self;
        _ = block;
        _ = channel;
        return BlockInfo{
            .block = block,
            .channel = channel.*,
            .rect = undefined,
        };
    }

    fn locFromBlockOverlap(self: *Layout, block: u32, channel: *u32) Point3(u32) {
        var index: usize = 0;
        if (self.contiguous) {
            index = @intCast(usize, block);
            channel.* = 0;
        } else {
            index = @intCast(usize, self.blocks % self.channels);
            channel.* = self.blocks / self.channels;
        }

        var x = @floatToInt(u32, self.coords.?[index].x);
        var y = @floatToInt(u32, self.coords.?[index].x);
        var z = @floatToInt(u32, self.coords.?[index].x);

        return Point3(u32).init(x, y, z);
    }

    fn locFromBlockNoOverlap(self: *Layout, block: u32, channel: *u32) LayoutError!Point3(u32) {
        var x: u32 = undefined;
        var y: u32 = undefined;
        var z: u32 = undefined;
        std.debug.print("CHANNEL-PRE: {d}\n", .{channel.*});

        if (self.contiguous) {
            channel.* = 0;
            var quot_1 = block / self.wh;
            if (quot_1 > self.gridsize.depth) {
                return error.OutOfRange;
            }
            var rem_1 = block % self.wh;
            var quot_2 = rem_1 / self.gridsize.width;
            var rem_2 = rem_1 % self.gridsize.width;

            x = rem_2;
            y = quot_2;
            z = quot_1;
        } else {
            var quot_1 = block / self.whc;
            std.debug.print("QUOT_1: {d}\n", .{quot_1});
            if (quot_1 > self.gridsize.depth) {
                return error.OutOfRange;
            }
            var rem_1 = block % self.whc;
            std.debug.print("REM_1: {d}\n", .{rem_1});
            var quot_2 = rem_1 / self.wh;
            std.debug.print("QUOT_2: {d}\n", .{quot_2});
            var rem_2 = rem_1 % self.wh;
            std.debug.print("REM_2: {d}\n", .{rem_2});
            var quot_3 = rem_2 / self.gridsize.width;
            std.debug.print("QUOT_3: {d}\n", .{quot_3});
            var rem_3 = rem_2 % self.gridsize.width;
            std.debug.print("REM_3: {d}\n", .{rem_3});

            x = rem_3;
            y = quot_3;
            z = quot_1;
            channel.* = quot_2;
            std.debug.print("CHANNEL: {d}\n", .{channel.*});
        }

        return Point3(u32).init(x, y, z);
    }

    fn toBlock(self: *Layout, loc: Point3(u32), channel: *u32) u32 {
        // if (self.placement != Placement.NoOverlap) unreachable;
        if (self.contiguous) {
            return loc.x + loc.y * self.gridsize.width + loc.z * self.wh;
        } else {
            return loc.x + loc.y * self.gridsize.width + channel.* * self.wh + loc.z * self.whc;
        }
    }

    fn sizeFromBlock(self: *Layout, block: u32) Size3(u32) {
        if (self.grid != Grid.Irregular) unreachable;

        var index: usize = 0;
        if (self.isCountiguous()) {
            index = @intCast(usize, block);
        } else {
            index = @intCast(usize, self.blocks % self.channels);
        }

        return self.block.sizes[index];
    }

    fn removeRedundancies(self: *Layout, cache: []BlockInfo, overlaps: []const Rect3(u32)) void {
        // TODO
        _ = cache;
        _ = overlaps;
        if (self.placement != Placement.Overlap) unreachable;
    }
};

test "initRegularNoOverlap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var size = Size3(u32).init(2048, 2048, 3);
    var block_size = Size3(u32).init(512, 512, 3);
    var channels: u32 = 3;
    var layout = Layout.initRegularNoOverlap(
        allocator,
        size,
        block_size,
        channels,
    );
    defer layout.deinit();

    try std.testing.expect(layout.grid == Grid.Regular);
    try std.testing.expect(layout.placement == Placement.NoOverlap);
    try std.testing.expect(layout.typ == LayoutType.RegularNoOverlap);
    try std.testing.expect(std.meta.eql(layout.size, Size3(u32){ .width = 2048, .height = 2048, .depth = 3 }));
    try std.testing.expect(layout.coords == null);
    try std.testing.expect(std.meta.eql(layout.gridsize, Size3(u32){ .width = 4, .height = 4, .depth = 1 }));
    try std.testing.expect(std.meta.eql(layout.block.size, block_size));
    try std.testing.expect(layout.blocks == undefined);
    try std.testing.expect(layout.channels == channels);
    try std.testing.expect(layout.whc == 48); // 4 * 4 * 3
    try std.testing.expect(layout.wh == 16); // 4 * 4
    try std.testing.expect(@TypeOf(layout.cache) == std.ArrayList(BlockInfo));
    try std.testing.expect(layout.cache.items.len == 0);
    try std.testing.expect(layout.contiguous == false);
}

test "getBlockRegularNoOverlap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var size = Size3(u32).init(2048, 2048, 3);
    var block_size = Size3(u32).init(512, 512, 3);
    var layout = Layout.initRegularNoOverlap(
        allocator,
        size,
        block_size,
        3,
    );
    defer layout.deinit();

    var channel: u32 = 1;
    var block = try layout.getBlock(6, &channel);

    std.debug.print("{any}\n", .{block});
}

test "getIntersectRegularNoOverlap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var size = Size3(u32).init(2048, 2048, 3);
    var block_size = Size3(u32).init(512, 512, 3);
    var layout = Layout.initRegularNoOverlap(
        allocator,
        size,
        block_size,
        3,
    );
    defer layout.deinit();

    var region = Rect3(u32).init(0, 0, 0, 1024, 1024, 1);
    var channel: u32 = 1;
    var range = try layout.getIntersect(region, &channel);
    std.debug.print("{any}\n", .{layout});
    std.debug.print("{any}\n", .{range});
}

test "locFromBlockNoOverlap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var size = Size3(u32).init(2048, 2048, 3);
    var block_size = Size3(u32).init(512, 512, 3);
    var layout = Layout.initRegularNoOverlap(allocator, size, block_size, 3);
    defer layout.deinit();

    var block: u32 = 5;
    var channel: u32 = 2;
    var loc = try layout.locFromBlockNoOverlap(block, &channel);

    std.debug.assert(loc.x == 1);
    std.debug.assert(loc.y == 1);
    std.debug.assert(loc.z == 0);
    std.debug.assert(channel == 0);
}
