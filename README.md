# Serve – Simple Static HTTP Server

A lightweight static HTTP server for serving files, built on top of [zap](https://github.com/zigzap/zap).

## Usage
```sh
serve [PATH] [OPTIONS]

A lightweight static HTTP server for serving files.

Arguments:
  PATH                Specify the server path (default: '.')

Options:
  -h, --help          Show this help message and exit
  -p, --port PORT     Set the server port (default: 8080)
  -t, --threads NUM   Set the number of threads (default: 2)
  -w, --workers NUM   Set the number of workers (default: 1)
```

## Building

### Prerequisites
- `zig` (latest stable release) – the compiler and build system.

To produce an executable in `zig-out/bin`, run:
```sh
zig build -Doptimize=ReleaseFast
```
