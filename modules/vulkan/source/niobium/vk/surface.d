/**
    Niobium Vulkan Surface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.surface;
import niobium.vk.resource;
import niobium.vk.device;
import niobium.surface;
import vulkan.khr.surface;
import vulkan.khr.win32_surface;
import vulkan.khr.wayland_surface;
import vulkan.khr.xlib_surface;
import vulkan.khr.swapchain;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;


public import niobium.surface;

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
    VkSurfaceCapabilitiesKHR surfaceCaps;

    // Handles
    NioVkDevice device_;
    VkSurfaceKHR handle_;
    VkSwapchainKHR swapchain_;
    VkSurfaceFormatKHR[] supportedFormats_;

    // Swapchain
    bool needsRebuild = true;
    VK_KHR_swapchain swapFuncs;

    // Drawables
    uint imageCount_;
    uint currentImageIdx_;
    NioVkDrawable[] drawables_;

    // Sync
    VkFence fence_;

    void rebuild() {
        bool isReady_ = 
            needsRebuild &
            (device_ !is null) & 
            (format_ != NioPixelFormat.unknown) &
            (size_.width * size.height != 0) &
            (framesInFlight_ != 0);
        
        if (!isReady_)
            return;

        import std.stdio : writeln;

        swapCreateInfo.oldSwapchain = swapchain_;
        auto result = swapFuncs.vkCreateSwapchainKHR(device_.vkDevice, &swapCreateInfo, null, &swapchain_);
        if (result == VK_SUCCESS) {

            // Recreate drawables.
            this.createDrawables(this.getSwapchainImages(), drawables_);
            this.currentImageIdx_ = 0;
            this.needsRebuild = false;
            return;
        }
    }

    /// Gets swapchain images.
    VkImage[] getSwapchainImages() {
        uint pCount;
        swapFuncs.vkGetSwapchainImagesKHR(device_.vkDevice, swapchain_, &pCount, null);
        VkImage[] images = nu_malloca!VkImage(pCount);

        swapFuncs.vkGetSwapchainImagesKHR(device_.vkDevice, swapchain_, &pCount, images.ptr);
        return images;
    }

    /// (Re-)creates the drawables.
    void createDrawables(VkImage[] images, ref NioVkDrawable[] drawables) {
        if (drawables_.length > 0)
            this.destroyDrawables();

        // Resize arrays.
        drawables = nu_malloca!NioVkDrawable(images.length);
        this.imageCount_ = cast(uint)images.length;

        auto fenceCreateInfo = VkFenceCreateInfo();
        vkCreateFence(device_.vkDevice, &fenceCreateInfo, null, &fence_);

        // Create new drawables.
        foreach(i; 0..images.length) {
            drawables[i] = nogc_new!NioVkDrawable(this, images[i], cast(uint)i);
        }
        nu_freea(images);
    }

    /// Destroys the drawables.
    void destroyDrawables() {

        // Delete old objects.
        nogc_delete(drawables_[0..$]);
        nu_freea(drawables_);
    }

    void setup() {
        this.swapCreateInfo = VkSwapchainCreateInfoKHR(
            surface: handle_,
            clipped: false,
            imageArrayLayers: 1,
            imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
            compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            preTransform: VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
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
        if (auto nvkDevice = cast(NioVkDevice)value) {
            if (!(nvkDevice.vkDevice && nvkDevice.vkPhysicalDevice))
                return;

            nvkDevice.vkDevice.loadProcs!VK_KHR_swapchain(swapFuncs);
            this.device_ = nvkDevice;
            this.needsRebuild = true;

            // Rebuild formats list.
            uint fmtCount;
            __nio_surface_procs.procs.vkGetPhysicalDeviceSurfaceFormatsKHR(nvkDevice.vkPhysicalDevice, handle_, &fmtCount, null);

            supportedFormats_ = supportedFormats_.nu_resize(fmtCount);
            __nio_surface_procs.procs.vkGetPhysicalDeviceSurfaceFormatsKHR(nvkDevice.vkPhysicalDevice, handle_, &fmtCount, supportedFormats_.ptr);

            // Get surface capabilities.
            __nio_surface_procs.procs.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
                device_.vkPhysicalDevice, 
                handle_, 
                &surfaceCaps
            );
        }
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
        import nulib.math : max;

        this.framesInFlight_ = max(surfaceCaps.minImageCount, value);
        swapCreateInfo.minImageCount = framesInFlight_;
        this.needsRebuild = true;
    }

    /**
        Presentation mode for the surface
    */
    override @property NioPresentMode presentMode() => presentMode_;
    override @property void presentMode(NioPresentMode value) {
        this.presentMode_ = value;
        swapCreateInfo.presentMode = value.toVkPresentMode();
        this.needsRebuild = true;
    }

    /**
        Whether the surface is ready for use.
    */
    override @property bool isReady() => !needsRebuild && swapchain_ !is null;
    
    /// Destructor
    ~this() {
        VK_KHR_surface procs = __nio_surface_procs.get().procs;

        this.destroyDrawables();

        if (supportedFormats_)
            nu_freea(supportedFormats_);
        
        if (swapchain_)
            swapFuncs.vkDestroySwapchainKHR(device_.vkDevice, swapchain_, null);
        
        if (handle_)
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
        if (needsRebuild)
            this.rebuild();
        
        if (!isReady)
            return null;

        auto result = swapFuncs.vkAcquireNextImageKHR(device_.vkDevice, swapchain_, 1000, null, fence_, &currentImageIdx_);
        switch(result) {
            case VK_SUBOPTIMAL_KHR:
                this.needsRebuild = true;
                goto case;
            
            case VK_SUCCESS:
                vkWaitForFences(device_.vkDevice, 1, &fence_, VK_TRUE, ulong.max);
                vkResetFences(device_.vkDevice, 1, &fence_);
                return drawables_[currentImageIdx_];

            case VK_ERROR_OUT_OF_DATE_KHR:
                this.needsRebuild = true;
                return this.next();

            default:
                return null;
        }
    }
}

/**
    Converts a $(D NioPresentMode) format to its $(D VkPresentModeKHR) equivalent.

    Params:
        format = The $(D NioPresentMode)
    
    Returns:
        The $(D VkPresentModeKHR) equivalent.
*/
VkPresentModeKHR toVkPresentMode(NioPresentMode mode) @nogc {
    final switch(mode) with (NioPresentMode) {
        case immediate: return VK_PRESENT_MODE_IMMEDIATE_KHR;
        case vsync:     return VK_PRESENT_MODE_FIFO_KHR;
        case mailbox:   return VK_PRESENT_MODE_MAILBOX_KHR;
    }
}

/**
    Vulkan Drawable.
*/
class NioVkDrawable : NioDrawable {
private:
@nogc:
    uint index_;
    NioVkSurface surface_;
    NioVkDrawableTexture texture_;

public:

    /// Helper that resets the drawable, called during submission.
    override void reset() {
        super.reset();
        texture_.layout = VK_IMAGE_LAYOUT_UNDEFINED;
    }

    /**
        The swapchain of the drawable.
    */
    @property VkSwapchainKHR swapchain() => surface_.swapchain_;

    /**
        The swapchain index of the drawable.
    */
    @property uint index() => index_;

    /// Destructor
    ~this() {
        texture_.release();
    }

    /**
        Creates a new Drawable from a Vulkan Image.
    */
    this(NioVkSurface surface, VkImage image, uint index) {
        super(surface);

        this.surface_ = surface;
        this.index_ = index;
        this.texture_ = nogc_new!NioVkDrawableTexture(surface.device, this, image);
    }

    /**
        The texture view of this drawable.
    */
    override @property NioTexture texture() => texture_;
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
    VkImageView view_;

public:

    /**
        Image layout of the drawable texture for state tracking.
    */
    VkImageLayout layout = VK_IMAGE_LAYOUT_UNDEFINED;

    /**
        Storage mode of the texture view.
    */
    override @property NioStorageMode storageMode() => NioStorageMode.privateStorage;

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
    override @property NioTextureType type() => NioTextureType.type2D;
    
    /**
        The usage flags of the texture.
    */
    override @property NioTextureUsage usage() => NioTextureUsage.attachment | NioTextureUsage.sampled;

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

    /// Destructor
    ~this() {
        auto nvkDevice = cast(NioVkDevice)device;
        vkDestroyImageView(nvkDevice.vkDevice, view_, null);
    }

    /**
        Constructs a new drawable texture.
    */
    this(NioDevice device, NioVkDrawable drawable, VkImage image) {
        super(device);

        this.drawable_ = drawable;
        this.image_ = image;
        this.swapCreateInfo_ = (cast(NioVkSurface)drawable.surface).swapCreateInfo;
        this.format_ = drawable.surface.format;

        auto createInfo = VkImageViewCreateInfo(
            image: image,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: swapCreateInfo_.imageFormat,
            components: VkComponentMapping(VK_COMPONENT_SWIZZLE_R, VK_COMPONENT_SWIZZLE_G, VK_COMPONENT_SWIZZLE_B, VK_COMPONENT_SWIZZLE_A),
            subresourceRange: VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS)
        );
        vkEnforce(vkCreateImageView((cast(NioVkDevice)device).vkDevice, &createInfo, null, &view_));
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