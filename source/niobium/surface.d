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
import niobium.pixelformat;
import niobium.texture;
import niobium.device;
import niobium.queue;
import niobium.types;
import numem;

// Darwin Version Identifier
version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;
else version (VisionOS)
    version = Darwin;

/**
    Presentation modes for a surface.
*/
enum NioPresentMode : uint {

    /**
        Frames are presented as soon as they are able, may result
        in screen tearing.
    */
    immediate,
    
    /**
        Frames are presented from a queue during vertial blanking, 
        if frames in flight fill up the queue the application blocks
        until the queue is free again.
    */
    vsync,

    /**
        Frames are presented in a triple buffered queue, with
        waiting images being overwritten if the queue is full.
    */
    mailbox
}

/**
    Represents a surface, whether it be a window, a full screen framebuffer,
    or something else.

    Note:
        You can only change the settings of the surface *after* you've selected
        a device to render to the surface with.
*/
abstract
class NioSurface : NuRefCounted {
public:
@nogc:

    /**
        The device the surface is attached to.
    */
    abstract @property NioDevice device();
    abstract @property void device(NioDevice);

    /**
        Size of the surface.
    */
    abstract @property NioExtent2D size();
    abstract @property void size(NioExtent2D);

    /**
        Whether to enable transparent composition for the surface.
        
        Note:
            This only applies to platforms where the app controls
            composition mode, some platforms may let you request
            transparent composition elsewhere.
    */
    abstract @property bool transparent();
    abstract @property void transparent(bool);

    /**
        Format of the surface.
    */
    abstract @property NioPixelFormat format();
    abstract @property void format(NioPixelFormat);

    /**
        The amount of frames that can be in-flight.
    */
    abstract @property uint framesInFlight();
    abstract @property void framesInFlight(uint);

    /**
        Presentation mode for the surface
    */
    abstract @property NioPresentMode presentMode();
    abstract @property void presentMode(NioPresentMode);

    /**
        Whether the surface is ready for use.
    */
    abstract @property bool isReady();
    
    /**
        Gets whether the surface supports the given pixel
        format.

        Params:
            format = The pixel format to query.
        
        Returns:
            $(D true) if the surface supports the given format,
            $(D false) otherwise.
    */
    abstract bool supports(NioPixelFormat format);

    /**
        Acquires the next drawable from the surface.

        Returns:
            $(D NioDrawable) representing the next available
            drawable surface, or $(D null).
    */
    abstract NioDrawable next();

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
    version(Posix)
    static NioSurface createForWindow(void* display, void* surface) @nogc {
        return nio_surface_create_for_wl_window(display, surface);
    }

    /**
        Creates a Niobium Surface from an X11 window.
        
        Params:
            display =   The X11 Display to create the surface for.
            window =    The X11 window to create the surface for.
    */
    version(Posix)
    static NioSurface createForWindow(void* display, uint window) @nogc {
        return nio_surface_create_for_x11_window(display, window);
    }

    /**
        Creates a Niobium Surface from a $(D CAMetalLayer).
        
        Params:
            drawable = The $(D CAMetalLayer) to create the surface for.
    */
    version(Darwin)
    static NioSurface createForLayer(void* layer) @nogc {
        return nio_surface_create_for_mtl_layer(layer);
    }
}

/**
    A lightweight strongly typed object referring to textures
    obtained from a surface's internal swapchain.
*/
abstract
class NioDrawable : NuRefCounted {
private:
@nogc:
    NioSurface surface_;
    NioCommandQueue queue_;

protected:

    /**
        Constructs a new drawable.
    */
    this(NioSurface surface) {
        this.surface_ = surface;
    }

    /**
        Resets the state of the drawable, allowing
        it to be reused.
    */
    void reset() {
        this.queue_ = null;
    }

public:

    /**
        The queue which has claimed this drawable by using it.

        Note:
            This can only be set once, and should be set by
            the Niobium implementation for you. It is invalid
            to submit a present to a queue that hasn't claimed
            the drawable.
    */
    final @property NioCommandQueue queue() => queue_;
    final @property void queue(NioCommandQueue value) {
        if (!queue_)
            this.queue_ = value;
    }

    /**
        The surface that this drawable belongs to.
    */
    final @property NioSurface surface() => surface_;

    /**
        The texture view of this drawable.
    */
    abstract @property NioTexture texture();
}

//
//          IMPLEMENTATION DETAILS
//
private extern(C):

version(Windows)
extern extern(C) NioSurface nio_surface_create_for_win32_window(void* hinstance, void* hwnd) @nogc;

version(Posix)
extern extern(C) NioSurface nio_surface_create_for_wl_window(void* display, void* surface) @nogc;

version(Posix)
extern extern(C) NioSurface nio_surface_create_for_x11_window(void* display, uint window) @nogc;

version(Darwin)
extern extern(C) NioSurface nio_surface_create_for_mtl_layer(void* layer) @nogc;
