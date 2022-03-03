const std = @import("std");
const testing = std.testing;
const logger = std.log.scoped(.main);

// pub const log_level: std.log.Level = .err;

const STEPS = 10_000_000;

const universeSize = 9;
const intialTriplets = STS9;

const Triplet = usize;

const STS = struct {
    neg: ?Triplet,
    ones: std.ArrayList(Triplet),
};

pub fn main() !void {
    var r = std.rand.DefaultPrng.init(std.crypto.random.int(u64)).random();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    try mh(allocator, r, STEPS);
}

pub fn mh(allocator: std.mem.Allocator, r: std.rand.Random, steps: usize) !void {
    var seen = std.AutoHashMap(u64, void).init(allocator);

    var sample_buf: [universeSize]usize = undefined;
    const sample = Sample(usize).init(r, sample_buf[0..]);

    var f = STS{
        .neg = null,
        .ones = try std.ArrayList(Triplet).initCapacity(allocator, intialTriplets.len + 0xfff),
        // TODO count max size of ones
    };
    f.ones.appendSliceAssumeCapacity(intialTriplets[0..]);

    var i: usize = 0;
    var xp: Triplet = undefined;
    var yp: Triplet = undefined;
    var zp: Triplet = undefined;
    var triplet: TripletSplit = undefined;
    while (i < steps) : (i += 1) {
        if (f.neg) |neg| {
            triplet = split(neg);
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
            try seen.put(hasher.final(), {});
        }
    }
    std.debug.print("seen {}\n", .{seen.count()});
}

fn setToZero(comptime T: type, list: []T, x: T) void {
    for (list) |*y| {
        if (x == y.*) y.* = 0;
    }
}

fn move(f: *STS, x: Triplet, y: Triplet, z: usize, xp: usize, yp: usize, zp: usize) void {
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

fn split(h: Triplet) TripletSplit {
    var buf: [3]Triplet = undefined;
    var i: usize = 0;
    var j: usize = 0;
    while (i < universeSize) : (i += 1) {
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

const STS7 = [_]Triplet{ 7, 25, 97, 42, 82, 76, 52 };
const STS9 = [_]Triplet{ 7, 73, 273, 161, 266, 146, 98, 140, 84, 292, 56, 448 };
