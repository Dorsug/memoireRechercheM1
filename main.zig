const std = @import("std");
const testing = std.testing;
const logger = std.log.scoped(.main);

// pub const log_level: std.log.Level = .err;

const Triplet = usize;
const saveBeforeFlush = 100_000;

const STS = struct {
    neg: ?Triplet,
    ones: std.ArrayList(Triplet),
};

pub fn main() !void {
    var r = std.rand.DefaultPrng.init(std.crypto.random.int(u64)).random();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const config = parseArgs();
    try mh(allocator, r, config.steps, config.size, config.sts, "res.txt");
}

fn parseArgs() struct { steps: usize, size: usize, sts: []const Triplet } {
    // default values
    var steps: usize = 0;
    var sts_index: usize = 7;

    var buf: [0xfff]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buf[0..]);
    const allocator = fba.allocator();

    var it = std.process.ArgIterator.initWithAllocator(allocator) catch {
        return .{ .steps = steps, .size = sts_index, .sts = initialSTS[sts_index] };
    };
    defer it.deinit();

    _ = it.next(); // skip program name
    if (it.next()) |arg| {
        steps = std.fmt.parseInt(usize, arg, 10) catch steps;
    }
    if (it.next()) |arg| {
        sts_index = std.fmt.parseInt(usize, arg, 10) catch sts_index;
    }

    return .{ .steps = steps, .size = sts_index, .sts = initialSTS[sts_index] };
}

pub fn mh(
    allocator: std.mem.Allocator,
    r: std.rand.Random,
    steps: usize,
    maxBits: usize,
    startSts: []const Triplet,
    out_file: []const u8,
) !void {
    var seen: [saveBeforeFlush]u64 = undefined;

    var file = try std.fs.cwd().createFile(out_file, .{.truncate = false});
    defer file.close();
    try file.seekFromEnd(0);
    var writer = file.writer();

    var sample_buf = try allocator.alloc(usize, maxBits);
    defer allocator.free(sample_buf);
    const sample = Sample(usize).init(r, sample_buf);

    var f = STS{
        .neg = null,
        .ones = try std.ArrayList(Triplet).initCapacity(allocator, startSts.len + 1),
    };
    defer f.ones.deinit();
    f.ones.appendSliceAssumeCapacity(startSts);

    var xp: Triplet = undefined;
    var yp: Triplet = undefined;
    var zp: Triplet = undefined;
    var triplet: TripletSplit = undefined;

    var stepsCounter: usize = 0;
    while (stepsCounter < steps) {
        var seenIndex: usize = 0;
        while (seenIndex < saveBeforeFlush and stepsCounter < steps) : (stepsCounter += 1) {
            if (f.neg) |neg| {
                triplet = split(neg, maxBits);
                xp = chooseComp(r, f, triplet.y + triplet.z);
                yp = chooseComp(r, f, triplet.x + triplet.z);
                zp = chooseComp(r, f, triplet.x + triplet.y);
            } else {
                triplet = chooseRandomZero(sample, f);
                xp = findComp(f, triplet.y + triplet.z);
                yp = findComp(f, triplet.x + triplet.z);
                zp = findComp(f, triplet.x + triplet.y);
            }
            move(&f, triplet.x, triplet.y, triplet.z, xp, yp, zp);

            if (f.neg == null) {
                std.sort.sort(usize, f.ones.items, {}, comptime std.sort.asc(usize));
                var hasher = std.hash.Wyhash.init(0);
                for (f.ones.items) |*element| {
                    hasher.update(std.mem.asBytes(element));
                }
                seen[seenIndex] = hasher.final();
                seenIndex += 1;
            }
        }

        {
            var i: usize = 0;
            while(i < seenIndex):(i += 1) {
                try std.fmt.format(writer, "{}\n", .{seen[i]});
            }
            try std.fmt.format(writer, "-- {}\n", .{stepsCounter});
        }
    }
}

fn setToZero(comptime T: type, list: []T, x: T) void {
    for (list) |*y| {
        if (x == y.*) y.* = 0;
    }
}

inline fn move(f: *STS, x: Triplet, y: Triplet, z: usize, xp: usize, yp: usize, zp: usize) void {
    var addOne = ([_]Triplet{ x + y + z, x + yp + zp, xp + y + zp, xp + yp + z })[0..];
    var subOne = ([_]Triplet{ xp + y + z, x + yp + z, x + y + zp, xp + yp + zp })[0..];

    if (f.neg) |neg| {
        if (belongs(Triplet, addOne, neg)) {
            f.neg = null;
            setToZero(Triplet, addOne, neg);
        }
    }

    var i: usize = f.ones.items.len;
    while (i > 0) : (i -= 1) {
        const j = i - 1;
        var item = f.ones.items[j];
        if (belongs(Triplet, subOne, item)) {
            _ = f.ones.swapRemove(j);
            setToZero(Triplet, subOne, item);
        }
    }

    for (subOne) |item| {
        if (item != 0) {
            f.neg = item;
            break; // should be only one
        }
    }

    for (addOne) |item| {
        if (item != 0) f.ones.appendAssumeCapacity(item);
    }
}

fn findComp(f: STS, duet: usize) usize {
    for (f.ones.items) |triplet| {
        if (duet & triplet == duet) {
            return duet ^ triplet;
        }
    }
    unreachable;
}

fn chooseComp(r: std.rand.Random, f: STS, duet: usize) usize {
    var choices: [2]Triplet = undefined;
    var i: usize = 0;
    for (f.ones.items) |triplet| {
        if (duet & triplet == duet) {
            choices[i] = duet ^ triplet;
            i += 1;
        }
    }
    return choices[r.int(u1)];
}

fn split(h: Triplet, maxBits: usize) TripletSplit {
    var buf: [3]Triplet = undefined;
    var i: usize = 0;
    var j: usize = 0;
    while (i < maxBits) : (i += 1) {
        var t = h & @shlExact(@as(usize, 1), @intCast(u6, i));
        if (t > 0) {
            buf[j] = t;
            j += 1;
        }
    }
    return TripletSplit{ .x = buf[0], .y = buf[1], .z = buf[2] };
}

fn Sample(comptime T: type) type {
    return struct {
        const Self = @This();
        r: std.rand.Random,
        buf: []T,

        fn init(r: std.rand.Random, buf: []T) Self {
            var i: usize = 0;
            while (i < buf.len) : (i += 1) {
                buf[i] = @shlExact(@as(usize, 1), @intCast(u6, i));
            }
            return Self{
                .r = r,
                .buf = buf,
            };
        }

        fn get(self: Self) *[3]T {
            var buf = self.buf;
            var i: usize = 0;
            while (i < 3) : (i += 1) {
                const j = self.r.intRangeLessThan(usize, i, buf.len);
                std.mem.swap(T, &buf[i], &buf[j]);
            }
            return buf[0..3];
        }
    };
}

const TripletSplit = struct { x: usize, y: usize, z: usize };

fn chooseRandomZero(sample: Sample(usize), f: STS) TripletSplit {
    var triplet = sample.get();
    var triplet_v = triplet[0] + triplet[1] + triplet[2];
    // Bug in compiler when booleans on the same line
    var belongsToOnes = belongs(usize, f.ones.items, triplet_v);
    var belongsToNeg = triplet_v == f.neg;

    var truth = @as(u8, @boolToInt(!belongsToOnes)) + @as(u8, @boolToInt(!belongsToNeg));

    while (truth != 2) {
        triplet = sample.get();
        triplet_v = triplet[0] + triplet[1] + triplet[2];
        belongsToOnes = belongs(Triplet, f.ones.items, triplet_v);
        belongsToNeg = triplet_v == f.neg;
        truth = @as(u8, @boolToInt(!belongsToOnes)) + @as(u8, @boolToInt(!belongsToNeg));
    }
    return TripletSplit{ .x = triplet[0], .y = triplet[1], .z = triplet[2] };
}

fn belongs(comptime T: type, list: []const T, x: T) bool {
    for (list) |y| {
        if (x == y) return true;
    } else {
        return false;
    }
}

const initialSTS = blk: {
    var buf: [15][]const Triplet = undefined;
    buf[7] = ([_]Triplet{ 7, 25, 97, 42, 82, 76, 52 })[0..];
    buf[9] = ([_]Triplet{ 7, 73, 273, 161, 266, 146, 98, 140, 84, 292, 56, 448 })[0..];
    buf[13] = ([_]Triplet{ 7, 25, 97, 385, 1537, 6145, 42, 146, 322, 2562, 5122, 524, 52, 1092, 4228, 2308, 2120, 1160, 4360, 4176, 784, 3088, 2208, 1312, 4640, 704 })[0..];
    break :blk buf;
};
