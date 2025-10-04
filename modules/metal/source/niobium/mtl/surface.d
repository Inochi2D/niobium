/**
    Niobium Metal Surface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.surface;
import niobium.mtl.texture;
import niobium.mtl.device;
import niobium.pixelformat;
import niobium.surface;
import niobium.texture;
import niobium.device;
import niobium.types;
import metal.drawable;
import metal.pixelformat;
import foundation;
import coregraphics.cggeometry;
import numem;
import nulib;
import nulib.threading.mutex;

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
    Represents a surface, whether it be a window, a full screen framebuffer,
    or something else.
*/
class NioMTLSurface : NioSurface {
private:
@nogc:
    // State
    uint                                framesInFlight_ = 2;
    NioMTLDevice                        device_;
    NioExtent2D                         size_;
    weak_vector!NioMTLDrawable          activeDrawables_;
    weak_map!(void*, NioMTLDrawable)    drawables_;
    Mutex                               mutex_;

    // Handles
    CAMetalLayer    handle_;
public:

    /**
        The device the surface is attached to.
    */
    override @property NioDevice device() => device_;
    override @property void device(NioDevice value) {
        if (auto device = cast(NioMTLDevice)value) {
            this.device_ = device;
            this.handle_.device = device.handle;
        }
    }

    /**
        Size of the surface.
    */
    override @property NioExtent2D size() => size_;
    override @property void size(NioExtent2D size) {
        this.size_ = size;
        this.handle_.drawableSize = CGSize(size.width, size.height);
    }

    /**
        Format of the surface.
    */
    override @property NioPixelFormat format() => handle_.pixelFormat.toNioPixelFormat();
    override @property void format(NioPixelFormat value) {
        if (this.supports(value))
            this.handle_.pixelFormat = value.toMTLPixelFormat();
    }

    /**
        The amount of frames that can be in-flight.
    */
    override @property uint framesInFlight() => framesInFlight_;
    override @property void framesInFlight(uint value) {
        import nulib.math : clamp;

        this.framesInFlight_ = clamp(value, 2, 3);
        this.handle_.maximumDrawableCount = framesInFlight_;
    }

    /**
        Presentation mode for the surface
    */
    override @property NioPresentMode presentMode() => handle_.displaySyncEnabled() ? NioPresentMode.vsync : NioPresentMode.immediate;
    override @property void presentMode(NioPresentMode value) {
        handle_.displaySyncEnabled = value == NioPresentMode.vsync;
    }

    /**
        Whether the surface is ready for use.
    */
    override @property bool isReady() => 
        (handle_ !is null) &&
        (device_ !is null) &&
        (size_.width > 0 && size_.height > 0) &&
        (framesInFlight_ >= 2);
    
    ~this() {
        foreach(drawable; activeDrawables_)
            drawable.release();
        nogc_delete(mutex_);
    }

    this(void* layer) {
        this.handle_ = cast(CAMetalLayer)layer;
        this.mutex_ = nogc_new!Mutex();
    }

    /**
        Gets whether the surface supports the given pixel
        format.

        Params:
            format = The pixel format to query.
        
        Returns:
            $(D true) if the surface supports the given format,
            $(D false) otherwise.
    */
    override bool supports(NioPixelFormat format) {
        switch(format.toMTLPixelFormat) with(MTLPixelFormat) {
            case    BGRA8Unorm,
                    BGRA8Unorm_sRGB,
                    RGBA16Float,
                    RGB10A2Unorm,
                    BGR10A2Unorm,
                    BGRA10_XR,
                    BGRA10_XR_sRGB,
                    BGR10_XR,
                    BGR10_XR_sRGB:  return true;
            default:                return false;
        }
    }

    /**
        Acquires the next drawable from the surface.

        Returns:
            $(D NioDrawable) representing the next available
            drawable surface, or $(D null).
    */
    override NioDrawable next() {
        if (!isReady)
            return null;

        mutex_.lock();
        scope(exit) mutex_.unlock();
        if (auto mtldrawable = handle_.next()) {
            if (cast(void*)mtldrawable in drawables_) {
                return drawables_[cast(void*)mtldrawable];
            }

            activeDrawables_ ~= nogc_new!NioMTLDrawable(this, mtldrawable);
            drawables_[cast(void*)mtldrawable] = activeDrawables_[$-1];
            return drawables_[cast(void*)mtldrawable];
        }
        return null;
    }
}

/**
    A lightweight strongly typed object referring to textures
    obtained from a surface's internal swapchain.
*/
class NioMTLDrawable : NioDrawable {
private:
@nogc:
    CAMetalDrawable handle_;
    NioMTLTexture texture_;

public:

    /**
        Underlying metal handle.
    */
    final @property CAMetalDrawable handle() => handle_;

    /// Destructor
    ~this() {
        texture_.release();
        handle_.release();
    }

    /**
        Creates a new drawable.
    */
    this(NioMTLSurface surface, CAMetalDrawable drawable) {
        super(surface);
        this.handle_ = drawable;
        this.texture_ = nogc_new!NioMTLTexture(surface.device, drawable.texture);
    }

    /**
        The texture view of this drawable.
    */
    override @property NioTexture texture() => texture_;
}

version(Darwin)
export extern(C) NioSurface nio_surface_create_for_mtl_layer(void* layer) @nogc {
    return nogc_new!NioMTLSurface(layer);
}