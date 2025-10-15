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
    bool transparent_;
    NioPresentMode presentMode_;
    NioPixelFormat format_;
    NioExtent2D size_;
    VkCompositeAlphaFlagsKHR supportedAlphaMode_ = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
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
    uint currentFrame_;
    VkSemaphore[] semaphores_;

    void rebuild() {

        bool isReady_ = 
            needsRebuild &
            (device_ !is null) & 
            (format_ != NioPixelFormat.unknown) &
            (size_.width * size.height != 0) &
            (framesInFlight_ != 0);
        
        if (!isReady_)
            return;

        // Get surface capabilities.
        __nio_surface_procs.procs.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
            device_.vkPhysicalDevice, 
            handle_, 
            &surfaceCaps
        );
        if (surfaceCaps.currentExtent.width != 0xFFFFFFFF) {
            import nulib.math : clamp;

            this.size_.width =  clamp(size_.width, surfaceCaps.minImageExtent.width, surfaceCaps.maxImageExtent.width);
            this.size_.height = clamp(size_.height, surfaceCaps.minImageExtent.height, surfaceCaps.maxImageExtent.height);
            this.swapCreateInfo.imageExtent = VkExtent2D(
                size_.width,
                size_.height,
            );
        }

        // Clear old images, if needed.
        if (swapCreateInfo.oldSwapchain) {
            swapFuncs.vkDestroySwapchainKHR(device_.handle, swapCreateInfo.oldSwapchain, null);
        }

        swapCreateInfo.oldSwapchain = swapchain_;
        auto result = swapFuncs.vkCreateSwapchainKHR(device_.handle, &swapCreateInfo, null, &swapchain_);
        if (result == VK_SUCCESS) {

            // Recreate drawables.
            this.createDrawables(this.getSwapchainImages());
            this.currentImageIdx_ = 0;
            this.needsRebuild = false;
            return;
        }
    }

    /// Gets swapchain images.
    VkImage[] getSwapchainImages() {
        uint pCount;
        swapFuncs.vkGetSwapchainImagesKHR(device_.handle, swapchain_, &pCount, null);
        VkImage[] images = nu_malloca!VkImage(pCount);

        swapFuncs.vkGetSwapchainImagesKHR(device_.handle, swapchain_, &pCount, images.ptr);
        return images;
    }

    /// (Re-)creates the drawables.
    void createDrawables(VkImage[] images) {
        if (drawables_.length > 0)
            this.destroyDrawables();

        // Resize arrays.
        this.imageCount_ = cast(uint)images.length;
        this.drawables_ = nu_malloca!NioVkDrawable(images.length);
        this.semaphores_ = semaphores_.nu_resize(imageCount_);

        auto semaCreateInfo = VkSemaphoreCreateInfo();
        foreach(ref semaphore; semaphores_)
            vkCreateSemaphore(device_.handle, &semaCreateInfo, null, &semaphore);

        // Create new drawables.
        foreach(i; 0..images.length) {
            this.drawables_[i] = nogc_new!NioVkDrawable(this, images[i], cast(uint)i);
        }
        nu_freea(images);
    }

    /// Destroys the drawables.
    void destroyDrawables() {
        foreach(semaphore; semaphores_)
            vkDestroySemaphore(device_.handle, semaphore, null);

        // Delete old objects.
        nu_freea(drawables_);
    }

    void setup() {
        this.swapCreateInfo = VkSwapchainCreateInfoKHR(
            surface: handle_,
            clipped: false,
            imageArrayLayers: 1,
            imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
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
    final @property VkSurfaceKHR handle() => handle_;

    /**
        The device the surface is attached to.
    */
    override @property NioDevice device() => device_;
    override @property void device(NioDevice value) {
        if (auto nvkDevice = cast(NioVkDevice)value) {
            if (!(nvkDevice.handle && nvkDevice.vkPhysicalDevice))
                return;

            nvkDevice.handle.loadProcs!VK_KHR_swapchain(swapFuncs);
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

            // Update supported alpha mode.
            this.supportedAlphaMode_ = 
                (surfaceCaps.supportedCompositeAlpha & VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR) ? VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR :
                (surfaceCaps.supportedCompositeAlpha & VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR) ? VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR :
                VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
            
            // Disable transparency if we can only do opaque composition.
            if (supportedAlphaMode_ == VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR && transparent_)
                transparent_ = false;
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
        Whether to enable transparent composition for the surface.
    */
    override @property bool transparent() => transparent_;
    override @property void transparent(bool value) {
        if (supportedAlphaMode_ != VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR) {
            swapCreateInfo.compositeAlpha = value ? supportedAlphaMode_ : VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
            this.transparent_ = value;
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
        
        if (swapCreateInfo.oldSwapchain)
            swapFuncs.vkDestroySwapchainKHR(device_.handle, swapCreateInfo.oldSwapchain, null);

        if (swapchain_)
            swapFuncs.vkDestroySwapchainKHR(device_.handle, swapchain_, null);
        
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
    version(Posix)
    this(void* display, void* surface) {
        import std.stdio;

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
    version(Posix)
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

        auto result = swapFuncs.vkAcquireNextImageKHR(device_.handle, swapchain_, 1000, semaphores_[currentFrame_], null, &currentImageIdx_);
        switch(result) {

            case VK_SUBOPTIMAL_KHR:
                this.needsRebuild = true;
                goto case;

            case VK_SUCCESS:
                auto drawable = drawables_[currentImageIdx_];
                drawable.semaphore = semaphores_[currentFrame_];
                drawable.reset();

                currentFrame_ = (currentFrame_ + 1) % imageCount_;
                return drawable;

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
        mode = The $(D NioPresentMode)
    
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
    NioVkTexture texture_;

public:

    /**
        The drawable's current semaphore.
    */
    VkSemaphore semaphore;

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

        auto surfaceSize = surface.size;
        this.texture_ = nogc_new!NioVkTexture(surface.device, image, NioTextureDescriptor(
            type: NioTextureType.type2D,
            format: surface.format,
            storage: NioStorageMode.privateStorage,
            usage: NioTextureUsage.transfer | NioTextureUsage.sampled | NioTextureUsage.attachment,
            width: surfaceSize.width,
            height: surfaceSize.height,
            depth: 1,
            levels: 1,
            slices: 1,
        ));
    }

    /**
        The texture view of this drawable.
    */
    override @property NioTexture texture() => texture_;
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
version(Posix)
export extern(C) NioSurface nio_surface_create_for_wl_window(void* display, void* surface) @nogc {
    return nogc_new!NioVkSurface(display, surface);
}

/**
    Creates a Niobium Surface from an X11 window.
    
    Params:
        display =   The X11 Display to create the surface for.
        window =    The X11 window to create the surface for.
*/
version(Posix)
export extern(C) NioSurface nio_surface_create_for_x11_window(void* display, uint window) @nogc {
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