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
import niobium.vk.texture;
import niobium.vk.device;
import niobium.surface;
import niobium.texture;
import niobium.device;
import niobium.types;
import vulkan.khr.surface;
import vulkan.khr.win32_surface;
import vulkan.khr.wayland_surface;
import vulkan.khr.xlib_surface;
import vulkan.khr.swapchain;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;

/**
    Represents a surface, whether it be a window, a full screen framebuffer,
    or something else.
*/
class NioVkSurface : NioSurface {
private:
@nogc:
    // Settings
    uint framesInFlight_;
    NioPresentMode presentMode_;
    NioPixelFormat format_;
    NioExtent2D size_;
    VkSwapchainCreateInfoKHR swapCreateInfo;

    // Handles
    NioVkDevice device_;
    VkSurfaceKHR handle_;
    VkSwapchainKHR swapchain_;
    VkSurfaceFormatKHR[] supportedFormats_;

    // Swapchain
    bool needsRebuild = true;
    VK_KHR_swapchain swapFuncs;
    uint currentImageIdx_;
    uint imageCount_;
    VkSemaphore vkSwapSemaphore_;
    VkImage[] vkImages_;
    NioDrawable[] drawables_;

    void rebuild() {
        bool isReady_ = 
            needsRebuild &
            (device_ !is null) & 
            (format_ != NioPixelFormat.unknown) &
            (size_.width * size.height != 0) &
            (framesInFlight_ != 0);
        
        if (!isReady_)
            return;

        swapCreateInfo.oldSwapchain = swapchain_;
        if (swapFuncs.vkCreateSwapchainKHR(device_.handle, &swapCreateInfo, null, &swapchain_) == VK_SUCCESS) {

            // Fetch new images for NioDrawables.
            swapFuncs.vkGetSwapchainImagesKHR(device_.handle, swapchain_, &imageCount_, null);
            vkImages_ = vkImages_.nu_resize(imageCount_);
            swapFuncs.vkGetSwapchainImagesKHR(device_.handle, swapchain_, &imageCount_, vkImages_.ptr);

            // Delete old drawables.
            foreach(i; 0..drawables_.length) {
                drawables_[i].release();
                drawables_[i] = null;
            }
            drawables_ = drawables_.nu_resize(imageCount_);
            
            // Create new drawables.
            foreach(i; 0..drawables_.length) {
                drawables_[i] = nogc_new!NioVkDrawable(this, vkImages_[i]);
            }
            this.needsRebuild = false;
            return;
        }
    }

    void setup() {
        swapCreateInfo = VkSwapchainCreateInfoKHR(
            surface: handle_,
            clipped: false,
            imageArrayLayers: 1,
            imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
            compositeAlpha: VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR,
            preTransform: VK_SURFACE_TRANSFORM_INHERIT_BIT_KHR,
        );
    }

    ptrdiff_t findFormat(VkFormat fmt) {
        foreach(i, format; supportedFormats_) {
            if (format.format == fmt)
                return i;
        }
        return -1;
    }

public:

    /**
        Vulkan surface handle
    */
    final @property VkSurfaceKHR vkSurface() => handle_;

    /**
        The device the surface is attached to.
    */
    override @property NioDevice device() => device_;
    override @property void device(NioDevice value) {
        this.device_ = cast(NioVkDevice)value;
        this.device_.handle.loadProcs!VK_KHR_swapchain(swapFuncs);
        this.needsRebuild = true;

        // Rebuild formats list.
        uint fmtCount;
        __nio_surface_procs.procs.vkGetPhysicalDeviceSurfaceFormatsKHR(device_.vkPhysicalDevice, handle_, &fmtCount, null);

        supportedFormats_ = supportedFormats_.nu_resize(fmtCount);
        __nio_surface_procs.procs.vkGetPhysicalDeviceSurfaceFormatsKHR(device_.vkPhysicalDevice, handle_, &fmtCount, supportedFormats_.ptr);
    }

    /**
        Size of the surface.
    */
    override @property NioExtent2D size() => size_;
    override @property void size(NioExtent2D value) {
        swapCreateInfo.imageExtent.width = value.width;
        swapCreateInfo.imageExtent.height = value.height;
        this.size_ = value;
        this.needsRebuild = true;
    }

    /**
        Format of the surface.
    */
    override @property NioPixelFormat format() => format_;
    override @property void format(NioPixelFormat value) {
        auto vkformat = value.toVkFormat();
        auto fmtidx = this.findFormat(vkformat);
        if (fmtidx >= 0) {
            swapCreateInfo.imageFormat = vkformat;
            swapCreateInfo.imageColorSpace = supportedFormats_[fmtidx].colorSpace;
            
            this.format_ = value;
            this.needsRebuild = true;
        }
    }

    /**
        The amount of frames that can be in-flight.
    */
    override @property uint framesInFlight() => framesInFlight_;
    override @property void framesInFlight(uint value) {
        swapCreateInfo.minImageCount = value;
        this.framesInFlight_ = value;
        this.needsRebuild = true;
    }

    /**
        Presentation mode for the surface
    */
    override @property NioPresentMode presentMode() => presentMode_;
    override @property void presentMode(NioPresentMode value) {
        this.presentMode_ = value;
        this.needsRebuild = true;
    }

    /**
        Whether the surface is ready for use.
    */
    override @property bool isReady() => !needsRebuild && swapchain_ !is null;
    
    /// Destructor
    ~this() {
        VK_KHR_surface procs = __nio_surface_procs.get().procs;

        if (drawables_)
            nu_freea(drawables_);

        if (supportedFormats_)
            nu_freea(supportedFormats_);
        
        if (handle_)
            procs.vkDestroySurfaceKHR(__nio_vk_instance, handle_, null);
        
        if (swapchain_)
            swapFuncs.vkDestroySwapchainKHR(device_.handle, swapchain_, null);
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

        if (procs.vkCreateWin32SurfaceKHR) {
            auto createInfo = VkWin32SurfaceCreateInfoKHR(
                hinstance: hinstance,
                hwnd: hwnd
            );
            vkEnforce(procs.vkCreateWin32SurfaceKHR(__nio_vk_instance, &createInfo, null, &handle_));
            this.setup();
        }
    }

    /**
        Creates a Niobium Surface from a Wayland window.
        
        Params:
            display = The wayland display to create the surface for.
            surface = The wayland surface (window) to create the surface for.
    */
    version(posix)
    this(void* display, void* surface) {
        VK_KHR_wayland_surface procs = __nio_surface_procs.get().wayland;

        if (procs.vkCreateWaylandSurfaceKHR) {
            auto createInfo = VkWaylandSurfaceCreateInfoKHR(
                display: cast(wl_display*)display,
                surface: cast(wl_surface*)surface
            );
            vkEnforce(procs.vkCreateWaylandSurfaceKHR(__nio_vk_instance, &createInfo, null, &handle_));
            this.setup();
        }
    }

    /**
        Creates a Niobium Surface from an X11 window.
        
        Params:
            display =   The X11 Display to create the surface for.
            window =    The X11 window to create the surface for.
    */
    version(posix)
    this(void* display, uint window) {
        VK_KHR_xlib_surface procs = __nio_surface_procs.get().xlib;
        if (procs.vkCreateXlibSurfaceKHR) {
            auto createInfo = VkXlibSurfaceCreateInfoKHR(
                display: cast(Display*)display,
                window: window
            );
            vkEnforce(procs.vkCreateXlibSurfaceKHR(__nio_vk_instance, &createInfo, null, &handle_));
            this.setup();
        }
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
        return this.findFormat(format.toVkFormat()) != -1;
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
        
        if (needsRebuild)
            this.rebuild();

        auto result = swapFuncs.vkAcquireNextImageKHR(device_.handle, swapchain_, 1000, vkSwapSemaphore_, null, &currentImageIdx_);
        if (result == VK_ERROR_OUT_OF_DATE_KHR) {
            this.needsRebuild = true;
            return this.next();
        }
        return drawables_[currentImageIdx_];
    }
}

/**
    Vulkan Drawable.
*/
class NioVkDrawable : NioDrawable {
private:
@nogc:
    NioVkSurface surface_;
    NioVkDrawableTexture texture_;
    NioVkDrawableTextureView view_;

public:
    /**
        Semaphore signalled when the drawable is ready
        for use.
    */
    VkSemaphore semaphore;

    /// Destructor
    ~this() {
        auto vkDevice = (cast(NioVkDevice)surface_.device).handle;

        this.view_.release();
        vkDestroySemaphore(vkDevice, semaphore, null);
    }

    /**
        Creates a new Drawable from a Vulkan Image.
    */
    this(NioVkSurface surface, VkImage image) {
        super(surface);

        auto vkDevice = (cast(NioVkDevice)surface_.device).handle;
        
        auto createInfo = VkSemaphoreCreateInfo();
        vkCreateSemaphore(vkDevice, &createInfo, null, &semaphore);

        this.surface_ = surface;
        this.texture_ = nogc_new!NioVkDrawableTexture(surface.device, this, image);
        this.view_ = nogc_new!NioVkDrawableTextureView(surface.device, texture_);
    }

    /**
        The texture view of this drawable.
    */
    override @property NioTextureView texture() => view_;
}

/**
    A drawable texture.
*/
class NioVkDrawableTexture : NioTexture {
private:
@nogc:
    NioPixelFormat format_;
    VkSwapchainCreateInfoKHR swapCreateInfo_;
    NioVkDrawable drawable_;
    VkImage image_;

public:

    /**
        Handle to underlying vulkan image.
    */
    final @property VkImage vkImage() => image_;

    /**
        The pixel format of the texture.
    */
    override @property NioPixelFormat format() => format_;

    /**
        The type of the texture.
    */
    override @property NioTextureType type() => NioTextureType.texture2d;

    /**
        Width of the texture in pixels.
    */
    override @property uint width() => swapCreateInfo_.imageExtent.width;

    /**
        Height of the texture in pixels.
    */
    override @property uint height() => swapCreateInfo_.imageExtent.height;

    /**
        Depth of the texture in pixels.
    */
    override @property uint depth() => 1;

    /**
        Array layer count of the texture.
    */
    override @property uint layers() => 1;

    /**
        Mip level count of the texture.
    */
    override @property uint levels() => 1;

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => 0;

    /**
        Alignment of the resource in bytes.
    */
    override @property uint alignment() => 1;

    /**
        Constructs a new drawable texture.
    */
    this(NioDevice device, NioVkDrawable drawable, VkImage image) {
        super(device);

        this.drawable_ = drawable;
        this.image_ = image;
        this.swapCreateInfo_ = (cast(NioVkSurface)drawable.surface).swapCreateInfo;
        this.format_ = drawable.surface.format;
    }
}

/**
    A drawable texture.
*/
class NioVkDrawableTextureView : NioTextureView {
private:
@nogc:
    VkImageView view_;

public:

    /**
        Handle to underlying vulkan image.
    */
    final @property VkImage vkImage() => (cast(NioVkDrawableTexture)texture).vkImage;

    /**
        Handle to underlying vulkan image view.
    */
    final @property VkImageView vkImageView() => view_;

    /**
        The format this view is interpreting the texture as.
    */
    override @property NioPixelFormat format() => texture.format;

    /**
        The base layer being viewed.
    */
    override @property uint layer() => 0;

    /**
        Array layer count of the texture.
    */
    override @property uint layers() => texture.layers;

    /**
        The base mip level being viewed.
    */
    override @property uint level() => 0;

    /**
        Mip level count of the texture.
    */
    override @property uint levels() => texture.levels;

    /**
        Size of the resource in bytes.
    */
    override @property uint size() => 0;

    /**
        Alignment of the resource in bytes.
    */
    override @property uint alignment() => 1;

    /// Destructor
    ~this() {
        vkDestroyImageView((cast(NioVkDevice)device).handle, view_, null);
    }

    /**
        Creates a new drawable texture view.
    */
    this(NioDevice device, NioVkDrawableTexture texture) {
        super(device, texture);

        auto createInfo = VkImageViewCreateInfo(
            image: vkImage,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: texture.swapCreateInfo_.imageFormat,
            components: VkComponentMapping(VK_COMPONENT_SWIZZLE_R, VK_COMPONENT_SWIZZLE_G, VK_COMPONENT_SWIZZLE_B, VK_COMPONENT_SWIZZLE_A),
            subresourceRange: VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS)
        );
        vkEnforce(vkCreateImageView((cast(NioVkDevice)device).handle, &createInfo, null, &view_));
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
version(posix)
export extern(C) static NioSurface nio_surface_create_for_wl_window(void* display, void* surface) @nogc {
    return nogc_new!NioVkSurface(display, surface);
}

/**
    Creates a Niobium Surface from an X11 window.
    
    Params:
        display =   The X11 Display to create the surface for.
        window =    The X11 window to create the surface for.
*/
version(posix)
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