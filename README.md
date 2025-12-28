# ZAP: A simple Zig Argument Parser

Lightweight implementation of a very simple argument parser for Zig programms. It supports adding arguments of three types: Positionals, Flags and Optionals.

See the `src/main.zig` file for an example:

```Zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

const allocator = arena.allocator();

var parser: zap.ArgumentParser = try zap.ArgumentParser.init(allocator, "my test parser");
defer parser.deinit();

_ = parser.addArgument("integer", i32, 125, null); // Default is positional
_ = parser.addArgument("test", bool, null, zap.ArgumentOptions{ .role = .Flag });
_ = parser.addArgument("float", f64, 125.23, zap.ArgumentOptions{ .role = .Optional });
_ = parser.addArgument("string", []const u8, "hello arg", zap.ArgumentOptions{ .role = .Optional });

parser.parse() catch std.debug.print("Error parsing arguments!\n", .{});

parser.printInfo();
```

Call it with:

```bash
<cmd> -10 --test --float 35.2 --string "this is a string"
```

If just testing with this repo:
```bash
zig build
./zig-out/bin/zap -10 --test --float 35.2 --string "this is a string"
```

Internally, floats and integers are casted to _f64_ and _i64_ respectively.


This small project was developed for learning purposes, many features of a full argument parser are missing, but it is enough for most simple use-cases.
