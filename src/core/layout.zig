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
    block: usize,
    channel: usize,
    rect: Rect3(usize),
};

pub const Layout = struct {
    grid: Grid,
    placement: Placement,
    typ: LayoutType,
    size: Size3(u32),
    coords: ?[]Point3(f64),
    gridsize: Size3(u32),
    block: Block,
    blocks: usize,
    channels: usize,
    whc: usize,
    wh: usize,
    cache: std.ArrayList(BlockInfo),
    contiguous: bool,

    pub fn initRegularNoOverlap(
        allocator: std.mem.Allocator,
        size: Size3(u32),
        blocksize: Size3(u32),
        channels: usize,
    ) Layout {
        var gridsize_width = 1 + ((size.width - 1) / blocksize.width);
        var gridsize_height = 1 + ((size.height - 1) / blocksize.height);
        var gridsize_depth = 1 + ((size.depth - 1) / blocksize.depth);

        return Layout{
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

    pub fn getIntersect(self: *Layout, region: Rect3(usize), channel: usize) ![]BlockInfo {
        switch (self.typ) {
            LayoutType.RegularNoOverlap => return self.getIntersectRegularNoOverlap(region, channel),
            LayoutType.IrregularNoOverlap => return self.getIntersectIrregularNoOverlap(region, channel),
            LayoutType.RegularOverlap => return self.getIntersectRegularOverlap(region, channel),
            LayoutType.IrregularOverlap => return self.getIntersectIrregularOverlap(region, channel),
        }
    }

    fn getIntersectRegularNoOverlap(self: *Layout, region: Rect3(usize), channel: usize) ![]BlockInfo {
        var x1 = region.x / self.block.size.width;
        var y1 = region.y / self.block.size.height;
        var z1 = region.z / self.block.size.depth;

        var x2 = @minimum(self.gridsize.width - 1, (region.x + region.width - 1) / self.block.size.width);
        var y2 = @minimum(self.gridsize.height - 1, (region.y + region.height - 1) / self.block.size.height);
        var z2 = @minimum(self.gridsize.depth - 1, (region.z + region.depth - 1) / self.block.size.depth);

        var x: usize = x1;
        var y: usize = y1;
        var z: usize = z1;
        while (z <= z2) : (z += 1) {
            while (y <= y2) : (y += 1) {
                while (x <= x2) : (x += 1) {
                    var p = Point3(usize).init(x, y, z);
                    var block = self.toBlock(p, channel);
                    var info = try self.getBlock(block, channel);
                    try self.cache.append(info);
                }
            }
        }

        return self.cache.toOwnedSlice();
    }

    fn getIntersectIrregularNoOverlap(self: *Layout, region: Rect3(usize), channel: usize) ![]BlockInfo {
        _ = self;
        _ = region;
        _ = channel;

        return undefined;
    }

    fn getIntersectRegularOverlap(self: *Layout, region: Rect3(usize), channel: usize) ![]BlockInfo {
        _ = self;
        _ = region;
        _ = channel;
        return undefined;
    }

    fn getIntersectIrregularOverlap(self: *Layout, region: Rect3(usize), channel: usize) ![]BlockInfo {
        _ = self;
        _ = region;
        _ = channel;
        return undefined;
    }

    pub fn getBlock(self: *Layout, block: usize, channel: usize) LayoutError!BlockInfo {
        switch (self.typ) {
            LayoutType.RegularNoOverlap => return self.getBlockRegularNoOverlap(block, channel),
            LayoutType.IrregularNoOverlap => return self.getBlockIrregularNoOverlap(block, channel),
            LayoutType.RegularOverlap => return self.getBlockRegularOverlap(block, channel),
            LayoutType.IrregularOverlap => return self.getBlockIrregularOverlap(block, channel),
        }
    }

    fn getBlockRegularNoOverlap(self: *Layout, block: usize, channel: usize) LayoutError!BlockInfo {
        var chan = channel;
        var loc = try self.locFromBlockNoOverlap(block, &chan);

        var x = loc.x * self.block.size.width;
        var y = loc.y * self.block.size.height;
        var z = loc.z * self.block.size.depth;
        var width = self.block.size.width;
        var height = self.block.size.height;
        var depth = self.block.size.depth;

        var rect = Rect3(usize).init(x, y, z, width, height, depth);

        return BlockInfo{
            .block = block,
            .channel = chan,
            .rect = rect,
        };
    }

    fn getBlockIrregularNoOverlap(self: *Layout, block: usize, channel: usize) LayoutError!BlockInfo {
        // TODO
        _ = self;
        _ = block;
        _ = channel;
        return BlockInfo{
            .block = block,
            .channel = channel,
            .rect = undefined,
        };
    }

    fn getBlockRegularOverlap(self: *Layout, block: usize, channel: usize) LayoutError!BlockInfo {
        // TODO
        _ = self;
        _ = block;
        _ = channel;
        return BlockInfo{
            .block = block,
            .channel = channel,
            .rect = undefined,
        };
    }

    fn getBlockIrregularOverlap(self: *Layout, block: usize, channel: usize) LayoutError!BlockInfo {
        // TODO
        _ = self;
        _ = block;
        _ = channel;
        return BlockInfo{
            .block = block,
            .channel = channel,
            .rect = undefined,
        };
    }

    fn locFromBlockOverlap(self: *Layout, block: usize, channel: *usize) Point3(usize) {
        var index: usize = 0;
        if (self.contiguous) {
            index = @intCast(usize, block);
            channel.* = 0;
        } else {
            index = @intCast(usize, self.blocks % self.channels);
            channel.* = self.blocks / self.channels;
        }

        var x = @floatToInt(usize, self.coords.?[index].x);
        var y = @floatToInt(usize, self.coords.?[index].x);
        var z = @floatToInt(usize, self.coords.?[index].x);

        return Point3(usize).init(x, y, z);
    }

    fn locFromBlockNoOverlap(self: *Layout, block: usize, channel: *usize) LayoutError!Point3(usize) {
        var x: usize = undefined;
        var y: usize = undefined;
        var z: usize = undefined;
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

        return Point3(usize).init(x, y, z);
    }

    fn toBlock(self: *Layout, loc: Point3(usize), channel: usize) usize {
        // if (self.placement != Placement.NoOverlap) unreachable;
        if (self.contiguous) {
            return loc.x + loc.y * self.gridsize.width + loc.z * self.wh;
        } else {
            return loc.x + loc.y * self.gridsize.width + channel * self.wh + loc.z * self.whc;
        }
    }

    fn sizeFromBlock(self: *Layout, block: usize) Size3(usize) {
        if (self.grid != Grid.Irregular) unreachable;

        var index: usize = 0;
        if (self.isCountiguous()) {
            index = @intCast(usize, block);
        } else {
            index = @intCast(usize, self.blocks % self.channels);
        }

        return self.block.sizes[index];
    }

    fn removeRedundancies(self: *Layout, cache: []BlockInfo, overlaps: []const Rect3(usize)) void {
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
    var channels: usize = 3;
    var layout = Layout.initRegularNoOverlap(
        allocator,
        size,
        block_size,
        channels,
    );
    defer layout.deinit();

    try std.testing.expectEqual(Grid.Regular, layout.grid);
    try std.testing.expectEqual(Placement.NoOverlap, layout.placement);
    try std.testing.expectEqual(LayoutType.RegularNoOverlap, layout.typ);
    try std.testing.expect(std.meta.eql(layout.size, Size3(u32){ .width = 2048, .height = 2048, .depth = 3 }));
    try std.testing.expect(layout.coords == null);
    try std.testing.expect(std.meta.eql(layout.gridsize, Size3(u32){ .width = 4, .height = 4, .depth = 1 }));
    try std.testing.expect(std.meta.eql(layout.block.size, block_size));
    try std.testing.expect(layout.blocks == undefined);
    try std.testing.expectEqual(channels, layout.channels);
    try std.testing.expect(layout.whc == 48); // 4 * 4 * 3
    try std.testing.expect(layout.wh == 16); // 4 * 4
    try std.testing.expectEqual(std.ArrayList(*BlockInfo), @TypeOf(layout.cache));
    try std.testing.expect(layout.cache.items.len == 0);
    try std.testing.expectEqual(false, layout.contiguous);
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

    var channel: usize = 1;
    var block = try layout.getBlock(6, channel);

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

    var region = Rect3(usize).init(0, 0, 0, 1024, 1024, 1);
    var channel: usize = 1;
    var range = try layout.getIntersect(region, channel);
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

    var block: usize = 5;
    var channel: usize = 2;
    var loc = try layout.locFromBlockNoOverlap(block, &channel);

    std.debug.assert(loc.x == 1);
    std.debug.assert(loc.y == 1);
    std.debug.assert(loc.z == 0);
    std.debug.assert(channel == 0);
}
