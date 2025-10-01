/**
    Niobium Device Interface
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.device;
import niobium.vk.queue;
import niobium.vk.heap;
import niobium.resource;
import niobium.texture;
import niobium.device;
import niobium.buffer;
import niobium.queue;
import niobium.heap;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;
import niobium.vk.texture;
import niobium.vk.buffer;

/**
    A device which is capable of doing 3D rendering and/or
    GPGPU computations.
*/
class NioVkDevice : NioDevice {
private:
@nogc:
    // Device related data
    string deviceName_;
    NioDeviceType deviceType_;
    VkPhysicalDeviceLimits deviceLimits_;
    NioDeviceFeatures deviceFeatures_;

    // Memory related data
    VkPhysicalDeviceMemoryProperties memoryProps_;

    // Queue related data
    NioVkCommandQueue[] mainQueues;
    NioVkVideoEncodeQueue encodeQueue;
    NioVkVideoDecodeQueue decodeQueue;

    // Handles
    VkPhysicalDevice phandle_;
    VkDevice handle_;

    // Memory
    NioAllocator allocator_;

    void createDevice(NioVkQueueTable queueTable) {
        import nulib.math : min;
        import vulkan.khr.swapchain : VK_KHR_SWAPCHAIN_EXTENSION_NAME;

        // Fetch temporaries.
        auto deviceExtensions = phandle_.getDeviceExtensions();
        auto tmpQueuePriorities = nu_malloca!float(32);
        tmpQueuePriorities[0..$] = 1.0f;

        // Build queues.
        vector!VkDeviceQueueCreateInfo queueCreateInfos;
        queueCreateInfos ~= VkDeviceQueueCreateInfo(
            flags: queueTable.mainQueueFamily.flags,
            queueFamilyIndex: cast(uint)queueTable.mainQueueFamily.queueFamilyIndex,
            queueCount: queueTable.mainQueueFamily.queueCount,
            pQueuePriorities: tmpQueuePriorities.ptr
        );

        // Video encode queues.
        if (queueTable.videoEncodeQueueFamily.queueCount > 0) {
            queueCreateInfos ~= VkDeviceQueueCreateInfo(
                flags: queueTable.videoEncodeQueueFamily.flags,
                queueFamilyIndex: cast(uint)queueTable.videoEncodeQueueFamily.queueFamilyIndex,
                queueCount: queueTable.videoEncodeQueueFamily.queueCount,
                pQueuePriorities: tmpQueuePriorities.ptr
            );
            deviceFeatures_.videoEncode = true;
        }

        // Video decode queues.
        if (queueTable.videoDecodeQueueFamily.queueCount > 0) {
            queueCreateInfos ~= VkDeviceQueueCreateInfo(
                flags: queueTable.videoDecodeQueueFamily.flags,
                queueFamilyIndex: cast(uint)queueTable.videoDecodeQueueFamily.queueFamilyIndex,
                queueCount: queueTable.videoDecodeQueueFamily.queueCount,
                pQueuePriorities: tmpQueuePriorities.ptr
            );
            deviceFeatures_.videoDecode = true;
        }

        // Build features
        VkPhysicalDeviceMaintenance4Features mt4 = VkPhysicalDeviceMaintenance4Features();
        VkPhysicalDeviceVulkan13Features vk13 = VkPhysicalDeviceVulkan13Features(pNext: &mt4);
        VkPhysicalDeviceVulkan12Features vk12 = VkPhysicalDeviceVulkan12Features(pNext: &vk13);
        VkPhysicalDeviceVulkan11Features vk11 = VkPhysicalDeviceVulkan11Features(pNext: &vk12);
        VkPhysicalDeviceFeatures2 vkf =         VkPhysicalDeviceFeatures2(pNext: &vk11);
        vkGetPhysicalDeviceFeatures2(phandle_, &vkf);

        // Check features & extensions
        this.deviceFeatures_.dualSourceBlend = cast(bool)vkf.features.dualSrcBlend;
        this.deviceFeatures_.geometryShaders = cast(bool)vkf.features.geometryShader;
        this.deviceFeatures_.tesselationShaders = cast(bool)vkf.features.tessellationShader;
        this.deviceFeatures_.presentation = deviceExtensions.hasExtension("VK_KHR_swapchain");
        this.deviceFeatures_.meshShaders  = deviceExtensions.hasExtension("VK_EXT_mesh_shader");

        // Create Device
        auto createInfo = VkDeviceCreateInfo(
            pNext: &vkf,
            queueCreateInfoCount: cast(uint)queueCreateInfos.length,
            pQueueCreateInfos: queueCreateInfos.ptr,
            enabledExtensionCount: cast(uint)deviceExtensions.length,
            ppEnabledExtensionNames: deviceExtensions.ptr
        );
        vkEnforce(vkCreateDevice(phandle_, &createInfo, null, &handle_));
        nu_freea(tmpQueuePriorities);
        
        // Free the pointers we allocated.
        foreach(ext; deviceExtensions)
            nu_free(cast(void*)ext);
        nu_freea(deviceExtensions);

        // Create queues
        this.createQueues(queueTable);
    }

    void createQueues(NioVkQueueTable queueTable) {
        VkQueue queue_;

        this.mainQueues = nu_malloca!NioVkCommandQueue(queueTable.mainQueueFamily.queueCount);
        foreach(i; 0..queueTable.mainQueueFamily.queueCount) {
            vkGetDeviceQueue(handle_, cast(uint)queueTable.mainQueueFamily.queueFamilyIndex, cast(uint)i, &queue_);
            this.mainQueues[i] = nogc_new!NioVkCommandQueue(this, queue_);
        }

        if (queueTable.videoEncodeQueueFamily.queueCount > 0) {
            vkGetDeviceQueue(handle_, cast(uint)queueTable.videoEncodeQueueFamily.queueFamilyIndex, 0, &queue_);
            this.encodeQueue = nogc_new!NioVkVideoEncodeQueue(this, queue_);
        }

        if (queueTable.videoDecodeQueueFamily.queueCount > 0) {
            vkGetDeviceQueue(handle_, cast(uint)queueTable.videoDecodeQueueFamily.queueFamilyIndex, 0, &queue_);
            this.decodeQueue = nogc_new!NioVkVideoDecodeQueue(this, queue_);
        }
    }

public:

    /**
        Low level handle for the device.
    */
    final @property VkDevice vkDevice() => handle_;

    /**
        Low level handle for the physical device.
    */
    final @property VkPhysicalDevice vkPhysicalDevice() => phandle_;

    /**
        Name of the device.
    */
    override @property string name() => deviceName_;

    /**
        Features list for the device.
    */
    override @property NioDeviceFeatures features() => deviceFeatures_;

    /**
        Type of the device.
    */
    override @property NioDeviceType type() => deviceType_;

    /**
        Vulkan Memory Properties.
    */
    final @property VkPhysicalDeviceMemoryProperties vkMemoryProperties() => memoryProps_;

    /**
        The device-owned memory allocator.
    */
    final @property NioAllocator allocator() => allocator_;

    /**
        The amount of command queues that you can 
        fetch from the device.
    */
    override @property uint queueCount() => cast(uint)mainQueues.length;

    /**
        The video encode queue for the device, $(D null) if video
        encoding is not supported.
    */
    override @property NioVideoEncodeQueue videoEncodeQueue() => encodeQueue;

    /**
        The video decode queue for the device, $(D null) if video
        decoding is not supported.
    */
    override @property NioVideoDecodeQueue videoDecodeQueue() => decodeQueue;

    /// Destructor
    ~this() {
        
        // Free queues
        nu_freea(mainQueues);
        if (encodeQueue)
            nogc_delete(encodeQueue);
        
        if (decodeQueue)
            nogc_delete(decodeQueue);
        
        // Free containers and handles.
        nu_freea(deviceName_);
        nogc_delete(allocator_);
        vkDestroyDevice(handle_, null);
    }

    /**
        Creates a Vulkan Device from its physical device handle.
    */
    this(VkPhysicalDevice physicalDevice, NioVkQueueTable queueTable) {
        this.phandle_ = physicalDevice;

        VkPhysicalDeviceProperties pdProps;
        vkGetPhysicalDeviceProperties(physicalDevice, &pdProps);

        this.deviceLimits_ = pdProps.limits;
        this.deviceType_ = pdProps.deviceType.toNioDeviceType();
        this.deviceName_ = nstring(pdProps.deviceName.ptr).take();
        this.createDevice(queueTable);

        this.allocator_ = nogc_new!NioPoolAllocator(phandle_, handle_, NioPoolAllocatorDescriptor(
            size: 134_217_728, 
        ));
    }

    /**
        Gets a command queue from the device..

        Params:
            index = The index of the queue to get.
        
        Returns:
            A $(D NioCommandQueue) or $(D null) on failure.
    */
    override NioCommandQueue getCommandQueue(uint index) {
        return index < mainQueues.length ? 
            mainQueues[index] : 
            null;
    }

    /**
        Creates a new heap.

        Params:
            desc = Descriptor for the heap.
        
        Returns:
            A new $(D NioHeap) or $(D null) on failure.
    */
    override NioHeap createHeap(NioHeapDescriptor desc) {
        return nogc_new!NioVkHeap(this, desc);
    }

    /**
        Creates a new texture.

        The texture is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    override NioTexture createTexture(NioTextureDescriptor desc) {
        return nogc_new!NioVkTexture(this, desc);
    }

    /**
        Creates a new texture which reinterprets the data of another
        texture.

        Params:
            texture =   Texture to create a view of.
            desc =      Descriptor for the texture.
        
        Returns:
            A new $(D NioTexture) or $(D null) on failure.
    */
    override NioTexture createTextureView(NioTexture texture, NioTextureDescriptor desc) {
        return nogc_new!NioVkTexture(this, texture, desc);
    }

    /**
        Creates a new buffer.

        The buffer is created on the internal device heap, managed
        by Niobium itself.

        Params:
            desc = Descriptor for the buffer.
        
        Returns:
            A new $(D NioBuffer) or $(D null) on failure.
    */
    override NioBuffer createBuffer(NioBufferDescriptor desc) {
        return nogc_new!NioVkBuffer(this, desc);
    }

    /// Stringification override
    override string toString() => name; // @suppress(dscanner.suspicious.object_const)
}

pragma(inline, true)
NioDeviceType toNioDeviceType(VkPhysicalDeviceType type) @nogc {
    switch(type) {
        default:                                        return NioDeviceType.unknown;
        case VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU:    return NioDeviceType.iGPU;
        case VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU:      return NioDeviceType.dGPU;
        case VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU:       return NioDeviceType.vGPU;
        case VK_PHYSICAL_DEVICE_TYPE_CPU:               return NioDeviceType.cpu;
    }
}

/**
    Sets the debug name for an object.
*/
void setDebugName(VkDevice device, VkObjectType objectType, void* handle, string tag) @nogc {
    if (__nio_vk_debug_utils.vkSetDebugUtilsObjectNameEXT) {
        auto createInfo = VkDebugUtilsObjectNameInfoEXT(
            objectType: objectType,
            objectHandle: cast(ulong)handle,
            pObjectName: nstring(tag).take.ptr
        );
    
        __nio_vk_debug_utils.vkSetDebugUtilsObjectNameEXT(device, &createInfo);
        nu_free(cast(void*)createInfo.pObjectName);
    }
}

/**
    Global Vulkan Instance.
*/
package(niobium.vk)
extern(C) __gshared VkInstance __nio_vk_instance;

//
//          IMPLEMENTATION DETAILS
//
private:

/// Gets device extensions.
const(char)*[] getDeviceExtensions(VkPhysicalDevice device) @nogc nothrow {
    uint pCount;
    vkEnumerateDeviceExtensionProperties(device, null, &pCount, null);

    VkExtensionProperties[] props = nu_malloca!VkExtensionProperties(pCount);
    const(char)*[] names = nu_malloca!(const(char)*)(pCount);
    vkEnumerateDeviceExtensionProperties(device, null, &pCount, props.ptr);
    foreach(i, prop; props) {
        if (prop.extensionName[$-1] != '\0')
            names[i] = nstring(prop.extensionName[0..$]).take().ptr;
        else
            names[i] = nstring(prop.extensionName.ptr).take().ptr;
    }
    nu_freea(props);
    return names;
}

/// Gets whether an extension list has a given extension.
bool hasExtension(const(char)*[] list, string ext) @nogc {
    foreach(item; list) {
        if (item.fromStringz() == ext)
            return true;
    }
    return false;
}


//
//          DEVICE ITERATION IMPLEMENTATION DETAILS
//

__gshared extern(C) NioDevice[] __nio_vk_devices;

/// Gets the devices available.
export extern(C) @property NioDevice[] __nio_enumerate_devices() @nogc {
    return __nio_vk_devices;
}

/// Gets all physical devices.
VkPhysicalDevice[] getPhysicalDevices() @nogc {
    uint deviceCount;
    vkEnumeratePhysicalDevices(__nio_vk_instance, &deviceCount, null);

    VkPhysicalDevice[] devices = nu_malloca!VkPhysicalDevice(deviceCount);
    vkEnumeratePhysicalDevices(__nio_vk_instance, &deviceCount, devices.ptr);
    return devices;
}

/// Enumerates devices in the system
void enumerateVulkanDevices() @nogc {
    auto physicalDevices = getPhysicalDevices();

    vector!NioDevice devices;
    foreach(i, physicalDevice; physicalDevices) {
        auto queueTable = physicalDevice.fetchQueues();
        if (physicalDevice.isSupported(queueTable))
            devices ~= nogc_new!NioVkDevice(physicalDevice, queueTable);
    }
    __nio_vk_devices = devices.take();
    nu_freea(physicalDevices);
}

bool isSupported(VkPhysicalDevice device, NioVkQueueTable queueTable) @nogc {
    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(device, &props);

    // API too low, skip.
    if (props.apiVersion < VK_API_VERSION_1_3)
        return false;

    // No graphics-transfer queues?
    if (queueTable.mainQueueFamily.queueCount == 0)
        return false;

    VkPhysicalDeviceVulkan13Features vk13 = VkPhysicalDeviceVulkan13Features();
    VkPhysicalDeviceVulkan12Features vk12 = VkPhysicalDeviceVulkan12Features(pNext: &vk13);
    VkPhysicalDeviceVulkan11Features vk11 = VkPhysicalDeviceVulkan11Features(pNext: &vk12);
    VkPhysicalDeviceFeatures2 vkf =         VkPhysicalDeviceFeatures2(pNext: &vk11);
    vkGetPhysicalDeviceFeatures2(device, &vkf);

    VkBool32 required = 
        vk13.synchronization2 & vk13.dynamicRendering & vk13.maintenance4 &
        vkf.features.samplerAnisotropy & vkf.features.depthClamp & 
        vkf.features.logicOp & vkf.features.independentBlend &
        vkf.features.shaderClipDistance & vkf.features.sampleRateShading &
        vkf.features.imageCubeArray & vkf.features.drawIndirectFirstInstance;
    return cast(bool)required;
}



//
//          QUEUE ITERATION IMPLEMENTATION DETAILS
//
struct NioVkQueueTable {
    NioVkQueueInfo mainQueueFamily;
    NioVkQueueInfo videoEncodeQueueFamily;
    NioVkQueueInfo videoDecodeQueueFamily;
}
struct NioVkQueueInfo {
    ptrdiff_t queueFamilyIndex = -1;
    uint queueCount = 0;
    VkQueueFlags flags = 0;
}

/// Fetches a table of queues that should be used.
NioVkQueueTable fetchQueues(VkPhysicalDevice device) @nogc {
    NioVkQueueTable table;
    VkQueueFamilyProperties[] props = device.getQueueProperties();

    uint maxQueueFlagCount = 0;
    foreach(i, ref VkQueueFamilyProperties prop; props) {
        uint flagCount = 0;

        if ((prop.queueFlags & VK_QUEUE_GRAPHICS_BIT) && (prop.queueFlags & VK_QUEUE_TRANSFER_BIT)) {
            foreach(j; 0..32)
                flagCount += ((prop.queueFlags >> j) & 0x01);

            if (flagCount > maxQueueFlagCount) {
                table.mainQueueFamily = NioVkQueueInfo(
                    queueFamilyIndex: i, 
                    queueCount: prop.queueCount, 
                    flags: prop.queueFlags
                );
                maxQueueFlagCount = flagCount;
            }
        }

        if (prop.queueFlags & VK_QUEUE_VIDEO_ENCODE_BIT_KHR) {
            table.videoEncodeQueueFamily = NioVkQueueInfo(
                queueFamilyIndex: i, 
                queueCount: 1, 
                flags: prop.queueFlags
            );
        }

        if (prop.queueFlags & VK_QUEUE_VIDEO_DECODE_BIT_KHR) {
            table.videoDecodeQueueFamily = NioVkQueueInfo(
                queueFamilyIndex: i, 
                queueCount: 1, 
                flags: prop.queueFlags
            );
        }
    }

    nu_freea(props);
    return table;
}

/// Gets all of the queues for a device.
VkQueueFamilyProperties[] getQueueProperties(VkPhysicalDevice device) @nogc {
    uint propCount;
    vkGetPhysicalDeviceQueueFamilyProperties(device, &propCount, null);

    VkQueueFamilyProperties[] props = nu_malloca!VkQueueFamilyProperties(propCount);
    vkGetPhysicalDeviceQueueFamilyProperties(device, &propCount, props.ptr);
    return props;
}



//
//          INSTANCE IMPLEMENTATION DETAILS
//

pragma(crt_constructor)
export extern(C) void __nio_crt_init() @nogc {
    auto extensions =   getInstanceExtensions();
    auto appInfo = VkApplicationInfo(
        apiVersion: VK_API_VERSION_1_3
    );

    auto createInfo = VkInstanceCreateInfo(
        pApplicationInfo: &appInfo,
        enabledExtensionCount: cast(uint)extensions.length,
        ppEnabledExtensionNames: extensions.ptr,
    );

    vkEnforce(vkCreateInstance(&createInfo, null, __nio_vk_instance));
    nu_freea(extensions);

    __nio_vk_instance.loadProcs(__nio_vk_debug_utils);
    enumerateVulkanDevices();
}

pragma(crt_destructor)
export extern(C) void __nio_crt_fini() @nogc {
    foreach(device; __nio_vk_devices) {
        device.release();
    }
    nu_freea(__nio_vk_devices);
    vkDestroyInstance(__nio_vk_instance, null);
}

/// Gets instance extensions.
const(char)*[] getInstanceExtensions() @nogc nothrow {
    uint pCount;
    vkEnumerateInstanceExtensionProperties(null, &pCount, null);

    VkExtensionProperties[] props = nu_malloca!VkExtensionProperties(pCount);
    const(char)*[] names = nu_malloca!(const(char)*)(pCount);
    vkEnumerateInstanceExtensionProperties(null, &pCount, props.ptr);
    foreach(i, prop; props) {
        if (prop.extensionName[$-1] != '\0')
            names[i] = nstring(prop.extensionName[0..$]).take().ptr;
        else
            names[i] = nstring(prop.extensionName.ptr).take().ptr;
    }
    nu_freea(props);
    return names;
}


//
//              DEBUG TAGS IMPLEMENTATION DETAILS
//
VK_EXT_debug_utils __nio_vk_debug_utils;

struct VkDebugUtilsObjectNameInfoEXT {
    VkStructureType    sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT;
    const(void)*       pNext;
    VkObjectType       objectType;
    ulong              objectHandle;
    const(char)*       pObjectName;
} 

struct VK_EXT_debug_utils {
extern(System) @nogc nothrow:

    @VkProcName("vkSetDebugUtilsObjectNameEXT")
    VkResult function(VkDevice, const(VkDebugUtilsObjectNameInfoEXT)*) vkSetDebugUtilsObjectNameEXT;
}