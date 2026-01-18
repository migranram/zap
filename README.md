# ZAP: A simple Zig Argument Parser

Lightweight implementation of a very simple argument parser for Zig programms. It supports adding arguments of three types: Positionals, Flags and Optionals.

## Adding arguments manually

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

## Adding arguments from structs

It also supports adding arguments directly from a struct.

```Zig
const zap = @import("zap");

const myOptionalArgs = struct {
    optional1: f32,
    int_param_name: i32 = 35, // You can add default values
    just_another_param: bool
};

const notValidArgsType = enum {hello, world};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var parser: zap.ArgumentParser = try zap.ArgumentParser.init(allocator, "my test parser");
    defer parser.deinit();

    _ = parser.addArgumentsFromStruct(myOptionalArgs, zap.ArgumentOptions{ .role = .Optional });
    _ = parser.addArgumentsFromStruct(notValidArgsType, zap.ArgumentOptions{ .role = .Optional }); // This will return _false_ and the args will not be added

    std.debug.print("Arguments before parsing\n", .{});
    parser.printInfo();

    parser.parse() catch {
        std.debug.print(">>> Error parsing arguments!\n", .{});
        return;
    };

    std.debug.print("\n\nArguments after parsing\n", .{});
    parser.printInfo();
}
```


## Notes

- Internally, floats and integers are casted to _f64_ and _i64_ respectively.
- If no default value is given, they are *undefined*.

