/**
    Niobium Surface Interface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.surface;
import niobium.device;
import numem;

/**
    Represents a surface, whether it be a window, a full screen framebuffer,
    or something else.
*/
abstract
class NioSurface : NuRefCounted {
public:
@nogc:
    
    /**
        Creates a Niobium Surface from a Win32 window.
        
        Params:
            hinstance = The HINSTANCE handle of the executable.
            hwnd =      The HWND handle of the window.
    */
    version(Windows)
    static NioSurface createForWindow(void* hinstance, void* hwnd) {
        return nio_surface_create_for_win32_window(hinstance, hwnd);
    }
    
    /**
        Creates a Niobium Surface from a Wayland window.
        
        Params:
            display = The wayland display to create the surface for.
            surface = The wayland surface (window) to create the surface for.
    */
    version(linux)
    static NioSurface createForWindow(void* display, void* surface) @nogc {
        return nio_surface_create_for_wl_window(display, surface);
    }

    /**
        Creates a Niobium Surface from an X11 window.
        
        Params:
            display =   The X11 Display to create the surface for.
            window =    The X11 window to create the surface for.
    */
    version(linux)
    static NioSurface createForWindow(void* display, uint window) @nogc {
        return nio_surface_create_for_x11_window(display, window);
    }

    /**
        Creates a Niobium Surface from a Metal Drawable.
        
        Params:
            drawable = The MTLDrawable to create the surface for.
    */
    version(Darwin)
    static NioSurface createForDrawable(void* drawable) @nogc {
        return nio_surface_create_for_mtl_drawable(drawable);
    }

    /**
        The native underlying handle of the object.
    */
    abstract @property void* handle();
}

//
//          IMPLEMENTATION DETAILS
//
private extern(C):

version(Windows)
extern extern(C) NioSurface nio_surface_create_for_win32_window(void* hinstance, void* hwnd) @nogc;

version(linux)
extern extern(C) NioSurface nio_surface_create_for_wl_window(void* display, void* surface) @nogc;

version(linux)
extern extern(C) NioSurface nio_surface_create_for_x11_window(void* display, uint window) @nogc;

version(Darwin)
extern extern(C) NioSurface nio_surface_create_for_mtl_drawable(void* drawable) @nogc;
