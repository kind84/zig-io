const std = @import("std");
const Point3 = @import("point.zig").Point3;
const Rect3 = @import("rect.zig").Rect3;
const Size3 = @import("size.zig").Size3;

const LayoutError = error{
    OutOfRange,
};

const Grid = union(enum) {
    Regular,
    Irregular,
};

const Placement = union(enum) {
    Overlap,
    NoOverlap,
};

const Block = union {
    size: Size3(u32),
    sizes: []Size3(u32),
};

pub const BlockInfo = struct {
    block: u32,
    channel: u32,
    rect: Rect3(u32),
};

pub const Layout = struct {
    grid: Grid,
    placement: Placement,
    size: Size3(u32),
    coords: ?[]Point3(f64),
    gridsize: Size3(u32),
    block: Block,
    blocks: u32,
    channels: u32,
    whc: u32,
    wh: u32,
    cache: []BlockInfo,
    contiguous: bool,

    pub fn initRegularNoOverlap(size: Size3(u32), blocksize: Size3(u32), channels: u32) Layout {
        var gridsize_width = 1 + ((size.width - 1) / blocksize.width);
        var gridsize_height = 1 + ((size.height - 1) / blocksize.height);
        var gridsize_depth = 1 + ((size.depth - 1) / blocksize.depth);

        return Layout{
            .grid = Grid.Regular,
            .placement = Placement.NoOverlap,
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
            .cache = undefined,
            .contiguous = channels == 0,
        };
    }

    fn locFromBlock(self: Layout, block: u32, channel: *usize) LayoutError!Point3(u32) {
        return switch (self.placement) {
            .Overlap => self.locFromBlockOverlap(block, channel),
            .NoOverlap => self.locFromBlockNoOverlap(block, channel),
        };
    }

    fn locFromBlockOverlap(self: Layout, block: u32, channel: *usize) !Point3(u32) {
        var index: usize = 0;
        if (self.contiguous) {
            index = @intCast(usize, block);
            channel.* = 0;
        } else {
            index = @intCast(usize, self.blocks % self.channels);
            channel.* = @intCast(usize, self.blocks / self.channels);
        }

        var x = @floatToInt(u32, self.coords.?[index].x);
        var y = @floatToInt(u32, self.coords.?[index].x);
        var z = @floatToInt(u32, self.coords.?[index].x);

        return Point3(u32).init(x, y, z);
    }

    fn locFromBlockNoOverlap(self: Layout, block: u32, channel: *usize) !Point3(u32) {
        var x: u32 = undefined;
        var y: u32 = undefined;
        var z: u32 = undefined;

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
            if (quot_1 > self.gridsize.depth) {
                return error.OutOfRange;
            }
            var rem_1 = block % self.whc;
            var quot_2 = rem_1 / self.wh;
            var rem_2 = rem_1 % self.wh;
            var quot_3 = rem_2 / self.gridsize.width;
            var rem_3 = rem_2 % self.gridsize.width;

            x = rem_3;
            y = quot_3;
            z = quot_1;
            channel.* = @intCast(usize, quot_2);
        }

        return Point3(u32).init(x, y, z);
    }

    fn toBlock(self: Layout, channel: usize) u32 {
        // TODO
        _ = channel;
        if (self.placement != Placement.NoOverlap) unreachable;
        return 0;
    }

    fn sizeFromBlock(self: Layout, block: u32) Size3(u32) {
        if (self.grid != Grid.Irregular) unreachable;

        var index: usize = 0;
        if (self.isCountiguous()) {
            index = @intCast(usize, block);
        } else {
            index = @intCast(usize, self.blocks % self.channels);
        }

        return self.block.sizes[index];
    }

    fn removeRedundancies(self: Layout, cache: []BlockInfo, overlaps: []const Rect3(u32)) void {
        // TODO
        _ = cache;
        _ = overlaps;
        if (self.placement != Placement.Overlap) unreachable;
    }
};

test "locFromBlock regular no-overlap" {
    var size = Size3(u32){ .width = 2048, .height = 2048, .depth = 3 };
    var block_size = Size3(u32){ .width = 512, .height = 512, .depth = 3 };
    var layout = Layout.initRegularNoOverlap(size, block_size, 3);

    var block: u32 = 5;
    var channel: usize = 2;
    var loc = try layout.locFromBlock(block, &channel);

    std.debug.print("{}\n", .{channel});
    std.debug.assert(loc.x == 1);
    std.debug.assert(loc.y == 1);
    std.debug.assert(loc.z == 0);
}
