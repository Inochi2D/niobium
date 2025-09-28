/**
    Niobium Surface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.surface;
import niobium.vk.device;
import niobium.surface;
import vulkan.khr.surface;
import vulkan.khr.win32_surface;
import vulkan.khr.wayland_surface;
import vulkan.khr.xlib_surface;
import vulkan.khr.swapchain;
import vulkan.loader;
import vulkan.eh;
import numem;

/**
    Represents a surface, whether it be a window, a full screen framebuffer,
    or something else.
*/
class NioVkSurface : NioSurface {
private:
@nogc:
    VkSurfaceKHR handle_;

public:
    
    /**
        The native underlying handle of the object.
    */
    override @property VkSurfaceKHR handle() => handle_;
    
    /// Destructor
    ~this() {
        VK_KHR_surface procs = __nio_surface_procs.get().procs;
        procs.vkDestroySurfaceKHR(__nio_vk_instance, handle_, null);
    }

    /**
        Creates a Niobium Surface from a handle.
        
        Params:
            hinstance = The HINSTANCE handle of the executable.
            hwnd =      The HWND handle of the window.
    */
    version(Windows)
    this(void* hinstance, void* hwnd) {
        VK_KHR_win32_surface procs = __nio_surface_procs.get().win32;

        auto createInfo = VkWin32SurfaceCreateInfoKHR(
            hinstance: hinstance,
            hwnd: hwnd
        );
        vkEnforce(procs.vkCreateWin32SurfaceKHR(__nio_vk_instance, &createInfo, null, &handle_));
    }

    /**
        Creates a Niobium Surface from a Wayland window.
        
        Params:
            display = The wayland display to create the surface for.
            surface = The wayland surface (window) to create the surface for.
    */
    version(linux)
    this(void* display, void* surface) {
        VK_KHR_wayland_surface procs = __nio_surface_procs.get().wayland;

        auto createInfo = VkWaylandSurfaceCreateInfoKHR(
            display: cast(wl_display*)display,
            surface: cast(wl_surface*)surface
        );
        vkEnforce(procs.vkCreateWaylandSurfaceKHR(__nio_vk_instance, &createInfo, null, &handle_));
    }

    /**
        Creates a Niobium Surface from an X11 window.
        
        Params:
            display =   The X11 Display to create the surface for.
            window =    The X11 window to create the surface for.
    */
    version(linux)
    this(void* display, uint window) {
        VK_KHR_xlib_surface procs = __nio_surface_procs.get().xlib;
        if (procs.vkCreateXlibSurfaceKHR) {
            auto createInfo = VkXlibSurfaceCreateInfoKHR(
                display: cast(Display*)display,
                window: window
            );
            vkEnforce(procs.vkCreateXlibSurfaceKHR(__nio_vk_instance, &createInfo, null, &handle_));
        }
    }
}

/**
    Creates a Niobium Surface from a Win32 window.
    
    Params:
        hinstance = The HINSTANCE handle of the executable.
        hwnd =      The HWND handle of the window.
*/
version(Windows)
export extern(C) NioSurface nio_surface_create_for_win32_window(void* hinstance, void* hwnd) @nogc {
    return nogc_new!NioVkSurface(hinstance, hwnd);
}

/**
    Creates a Niobium Surface from a Wayland window.
    
    Params:
        display = The wayland display to create the surface for.
        surface = The wayland surface (window) to create the surface for.
*/
version(linux)
export extern(C) static NioSurface nio_surface_create_for_wl_window(void* display, void* surface) @nogc {
    return nogc_new!NioVkSurface(display, surface);
}

/**
    Creates a Niobium Surface from an X11 window.
    
    Params:
        display =   The X11 Display to create the surface for.
        window =    The X11 window to create the surface for.
*/
version(linux)
export extern(C) static NioSurface nio_surface_create_for_x11_window(void* display, uint window) @nogc {
    return nogc_new!NioVkSurface(display, window);
}

/**
    Creates a Niobium Surface from a Metal Drawable.
    
    Params:
        drawable = The MTLDrawable to create the surface for.
*/
version(Darwin)
export extern(C) static NioSurface nio_surface_create_for_mtl_drawable(void* drawable) @nogc {
    return null;
}

//
//          IMPLEMENTATION DETAILS
//
private:
extern(C) __gshared NioSurfaceProcs __nio_surface_procs;

struct NioSurfaceProcs {
@nogc:
    VK_KHR_surface procs;
    version(Windows) VK_KHR_win32_surface win32;
    else version(linux) {
        VK_KHR_wayland_surface wayland;
        VK_KHR_xlib_surface xlib;
    }

    auto ref NioSurfaceProcs get() {
        if (!procs.vkDestroySurfaceKHR) {
            __nio_vk_instance.loadProcs!VK_KHR_surface(__nio_surface_procs.procs);
            version(Windows) {
                __nio_vk_instance.loadProcs!VK_KHR_win32_surface(__nio_surface_procs.win32);
            } else version(linux) {
                __nio_vk_instance.loadProcs!VK_KHR_wayland_surface(__nio_surface_procs.wayland);
                __nio_vk_instance.loadProcs!VK_KHR_xlib_surface(__nio_surface_procs.xlib);
            }
        }
        return __nio_surface_procs;
    }
}