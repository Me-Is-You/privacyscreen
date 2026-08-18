const std = @import("std");
const builtin = @import("builtin");

const Config = struct {
    mode: Mode = .vignette,
    falloff: f32 = 4.0,
    max_alpha: f32 = 0.3,
    shape: Shape = .elliptical,
    falloff_type: FalloffType = .smootherstep,
    left_bias: ?f32 = null,
    right_bias: ?f32 = null,
    invert: bool = false,
    stripe_width: u32 = 0,
    stripe_opacity: f32 = 0.8,
    radius_factor: f32 = 1.0,
    view_angle: f32 = 0.0,
    full_screen_cover: bool = false,
    mask_pattern: MaskPattern = .checkerboard,
    mask_size: u32 = 2,
    mask_opacity: f32 = 0.55,
};

const Mode = enum {
    vignette,
    pixel,
};

const MaskPattern = enum {
    checkerboard,
    vertical,
    horizontal,
    diagonal,
    mesh,
    dots,
};

const Shape = enum {
    circle,
    rectangle,
    diamond,
    elliptical,
};

const FalloffType = enum {
    power,
    exponential,
    gaussian,
    smootherstep,
    lens,
};

// Interactive control state
var interactive_config: Config = Config{};
var interactive_enabled = std.atomic.Value(bool).init(false);

const windows = if (builtin.os.tag == .windows) struct {
    const HWND = std.os.windows.HWND;
    const HDC = std.os.windows.HDC;
    const HINSTANCE = std.os.windows.HINSTANCE;
    const WPARAM = std.os.windows.WPARAM;
    const LPARAM = std.os.windows.LPARAM;
    const LRESULT = std.os.windows.LRESULT;
    const UINT = std.os.windows.UINT;
    const BOOL = std.os.windows.BOOL;
    const TRUE = std.os.windows.TRUE;
    const FALSE = std.os.windows.FALSE;
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    const PM_REMOVE: UINT = 0x0001;
    const INFINITE: u32 = std.os.windows.INFINITE;
    const WM_HOTKEY: UINT = 0x0312;
    const WM_QUIT: UINT = 0x0012;

    extern "kernel32" fn WaitForSingleObject(hHandle: *anyopaque, dwMilliseconds: u32) callconv(.winapi) u32;
    extern "kernel32" fn CreateEventW(
        lpEventAttributes: ?*anyopaque,
        bManualReset: i32,
        bInitialState: i32,
        lpName: ?[*:0]const u16,
    ) callconv(.winapi) ?*anyopaque;
    const WAIT_TIMEOUT: u32 = 0x00000102;
    extern "kernel32" fn SetEvent(hEvent: *anyopaque) callconv(.winapi) i32;
    extern "kernel32" fn RegisterHotKey(hWnd: HWND, id: i32, fsModifiers: u32, vk: u32) callconv(.winapi) BOOL;
    extern "kernel32" fn UnregisterHotKey(hWnd: HWND, id: i32) callconv(.winapi) BOOL;
    const MOD_CONTROL: u32 = 0x0002;
    const MOD_SHIFT: u32 = 0x0004;

    extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(.winapi) BOOL;

    extern "kernel32" fn SetConsoleCtrlHandler(
        HandlerRoutine: ?*const fn (dwCtrlType: u32) callconv(.winapi) i32,
        Add: i32,
    ) callconv(.winapi) i32;
    extern "kernel32" fn GetConsoleWindow() callconv(.winapi) ?HWND;

    fn windowsCtrlHandler(dwCtrlType: u32) callconv(.winapi) i32 {
        // 关闭控制台时不退出，继续在托盘后台运行（由托盘菜单或系统控制退出）
        _ = dwCtrlType;
        // 不设置 should_quit，保持后台运行
        return 1;
    }

    extern "user32" fn CreateWindowExW(
        dwExStyle: u32,
        lpClassName: [*:0]const u16,
        lpWindowName: [*:0]const u16,
        dwStyle: u32,
        X: i32,
        Y: i32,
        nWidth: i32,
        nHeight: i32,
        hWndParent: ?HWND,
        hMenu: ?*anyopaque,
        hInstance: ?HINSTANCE,
        lpParam: ?*anyopaque,
    ) callconv(.winapi) ?HWND;

    extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.winapi) u16;
    extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.winapi) BOOL;
    extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
    extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
    extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;
    extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(.winapi) BOOL;
    const SW_HIDE: i32 = 0;
    const SW_SHOW: i32 = 5;
    const SW_MINIMIZE: i32 = 6;
    const SW_RESTORE: i32 = 9;
    const WM_CLOSE: UINT = 0x0010;
    extern "user32" fn GetDC(hWnd: ?HWND) callconv(.winapi) ?HDC;
    extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.winapi) i32;
    extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: i32) callconv(.winapi) isize;
    extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: isize) callconv(.winapi) isize;
    extern "user32" fn UpdateLayeredWindow(
        hWnd: HWND,
        hdcDst: ?HDC,
        pptDst: ?*const POINT,
        psize: ?*const SIZE,
        hdcSrc: ?HDC,
        pptSrc: ?*const POINT,
        crKey: u32,
        pblend: ?*const BLENDFUNCTION,
        dwFlags: u32,
    ) callconv(.winapi) BOOL;
    extern "user32" fn EnumDisplayMonitors(
        hdc: ?HDC,
        lprcClip: ?*const RECT,
        lpfnEnum: *const fn (HMONITOR, HDC, *RECT, LPARAM) callconv(.winapi) BOOL,
        dwData: LPARAM,
    ) callconv(.winapi) BOOL;
    extern "user32" fn GetMonitorInfoW(hMonitor: HMONITOR, lpmi: *MONITORINFO) callconv(.winapi) BOOL;

    extern "shell32" fn Shell_NotifyIconW(
        dwMessage: u32,
        lpData: *NOTIFYICONDATAW,
    ) callconv(.winapi) BOOL;
    const NIM_ADD: u32 = 0x00000000;
    const NIM_DELETE: u32 = 0x00000002;
    const NIM_MODIFY: u32 = 0x00000001;
    const NIF_MESSAGE: u32 = 0x00000001;
    const NIF_ICON: u32 = 0x00000002;
    const NIF_TIP: u32 = 0x00000004;

    extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.winapi) ?HDC;
    extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.winapi) BOOL;
    extern "gdi32" fn CreateDIBSection(
        hdc: ?HDC,
        pbmi: *const BITMAPINFO,
        usage: u32,
        ppvBits: *?*anyopaque,
        hSection: ?*anyopaque,
        offset: u32,
    ) callconv(.winapi) ?*anyopaque;
    extern "gdi32" fn SelectObject(hdc: HDC, h: *anyopaque) callconv(.winapi) ?*anyopaque;
    extern "gdi32" fn DeleteObject(ho: *anyopaque) callconv(.winapi) BOOL;
    extern "gdi32" fn CreateIconIndirect(piconinfo: *ICONINFO) callconv(.winapi) ?*anyopaque;
    extern "gdi32" fn DestroyIcon(hIcon: ?*anyopaque) callconv(.winapi) BOOL;

    const WNDCLASSEXW = extern struct {
        cbSize: UINT = @sizeOf(WNDCLASSEXW),
        style: UINT,
        lpfnWndProc: *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT,
        cbClsExtra: i32 = 0,
        cbWndExtra: i32 = 0,
        hInstance: ?HINSTANCE,
        hIcon: ?*anyopaque = null,
        hCursor: ?*anyopaque = null,
        hbrBackground: ?*anyopaque = null,
        lpszMenuName: ?[*:0]const u16 = null,
        lpszClassName: [*:0]const u16,
        hIconSm: ?*anyopaque = null,
    };

    const MSG = extern struct {
        hWnd: ?HWND,
        message: UINT,
        wParam: WPARAM,
        lParam: LPARAM,
        time: u32,
        pt: POINT,
        lPrivate: u32,
    };

    const POINT = extern struct {
        x: i32,
        y: i32,
    };

    const SIZE = extern struct {
        cx: i32,
        cy: i32,
    };

    const RECT = extern struct {
        left: i32,
        top: i32,
        right: i32,
        bottom: i32,
    };

    const BLENDFUNCTION = extern struct {
        BlendOp: u8,
        BlendFlags: u8,
        SourceConstantAlpha: u8,
        AlphaFormat: u8,
    };

    const BITMAPINFOHEADER = extern struct {
        biSize: u32,
        biWidth: i32,
        biHeight: i32,
        biPlanes: u16,
        biBitCount: u16,
        biCompression: u32,
        biSizeImage: u32,
        biXPelsPerMeter: i32,
        biYPelsPerMeter: i32,
        biClrUsed: u32,
        biClrImportant: u32,
    };

    const RGBQUAD = extern struct {
        rgbBlue: u8,
        rgbGreen: u8,
        rgbRed: u8,
        rgbReserved: u8,
    };

    const BITMAPINFO = extern struct {
        bmiHeader: BITMAPINFOHEADER,
        bmiColors: [1]RGBQUAD,
    };

    const HMONITOR = *opaque {};

    const MONITORINFO = extern struct {
        cbSize: u32,
        rcMonitor: RECT,
        rcWork: RECT,
        dwFlags: u32,
    };

    extern "user32" fn CreatePopupMenu() callconv(.winapi) ?*anyopaque;
    extern "user32" fn AppendMenuW(hMenu: *anyopaque, uFlags: u32, uIDNewItem: usize, lpNewItem: ?[*:0]const u16) callconv(.winapi) BOOL;
    extern "user32" fn TrackPopupMenu(hMenu: *anyopaque, uFlags: u32, x: i32, y: i32, nReserved: i32, hWnd: HWND, lpRect: ?*const RECT) callconv(.winapi) BOOL;
    extern "user32" fn DestroyMenu(hMenu: *anyopaque) callconv(.winapi) BOOL;
    const MF_STRING: u32 = 0x00000000;
    const MF_SEPARATOR: u32 = 0x00000800;
    const MF_POPUP: u32 = 0x00000010;
    const TPM_RIGHTBUTTON: u32 = 0x0002;
    const TPM_RETURNCMD: u32 = 0x0100;
    const TPM_BOTTOMALIGN: u32 = 0x0020;

    const NOTIFYICONDATAW = extern struct {
        cbSize: u32,
        hWnd: ?HWND,
        uID: u32,
        uFlags: u32,
        uCallbackMessage: u32,
        hIcon: ?*anyopaque,
        szTip: [128]u16,
        dwState: u32,
        dwStateMask: u32,
        szInfo: [256]u16,
        uTimeoutOrVersion: u32,
        szInfoTitle: [64]u16,
        dwInfoFlags: u32,
    };

    const ICONINFO = extern struct {
        fIcon: BOOL,
        xHotspot: u32,
        yHotspot: u32,
        hbmMask: ?*anyopaque,
        hbmColor: ?*anyopaque,
    };

    const WS_POPUP: u32 = 0x80000000;
    const WS_VISIBLE: u32 = 0x10000000;
    const WS_EX_LAYERED: u32 = 0x00080000;
    const WS_EX_TRANSPARENT: u32 = 0x00000020;
    const WS_EX_TOOLWINDOW: u32 = 0x00000080;
    const WS_EX_TOPMOST: u32 = 0x00000008;
    const GWL_EXSTYLE: i32 = -20;
    const WM_DESTROY: UINT = 0x0002;
    const WM_COMMAND: UINT = 0x0111;
    const WM_LBUTTONUP: u32 = 0x0202;
    const WM_RBUTTONUP: u32 = 0x0205;
    const BI_RGB: u32 = 0;
    const DIB_RGB_COLORS: u32 = 0;
    const ULW_ALPHA: u32 = 0x00000002;
} else struct {};

fn windowProc(hWnd: windows.HWND, uMsg: windows.UINT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.winapi) windows.LRESULT {
    if (uMsg == windows.WM_CLOSE) {
        // 关闭窗口时隐藏到托盘，继续在后台运行
        _ = windows.ShowWindow(hWnd, windows.SW_HIDE);
        return 0;
    }
    if (uMsg == windows.WM_DESTROY) {
        // 防止窗口被销毁，保持后台运行
        return 0;
    }
    return windows.DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

const MonitorData = struct {
    monitors: std.ArrayListUnmanaged(MonitorInfo),
    allocator: std.mem.Allocator,
};

const MonitorInfo = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

const ScreenDetail = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    aspect_ratio: f32,
    pixel_area: u32,
};

fn detectScreens(allocator: std.mem.Allocator) !std.ArrayListUnmanaged(ScreenDetail) {
    var screens = std.ArrayListUnmanaged(ScreenDetail).empty;
    var monitor_data = MonitorData{ .monitors = std.ArrayListUnmanaged(MonitorInfo).empty, .allocator = allocator };
    defer monitor_data.monitors.deinit(allocator);
    _ = windows.EnumDisplayMonitors(null, null, monitorEnumProc, @intCast(@intFromPtr(&monitor_data)));

    for (monitor_data.monitors.items) |mon| {
        const w: f32 = @floatFromInt(mon.width);
        const h: f32 = @floatFromInt(mon.height);
        const ar = if (h > 0) w / h else 1.0;
        screens.append(allocator, ScreenDetail{
            .x = mon.x,
            .y = mon.y,
            .width = mon.width,
            .height = mon.height,
            .aspect_ratio = ar,
            .pixel_area = @as(u32, @intCast(mon.width)) * @as(u32, @intCast(mon.height)),
        }) catch {};
    }
    return screens;
}

fn monitorEnumProc(hMonitor: windows.HMONITOR, _: windows.HDC, _: *windows.RECT, dwData: windows.LPARAM) callconv(.winapi) windows.BOOL {
    const data: *MonitorData = @ptrFromInt(@as(usize, @intCast(dwData)));
    var mi = std.mem.zeroes(windows.MONITORINFO);
    mi.cbSize = @sizeOf(windows.MONITORINFO);
    if (windows.GetMonitorInfoW(hMonitor, &mi) == windows.TRUE) {
        const info = MonitorInfo{
            .x = mi.rcMonitor.left, .y = mi.rcMonitor.top,
            .width = mi.rcMonitor.right - mi.rcMonitor.left,
            .height = mi.rcMonitor.bottom - mi.rcMonitor.top,
        };
        data.monitors.append(data.allocator, info) catch {};
    }
    return windows.TRUE;
}

fn calculateVignetteFactor(dx: f32, dy: f32, center_x: f32, center_y: f32, config: Config) f32 {
    var eff_dx = dx;
    if (config.left_bias) |bias| { const m = if (bias == 0.0) 0.2 else bias; eff_dx += center_x * m; }
    if (config.right_bias) |bias| { const m = if (bias == 0.0) 0.2 else bias; eff_dx -= center_x * m; }

    var normalized_dist = switch (config.shape) {
        .circle => blk: { const d = @sqrt(eff_dx*eff_dx + dy*dy); const md = @sqrt(center_x*center_x + center_y*center_y); break :blk (d/md) * config.radius_factor; },
        .rectangle => blk: { const dx_ = @abs(eff_dx)/center_x; const dy_ = @abs(dy)/center_y; break :blk @max(dx_, dy_) * config.radius_factor; },
        .diamond => blk: { const dx_ = @abs(eff_dx)/center_x; const dy_ = @abs(dy)/center_y; break :blk ((dx_ + dy_)/2.0) * config.radius_factor; },
        .elliptical => blk: { const a = 1.7; const dx_ = eff_dx/center_x; const dy_ = dy/center_y; const d = @sqrt(dx_*dx_*a + dy_*dy_); const md = @sqrt(a + 1.0); break :blk (d/md) * config.radius_factor; },
    };

    if (config.invert) normalized_dist = 1.0 - normalized_dist;
    normalized_dist = std.math.clamp(normalized_dist, 0.0, 1.0);

    // 全屏防窥：覆盖整个屏幕，不留大面积清晰区域
    if (config.full_screen_cover) {
        normalized_dist = 0.85 + 0.15 * normalized_dist;
    }

    var angle_factor = normalized_dist;
    if (config.view_angle > 0.0) {
        const side_block = @abs(eff_dx) / center_x;
        const angle_effect = std.math.pow(f32, side_block, config.view_angle);
        angle_factor = @max(angle_factor, angle_effect);
    }

    return switch (config.falloff_type) {
        .power => @min(1.0, std.math.pow(f32, angle_factor, config.falloff)),
        .exponential => blk: { const em = @exp(config.falloff) - 1.0; break :blk (@exp(config.falloff * angle_factor) - 1.0) / em; },
        .gaussian => 1.0 - @exp(-config.falloff * angle_factor * angle_factor),
        .smootherstep => blk: { const t = @min(1.0, angle_factor); const ss = t*t*t*(t*(t*6-15)+10); break :blk std.math.pow(f32, ss, config.falloff); },
        .lens => blk: { const t = @min(1.0, angle_factor); const lc = 1.0 - @exp(-3.0*t*t*config.falloff) + 0.15*t*t*t; break :blk @min(1.0, lc); },
    };
}

fn drawVignetteWindows(hwnd: windows.HWND, width: u32, height: u32, xpos: i32, ypos: i32, config: Config) !void {
    const cx = @as(f32, @floatFromInt(width)) / 2.0;
    const cy = @as(f32, @floatFromInt(height)) / 2.0;
    const screen_dc = windows.GetDC(null) orelse return error.GetDCFailed;
    defer _ = windows.ReleaseDC(null, screen_dc);
    const mem_dc = windows.CreateCompatibleDC(screen_dc) orelse return error.CreateDCFailed;
    defer _ = windows.DeleteDC(mem_dc);
    var bmi = std.mem.zeroes(windows.BITMAPINFO);
    bmi.bmiHeader.biSize = @sizeOf(windows.BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = @intCast(width);
    bmi.bmiHeader.biHeight = -@as(i32, @intCast(height));
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = windows.BI_RGB;
    var bits_ptr: ?*anyopaque = null;
    const dib = windows.CreateDIBSection(screen_dc, &bmi, windows.DIB_RGB_COLORS, &bits_ptr, null, 0) orelse return error.CreateDIBFailed;
    if (bits_ptr == null) return error.CreateDIBFailed;
    defer _ = windows.DeleteObject(dib);
    const old_bmp = windows.SelectObject(mem_dc, dib);
    defer _ = windows.SelectObject(mem_dc, old_bmp.?);
    const pixel_count: usize = @as(usize, width) * @as(usize, height);
    const bits = @as([*]u32, @ptrCast(@alignCast(bits_ptr)))[0..pixel_count];

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const dx = @as(f32, @floatFromInt(x)) - cx;
            const dy = @as(f32, @floatFromInt(y)) - cy;
            const alpha: u8 = switch (config.mode) {
                .vignette => blk: {
                    const vf = calculateVignetteFactor(dx, dy, cx, cy, config);
                    var fa: f32 = vf * config.max_alpha;
                    if (config.stripe_width > 0) {
                        const sc = config.stripe_width * 2;
                        const pos = @mod(x, sc);
                        const gp = @as(f32, @floatFromInt(pos)) / @as(f32, @floatFromInt(sc));
                        const gf = @abs(gp - 0.5) * 2.0;
                        if (gp < 0.5) { const sa = 0.3 + 0.7 * gf; fa = @min(fa + sa * config.stripe_opacity, 1.0); }
                    }
                    break :blk @intFromFloat(fa * 255.0);
                },
                .pixel => blk: {
                    const masked = switch (config.mask_pattern) {
                        .checkerboard => (x / config.mask_size + y / config.mask_size) % 2 == 0,
                        .vertical => (x / config.mask_size) % 2 == 0,
                        .horizontal => (y / config.mask_size) % 2 == 0,
                        .diagonal => ((x + y) / config.mask_size) % 2 == 0,
                        .mesh => (x / config.mask_size) % 2 != (y / config.mask_size) % 2,
                        .dots => blk2: {
                            const lx = @as(f32, @floatFromInt(x % config.mask_size)) - @as(f32, @floatFromInt(config.mask_size)) / 2.0;
                            const ly = @as(f32, @floatFromInt(y % config.mask_size)) - @as(f32, @floatFromInt(config.mask_size)) / 2.0;
                            break :blk2 @sqrt(lx*lx + ly*ly) < @as(f32, @floatFromInt(config.mask_size)) / 3.5;
                        },
                    };
                    break :blk if (masked) @intFromFloat(config.mask_opacity * 255.0) else 0;
                },
            };
            bits[y * width + x] = (@as(u32, alpha) << 24);
        }
    }
    const pt_dst = windows.POINT{ .x = xpos, .y = ypos };
    const sz = windows.SIZE{ .cx = @intCast(width), .cy = @intCast(height) };
    const pt_src = windows.POINT{ .x = 0, .y = 0 };
    const blend = windows.BLENDFUNCTION{ .BlendOp = 0, .BlendFlags = 0, .SourceConstantAlpha = 255, .AlphaFormat = 1 };
    _ = windows.UpdateLayeredWindow(hwnd, screen_dc, &pt_dst, &sz, mem_dc, &pt_src, 0, &blend, windows.ULW_ALPHA);
}

fn applyAutoPrivacy(config: *Config, screens: []ScreenDetail) void {
    if (screens.len == 0) return;
    // 自动识别屏幕：根据检测到的屏幕尺寸自动增强真实防窥强度
    // 屏幕越宽、像素越多，侧面遮挡越强（更真实的防窥屏体验）
    var max_pixel_area: u32 = 0;
    var max_aspect: f32 = 1.0;
    for (screens) |s| {
        if (s.pixel_area > max_pixel_area) max_pixel_area = s.pixel_area;
        if (s.aspect_ratio > max_aspect) max_aspect = s.aspect_ratio;
    }
    // 根据最大像素面积自动计算 view_angle（真实防窥强度）
    // 基准：1080p (1920*1080 ≈ 2M) → view_angle ≈ 2.0
    // 4K (3840*2160 ≈ 8M) → view_angle ≈ 5.0
    // 超宽屏 (aspect > 2.0) → 额外增强
    const base_pixels: f32 = 2_073_600.0; // 1920*1080
    const base_angle: f32 = 2.0;
    const area_factor = @as(f32, @floatFromInt(max_pixel_area)) / base_pixels;
    const aspect_bonus = if (max_aspect > 2.0) @as(f32, 1.5) else @as(f32, 1.0);
    const auto_angle = std.math.clamp(base_angle * std.math.pow(f32, area_factor, 0.6) * aspect_bonus, 0.0, 8.0);
    config.view_angle = auto_angle;
    // 自动增强：宽屏自动增加侧面遮挡强度，真实防窥更明显
    if (max_aspect > 2.5) {
        config.view_angle = std.math.clamp(config.view_angle * 1.3, 0.0, 10.0);
        config.falloff = std.math.clamp(config.falloff * 1.2, 1.0, 10.0);
    }
}

fn createVignetteWindows(allocator: std.mem.Allocator, config: Config) !void {
    const hInstance: ?windows.HINSTANCE = @ptrCast(std.os.windows.kernel32.GetModuleHandleW(null));
    const wc = windows.WNDCLASSEXW{
        .style = 0, .lpfnWndProc = windowProc, .hInstance = hInstance,
        .lpszClassName = windows.L("PrivacyScreenV2"),
    };
    _ = windows.RegisterClassExW(&wc);
    var monitor_data = MonitorData{ .monitors = std.ArrayListUnmanaged(MonitorInfo).empty, .allocator = allocator };
    defer monitor_data.monitors.deinit(allocator);
    _ = windows.EnumDisplayMonitors(null, null, monitorEnumProc, @intCast(@intFromPtr(&monitor_data)));

    for (monitor_data.monitors.items) |mon| {
        const hwnd = windows.CreateWindowExW(
            windows.WS_EX_LAYERED | windows.WS_EX_TRANSPARENT | windows.WS_EX_TOOLWINDOW | windows.WS_EX_TOPMOST,
            windows.L("PrivacyScreenV2"), windows.L("PrivacyScreen"),
            windows.WS_POPUP | windows.WS_VISIBLE,
            mon.x, mon.y, mon.width, mon.height,
            null, null, hInstance, null,
        ) orelse continue;
        if (main_hwnd == null) main_hwnd = hwnd;
        drawVignetteWindows(hwnd, @intCast(mon.width), @intCast(mon.height), mon.x, mon.y, config) catch continue;
    }
}

var tray_hwnd: ?windows.HWND = null;
var main_hwnd: ?windows.HWND = null;

var should_quit = std.atomic.Value(bool).init(false);
var quit_event: ?*anyopaque = null;

fn handleSignal(_: c_int) callconv(.C) void { should_quit.store(true, .monotonic); }

fn stdoutPrint(comptime fmt: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print(fmt, args);
}

pub fn main() !void {
    if (builtin.os.tag != .windows) {
        std.debug.print("Only Windows supported.\n", .{});
        std.process.exit(0);
    }
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = parseArgs(allocator) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        std.process.exit(1);
    };

    interactive_config = config;
    interactive_enabled.store(true, .monotonic);

    // 管理员运行时防止乱码：设置控制台为 UTF-8，并隐藏控制台窗口（托盘后台运行，无控制台可见）
    _ = windows.SetConsoleOutputCP(65001);
    if (windows.GetConsoleWindow()) |cw| {
        _ = windows.ShowWindow(cw, windows.SW_HIDE);
    }

    // 自动识别屏幕：启动时检测所有显示器并根据尺寸自动增强真实防窥强度
    var screens = detectScreens(allocator) catch std.ArrayListUnmanaged(ScreenDetail).empty;
    defer screens.deinit(allocator);

    applyAutoPrivacy(&interactive_config, screens.items);

    const stdout_writer = std.io.getStdOut().writer();
    for (screens.items) |s| {
        stdout_writer.print("检测到屏幕: {}x{} 位置({},{}) 比例={:.2} 像素={} 自动防窥强度已增强\n", .{
            s.width, s.height, s.x, s.y, s.aspect_ratio, s.pixel_area,
        }) catch {};
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("PrivacyScreen v2 running. Interactive mode: ON\n", .{});
    try stdout.print("Controls: Ctrl+Up=+opacity, Ctrl+Down=-opacity, Ctrl+Left=-view-angle, Ctrl+Right=+view-angle, Ctrl+S=stripe toggle\n", .{});
    try stdout.print("Real privacy screen: view_angle={}. Front clear, sides blocked.\n", .{config.view_angle});

    // Register interactive hotkeys
        const control_window: ?windows.HWND = windows.CreateWindowExW(0, windows.L("Static"), windows.L("PrivacyControl"),
        0, 0, 0, 0, 0, null, null, @ptrCast(std.os.windows.kernel32.GetModuleHandleW(null)), null) orelse null;

    _ = windows.SetConsoleCtrlHandler(windows.windowsCtrlHandler, 1);

    if (control_window != null) {
        const cw = control_window.?;
        _ = windows.RegisterHotKey(cw, 1, windows.MOD_CONTROL, 38); // Ctrl+Up
        _ = windows.RegisterHotKey(cw, 2, windows.MOD_CONTROL, 40); // Ctrl+Down
        _ = windows.RegisterHotKey(cw, 3, windows.MOD_CONTROL, 37); // Ctrl+Left
        _ = windows.RegisterHotKey(cw, 4, windows.MOD_CONTROL, 39); // Ctrl+Right
        _ = windows.RegisterHotKey(cw, 5, windows.MOD_CONTROL, 83); // Ctrl+S
        _ = windows.RegisterHotKey(cw, 6, windows.MOD_CONTROL, 77); // Ctrl+M (show menu)
        _ = windows.RegisterHotKey(cw, 7, windows.MOD_CONTROL, 70); // Ctrl+F (full screen)
    }

    if (control_window != null) {
        tray_hwnd = control_window;
    }
    var nid: windows.NOTIFYICONDATAW = undefined;
    nid.cbSize = @sizeOf(windows.NOTIFYICONDATAW);
    nid.hWnd = control_window orelse null;
    nid.uID = 1;
    nid.uFlags = windows.NIF_MESSAGE | windows.NIF_ICON | windows.NIF_TIP;
    nid.uCallbackMessage = 1024; // Custom message for tray events
    nid.hIcon = null;
    const tip_str: []const u8 = "PrivacyScreen - Interactive";
    var tip_idx: usize = 0;
    while (tip_idx < tip_str.len and tip_idx < nid.szTip.len - 1) : (tip_idx += 1) {
        nid.szTip[tip_idx] = @as(u16, tip_str[tip_idx]);
    }
    nid.szTip[tip_idx] = 0;
    _ = windows.Shell_NotifyIconW(windows.NIM_ADD, &nid);

    createVignetteWindows(allocator, interactive_config) catch |err| {
        std.debug.print("Error: {}\n", .{err});
    };

    // Mature interactive message loop (instead of blocking WaitForSingleObject)
    var msg: windows.MSG = undefined;
    while (!should_quit.load(.monotonic)) {
        if (windows.PeekMessageW(&msg, null, 0, 0, windows.PM_REMOVE) == windows.TRUE) {
            if (msg.message == windows.WM_HOTKEY) {
                handleHotkey(msg.wParam);
            } else if (msg.message == windows.WM_QUIT) {
                should_quit.store(true, .monotonic);
            } else if (msg.message == 1024) {
                // 托盘图标交互：左键恢复窗口，右键显示菜单
                const is_right = msg.lParam == @as(windows.LPARAM, @intCast(windows.WM_RBUTTONUP));
                const is_left = msg.lParam == @as(windows.LPARAM, @intCast(windows.WM_LBUTTONUP));
                if (is_left) {
                    if (main_hwnd) |hw| {
                        _ = windows.ShowWindow(hw, windows.SW_SHOW);
                        std.debug.print("Tray: Window restored (left-click).\n", .{});
                    }
                } else if (is_right) {
                    if (tray_hwnd) |hw| {
                        showPopupMenu(hw);
                    }
                }
            } else if (msg.message == windows.WM_COMMAND) {
                // Handle menu commands if any were added
                handleMenuCommand(@as(u16, @intCast(msg.wParam)));
            }
            _ = windows.TranslateMessage(&msg);
            _ = windows.DispatchMessageW(&msg);
        } else {
            // Small sleep to prevent CPU spinning
            std.time.sleep(10 * std.time.ns_per_ms);
        }
    }

    if (control_window != null) {
        const cw = control_window.?;
        _ = windows.UnregisterHotKey(cw, 1);
        _ = windows.UnregisterHotKey(cw, 2);
        _ = windows.UnregisterHotKey(cw, 3);
        _ = windows.UnregisterHotKey(cw, 4);
        _ = windows.UnregisterHotKey(cw, 5);
        _ = windows.UnregisterHotKey(cw, 6);
        _ = windows.UnregisterHotKey(cw, 7);
    }

    try stdout.print("Closing... Interactive controls disabled.\n", .{});
}

// Menu command IDs for interactive tray control
const MENU_ID_VIEW_UP = 1001;
const MENU_ID_VIEW_DOWN = 1002;
const MENU_ID_OPACITY_UP = 1003;
const MENU_ID_OPACITY_DOWN = 1004;
const MENU_ID_STRIPE_TOGGLE = 1005;
const MENU_ID_FULL_SCREEN = 1007;
const MENU_ID_SHOW = 1008;
const MENU_ID_EXIT = 1006;

fn showPopupMenu(hwnd: windows.HWND) void {
    const hMenu = windows.CreatePopupMenu() orelse return;
    defer _ = windows.DestroyMenu(hMenu);

    const hSubMenu = windows.CreatePopupMenu() orelse null;
    if (hSubMenu != null) {
        defer _ = windows.DestroyMenu(hSubMenu.?);
        _ = windows.AppendMenuW(hSubMenu.?, windows.MF_STRING, MENU_ID_VIEW_UP, windows.L("View Angle Up"));
        _ = windows.AppendMenuW(hSubMenu.?, windows.MF_STRING, MENU_ID_VIEW_DOWN, windows.L("View Angle Down"));
        _ = windows.AppendMenuW(hSubMenu.?, windows.MF_STRING, MENU_ID_OPACITY_UP, windows.L("Opacity Up"));
        _ = windows.AppendMenuW(hSubMenu.?, windows.MF_STRING, MENU_ID_OPACITY_DOWN, windows.L("Opacity Down"));
    }

    _ = windows.AppendMenuW(hMenu, windows.MF_STRING, MENU_ID_STRIPE_TOGGLE, windows.L("Toggle Stripes"));
    _ = windows.AppendMenuW(hMenu, windows.MF_STRING, MENU_ID_FULL_SCREEN, windows.L("Full Screen Privacy"));
    if (hSubMenu != null) {
        _ = windows.AppendMenuW(hMenu, windows.MF_POPUP, @as(usize, @intFromPtr(hSubMenu.?)), windows.L("View Settings"));
    }
    _ = windows.AppendMenuW(hMenu, windows.MF_SEPARATOR, 0, null);
    _ = windows.AppendMenuW(hMenu, windows.MF_STRING, MENU_ID_SHOW, windows.L("Show Window"));
    _ = windows.AppendMenuW(hMenu, windows.MF_STRING, MENU_ID_EXIT, windows.L("Exit"));

    const flags = windows.TPM_RETURNCMD | windows.TPM_RIGHTBUTTON | windows.TPM_BOTTOMALIGN;
    const ret = windows.TrackPopupMenu(hMenu, flags, 200, 200, 0, hwnd, null);
    if (ret != windows.FALSE) {
        const cmd_id: u16 = @as(u16, @intCast(ret));
        if (cmd_id > 0) {
            handleMenuCommand(cmd_id);
        }
    }
}

fn handleMenuCommand(cmd: u16) void {
    switch (cmd) {
        MENU_ID_VIEW_UP => {
            interactive_config.view_angle = std.math.clamp(interactive_config.view_angle + 0.2, 0.0, 10.0);
            std.debug.print("Tray: View angle increased to {}\n", .{interactive_config.view_angle});
        },
        MENU_ID_VIEW_DOWN => {
            interactive_config.view_angle = std.math.clamp(interactive_config.view_angle - 0.2, 0.0, 10.0);
            std.debug.print("Tray: View angle decreased to {}\n", .{interactive_config.view_angle});
        },
        MENU_ID_OPACITY_UP => {
            interactive_config.max_alpha = std.math.clamp(interactive_config.max_alpha + 0.05, 0.0, 1.0);
            std.debug.print("Tray: Opacity increased to {}\n", .{interactive_config.max_alpha});
        },
        MENU_ID_OPACITY_DOWN => {
            interactive_config.max_alpha = std.math.clamp(interactive_config.max_alpha - 0.05, 0.0, 1.0);
            std.debug.print("Tray: Opacity decreased to {}\n", .{interactive_config.max_alpha});
        },
        MENU_ID_STRIPE_TOGGLE => {
            interactive_config.stripe_width = if (interactive_config.stripe_width > 0) 0 else 15;
            std.debug.print("Tray: Stripe width toggled to {}\n", .{interactive_config.stripe_width});
        },
        MENU_ID_FULL_SCREEN => {
            interactive_config.full_screen_cover = !interactive_config.full_screen_cover;
            std.debug.print("Tray: Full screen privacy toggled to {}\n", .{interactive_config.full_screen_cover});
        },
        MENU_ID_SHOW => {
            if (main_hwnd) |hw| {
                _ = windows.ShowWindow(hw, windows.SW_SHOW);
                std.debug.print("Tray: Window restored.\n", .{});
            }
        },
        MENU_ID_EXIT => {
            std.debug.print("Tray: Exit selected. Closing...\n", .{});
            should_quit.store(true, .monotonic);
        },
        else => {},
    }
}

fn handleHotkey(id: windows.WPARAM) void {
    switch (id) {
        1 => { // Ctrl+Up: +opacity (精细调节)
            interactive_config.max_alpha = std.math.clamp(interactive_config.max_alpha + 0.02, 0.0, 1.0);
            std.debug.print("Opacity: {}\n", .{interactive_config.max_alpha});
        },
        2 => { // Ctrl+Down: -opacity (精细调节)
            interactive_config.max_alpha = std.math.clamp(interactive_config.max_alpha - 0.02, 0.0, 1.0);
            std.debug.print("Opacity: {}\n", .{interactive_config.max_alpha});
        },
        3 => { // Ctrl+Left: -view_angle (精细调节)
            interactive_config.view_angle = std.math.clamp(interactive_config.view_angle - 0.1, 0.0, 10.0);
            std.debug.print("View angle: {}\n", .{interactive_config.view_angle});
        },
        4 => { // Ctrl+Right: +view_angle (精细调节)
            interactive_config.view_angle = std.math.clamp(interactive_config.view_angle + 0.1, 0.0, 10.0);
            std.debug.print("View angle: {}\n", .{interactive_config.view_angle});
        },
        5 => { // Ctrl+S: toggle stripe
            interactive_config.stripe_width = if (interactive_config.stripe_width > 0) 0 else 15;
            std.debug.print("Tray: Stripe width toggled to {}\n", .{interactive_config.stripe_width});
        },
        7 => { // Ctrl+F: full screen privacy toggle
            interactive_config.full_screen_cover = !interactive_config.full_screen_cover;
            std.debug.print("Full screen privacy: {} (view_angle={})\n", .{interactive_config.full_screen_cover, interactive_config.view_angle});
        },
        6 => { // Ctrl+M: interactive tray menu
            std.debug.print("Tray menu: Interactive controls active.\n", .{});
            std.debug.print("  Use Ctrl+Up/Down for opacity, Ctrl+Left/Right for view angle, Ctrl+S for stripes.\n", .{});
            if (tray_hwnd) |hw| {
                showPopupMenu(hw);
            }
        },
        else => {},
    }
}

fn printHelp(prog_name: []const u8, mode: ?Mode) !void {
    if (mode == null) {
        try stdoutPrint(
            \\Privacy screen overlay
            \\
            \\Usage: {s} <vig|pix> [OPTIONS]
            \\
            \\Commands:
            \\  vig, vignette  Vignette overlay
            \\  pix, pixel     Pixel masking overlay
            \\
            \\Run '{s} <command> --help' for mode-specific options.
            \\
        , .{ prog_name, prog_name });
    } else if (mode.? == .vignette) {
        try stdoutPrint(
            \\Vignette Mode
            \\
            \\Usage: {s} vig [OPTIONS]
            \\
            \\Options:
            \\  -f, --falloff <VALUE>        Fall-off power (default: 4.0)
            \\  -o, --opacity <VALUE>        Edge opacity 0.0-1.0 (default: 0.3)
            \\  -s, --shape <VALUE>          circle|rectangle|diamond|elliptical (default: elliptical)
            \\  -t, --type <VALUE>           power|exponential|gaussian|smootherstep|lens (default: smootherstep)
            \\  -l, --left-bias [VALUE]      Darken left side (default: 0.2)
            \\  -r, --right-bias [VALUE]     Darken right side (default: 0.2)
            \\  -W, --stripe-width <VALUE>   Stripe width in px (default: 0)
            \\  -S, --stripe-opacity <VALUE> Stripe opacity 0.0-1.0 (default: 0.8)
            \\  --radius <VALUE>            Clear area radius factor (default: 1.0)
            \\  -i, --invert                 Invert effect
            \\
        , .{prog_name});
    } else {
        try stdoutPrint(
            \\Pixel Mask Mode
            \\
            \\Usage: {s} pix [OPTIONS]
            \\
            \\Options:
            \\  -p, --pattern <VALUE>        checkerboard|vertical|horizontal|diagonal|mesh|dots (default: checkerboard)
            \\  -s, --size <VALUE>           Pattern size in px (default: 2)
            \\  -o, --opacity <VALUE>        Mask opacity 0.0-1.0 (default: 0.55)
            \\
        , .{prog_name});
    }
}

fn parseArgs(allocator: std.mem.Allocator) !Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config = Config{};

    var i: usize = 1;

    if (i < args.len and (std.mem.eql(u8, args[i], "-h") or std.mem.eql(u8, args[i], "--help"))) {
        try printHelp(args[0], null);
        std.process.exit(0);
    }

    if (i < args.len) {
        const cmd = args[i];
        if (std.mem.eql(u8, cmd, "vig") or std.mem.eql(u8, cmd, "vignette")) {
            config.mode = .vignette;
            i += 1;
            if (i < args.len and (std.mem.eql(u8, args[i], "-h") or std.mem.eql(u8, args[i], "--help"))) {
                try printHelp(args[0], .vignette);
                std.process.exit(0);
            }
        } else if (std.mem.eql(u8, cmd, "pix") or std.mem.eql(u8, cmd, "pixel")) {
            config.mode = .pixel;
            i += 1;
            if (i < args.len and (std.mem.eql(u8, args[i], "-h") or std.mem.eql(u8, args[i], "--help"))) {
                try printHelp(args[0], .pixel);
                std.process.exit(0);
            }
        } else {
            std.debug.print("Error: unknown command: {s}\n", .{cmd});
            try printHelp(args[0], null);
            std.process.exit(1);
        }
    }

    const is_vignette = config.mode == .vignette;
    const is_pixel = config.mode == .pixel;

    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--falloff")) {
            i += 1;
            if (is_pixel) {
                std.debug.print("Error: '{s}' is only valid for vignette mode\n", .{arg});
                std.process.exit(1);
            }
            if (i >= args.len) {
                std.debug.print("Error: --falloff requires a value\n", .{});
                std.process.exit(1);
            }
            config.falloff = std.fmt.parseFloat(f32, args[i]) catch {
                std.debug.print("Error: invalid falloff value: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-s")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: -s requires a value\n", .{});
                std.process.exit(1);
            }
            if (is_vignette) {
                config.shape = std.meta.stringToEnum(Shape, args[i]) orelse {
                    std.debug.print("Error: invalid shape: {s}\n", .{args[i]});
                    std.process.exit(1);
                };
            } else {
                config.mask_size = std.fmt.parseInt(u32, args[i], 10) catch {
                    std.debug.print("Error: invalid size: {s}\n", .{args[i]});
                    std.process.exit(1);
                };
            }
        } else if (std.mem.eql(u8, arg, "--shape")) {
            if (is_pixel) {
                std.debug.print("Error: '--shape' is only valid for vignette mode\n", .{});
                std.process.exit(1);
            }
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --shape requires a value\n", .{});
                std.process.exit(1);
            }
            config.shape = std.meta.stringToEnum(Shape, args[i]) orelse {
                std.debug.print("Error: invalid shape: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--size")) {
            if (is_vignette) {
                std.debug.print("Error: '--size' is only valid for pixel mode\n", .{});
                std.process.exit(1);
            }
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --size requires a value\n", .{});
                std.process.exit(1);
            }
            config.mask_size = std.fmt.parseInt(u32, args[i], 10) catch {
                std.debug.print("Error: invalid size: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--type")) {
            i += 1;
            if (is_pixel) {
                std.debug.print("Error: '{s}' is only valid for vignette mode\n", .{arg});
                std.process.exit(1);
            }
            if (i >= args.len) {
                std.debug.print("Error: --type requires a value\n", .{});
                std.process.exit(1);
            }
            config.falloff_type = std.meta.stringToEnum(FalloffType, args[i]) orelse {
                std.debug.print("Error: invalid falloff type: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--left-bias")) {
            if (i + 1 < args.len and args[i + 1][0] != '-') {
                i += 1;
                config.left_bias = std.fmt.parseFloat(f32, args[i]) catch {
                    std.debug.print("Error: invalid left-bias value: {s}\n", .{args[i]});
                    std.process.exit(1);
                };
            } else {
                config.left_bias = 0.2;
            }
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--right-bias")) {
            if (i + 1 < args.len and args[i + 1][0] != '-') {
                i += 1;
                config.right_bias = std.fmt.parseFloat(f32, args[i]) catch {
                    std.debug.print("Error: invalid right-bias value: {s}\n", .{args[i]});
                    std.process.exit(1);
                };
            } else {
                config.right_bias = 0.2;
            }
        } else if (std.mem.eql(u8, arg, "-W") or std.mem.eql(u8, arg, "--stripe-width")) {
            if (is_pixel) {
                std.debug.print("Error: '{s}' is only valid for vignette mode\n", .{arg});
                std.process.exit(1);
            }
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --stripe-width requires a value\n", .{});
                std.process.exit(1);
            }
            config.stripe_width = std.fmt.parseInt(u32, args[i], 10) catch {
                std.debug.print("Error: invalid stripe-width value: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-S") or std.mem.eql(u8, arg, "--stripe-opacity")) {
            if (is_pixel) {
                std.debug.print("Error: '{s}' is only valid for vignette mode\n", .{arg});
                std.process.exit(1);
            }
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --stripe-opacity requires a value\n", .{});
                std.process.exit(1);
            }
            config.stripe_opacity = std.fmt.parseFloat(f32, args[i]) catch {
                std.debug.print("Error: invalid stripe-opacity value: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--radius")) {
            i += 1;
            if (is_pixel) {
                std.debug.print("Error: '--radius' is only valid for vignette mode\n", .{});
                std.process.exit(1);
            }
            if (i >= args.len) {
                std.debug.print("Error: --radius requires a value\n", .{});
                std.process.exit(1);
            }
            config.radius_factor = std.fmt.parseFloat(f32, args[i]) catch {
                std.debug.print("Error: invalid radius value: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--invert")) {
            config.invert = true;
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--pattern")) {
            if (is_vignette) {
                std.debug.print("Error: '{s}' is only valid for pixel mode\n", .{arg});
                std.process.exit(1);
            }
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --pattern requires a value\n", .{});
                std.process.exit(1);
            }
            config.mask_pattern = std.meta.stringToEnum(MaskPattern, args[i]) orelse {
                std.debug.print("Error: invalid mask pattern: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--opacity")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --opacity requires a value\n", .{});
                std.process.exit(1);
            }
            const val = std.fmt.parseFloat(f32, args[i]) catch {
                std.debug.print("Error: invalid opacity value: {s}\n", .{args[i]});
                std.process.exit(1);
            };
            if (is_vignette) {
                config.max_alpha = val;
            } else {
                config.mask_opacity = val;
            }
        } else {
            std.debug.print("Error: unknown argument: {s}\n", .{arg});
            try printHelp(args[0], null);
            std.process.exit(1);
        }
    }
    return config;
}

