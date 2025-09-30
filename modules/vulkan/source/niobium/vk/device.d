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
import niobium.vk.heap;
import niobium.device;
import niobium.resource;
import niobium.texture;
import niobium.buffer;
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
    const(char)*[] deviceExtensions_;

    // Memory related data
    VkPhysicalDeviceMemoryProperties memoryProps_;

    // Queue related data
    VkDeviceQueueCreateInfo[] queueCreateInfos_;
    VkQueue[] vkQueues_;

    // Handles
    VkPhysicalDevice phandle_;
    VkDevice handle_;

    // Memory
    NioAllocator allocator_;

    void createDevice() {
        import nulib.math : min;
        import vulkan.khr.swapchain : VK_KHR_SWAPCHAIN_EXTENSION_NAME;

        // Query queues for various types.
        VkQueueFamilyProperties[] queues = phandle_.getQueueProperties();
        ptrdiff_t[7] activeQueueProperties_;
        foreach(i; 0..activeQueueProperties_.length) {
            activeQueueProperties_[i] = queues.getFirstQueueFor(1U << i);
        }

        float[] tmpQueuePriorities = nu_malloca!float(32);
        tmpQueuePriorities[0..$] = 1.0f;

        // Build queue create info.
        vector!VkDeviceQueueCreateInfo qcis;
        outer: foreach(queueProp; activeQueueProperties_) {
            if (queueProp < 0)
                continue;
            
            // If queue was already added, increase the queue count.
            foreach(ref qci; qcis[]) {
                if (qci.queueFamilyIndex == queueProp) {
                    qci.queueCount = min(qci.queueCount+1, queues[queueProp].queueCount);
                    qci.pQueuePriorities = tmpQueuePriorities.ptr;
                    continue outer;
                }
            }

            qcis ~= VkDeviceQueueCreateInfo(
                queueFamilyIndex: cast(uint)queueProp,
                queueCount: 1,
                pQueuePriorities: tmpQueuePriorities.ptr
            );
        }
        queueCreateInfos_ = qcis.take();

        // Build Extensions
        vector!(const(char)*) extensions;
        extensions ~= nstring(VK_KHR_SWAPCHAIN_EXTENSION_NAME).take.ptr;
        deviceExtensions_ = extensions.take();

        // Build features
        VkPhysicalDeviceVulkan13Features vk13 = VkPhysicalDeviceVulkan13Features();
        VkPhysicalDeviceVulkan12Features vk12 = VkPhysicalDeviceVulkan12Features(pNext: &vk13);
        VkPhysicalDeviceVulkan11Features vk11 = VkPhysicalDeviceVulkan11Features(pNext: &vk12);
        VkPhysicalDeviceFeatures2 vkf =         VkPhysicalDeviceFeatures2(pNext: &vk11);
        vkGetPhysicalDeviceFeatures2(phandle_, &vkf);

        // Create Device
        auto createInfo = VkDeviceCreateInfo(
            pNext: &vkf,
            queueCreateInfoCount: cast(uint)queueCreateInfos_.length,
            pQueueCreateInfos: queueCreateInfos_.ptr,
            enabledExtensionCount: cast(uint)deviceExtensions_.length,
            ppEnabledExtensionNames: deviceExtensions_.ptr
        );
        vkEnforce(vkCreateDevice(phandle_, &createInfo, null, &handle_));
        nu_freea(tmpQueuePriorities);
    }

    void createQueues() {
        size_t qidx = 0;
        foreach(family; queueCreateInfos_) {

            // Add queues for family.
            vkQueues_ = vkQueues_.nu_resize(vkQueues_.length+family.queueCount);
            foreach(queue; 0..family.queueCount) {
                vkGetDeviceQueue(handle_, family.queueFamilyIndex, queue, &vkQueues_[qidx]);
                qidx++;
            }
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

    /// Destructor
    ~this() {
        
        // Free the pointers we allocated.
        foreach(ext; deviceExtensions_)
            nu_free(cast(void*)ext);
        
        // Free containers and handles.
        nu_freea(queueCreateInfos_);
        nu_freea(deviceExtensions_);
        nu_freea(vkQueues_);
        nu_freea(deviceName_);
        nogc_delete(allocator_);
        vkDestroyDevice(handle_, null);
    }

    /**
        Creates a Vulkan Device from its physical device handle.
    */
    this(VkPhysicalDevice physicalDevice) {
        this.phandle_ = physicalDevice;

        VkPhysicalDeviceProperties pdProps;
        vkGetPhysicalDeviceProperties(physicalDevice, &pdProps);

        this.deviceLimits_ = pdProps.limits;
        this.deviceType_ = pdProps.deviceType.toNioDeviceType();
        this.deviceName_ = nstring(pdProps.deviceName.ptr).take();
        this.createDevice();
        this.createQueues();

        this.allocator_ = nogc_new!NioPoolAllocator(phandle_, handle_, NioPoolAllocatorDescriptor(
            size: 134_217_728, 
        ));
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




//
//          DEVICE ITERATION IMPLEMENTATION DETAILS
//

__gshared extern(C) NioDevice[] __nio_vk_devices;

/// Gets the devices available.
export extern(C) @property NioDevice[] __nio_enumerate_devices() @nogc {
    return __nio_vk_devices;
}

/// Enumerates devices in the system
void enumerateVulkanDevices() @nogc {
    auto physicalDevices = getPhysicalDevices();
    vector!NioDevice devices;
    foreach(i, physicalDevice; physicalDevices) {
        if (physicalDevice.isSupported())
            devices ~= nogc_new!NioVkDevice(physicalDevice);
    }
    __nio_vk_devices = devices.take();
    nu_freea(physicalDevices);
}

/// Gets all physical devices.
VkPhysicalDevice[] getPhysicalDevices() @nogc {
    uint deviceCount;
    vkEnumeratePhysicalDevices(__nio_vk_instance, &deviceCount, null);

    VkPhysicalDevice[] devices = nu_malloca!VkPhysicalDevice(deviceCount);
    vkEnumeratePhysicalDevices(__nio_vk_instance, &deviceCount, devices.ptr);
    return devices;
}

bool isSupported(VkPhysicalDevice device) @nogc {
    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(device, &props);

    // API too low, skip.
    if (props.apiVersion < VK_API_VERSION_1_3)
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

/// Gets all of the extensions.
VkExtensionProperties[] getExtensionProperties(VkPhysicalDevice device) @nogc {
    uint propCount;
    vkEnumerateDeviceExtensionProperties(device, null, &propCount, null);

    VkExtensionProperties[] props = nu_malloca!VkExtensionProperties(propCount);
    vkEnumerateDeviceExtensionProperties(device, null, &propCount, props.ptr);
    return props;
}

/// Gets whether the list has a given extension.
bool hasExtension(ref VkExtensionProperties[] extensions, string extension) {
    if (extension.length > VK_MAX_EXTENSION_NAME_SIZE)
        return false;
    
    foreach(ref VkExtensionProperties ext; extensions) {
        if (ext.extensionName[0..extension.length] == extension)
            return true;
    }
    return false;
}




//
//          QUEUE ITERATION IMPLEMENTATION DETAILS
//

/// Gets all of the queues for a device.
VkQueueFamilyProperties[] getQueueProperties(VkPhysicalDevice device) @nogc {
    uint propCount;
    vkGetPhysicalDeviceQueueFamilyProperties(device, &propCount, null);

    VkQueueFamilyProperties[] props = nu_malloca!VkQueueFamilyProperties(propCount);
    vkGetPhysicalDeviceQueueFamilyProperties(device, &propCount, props.ptr);
    return props;
}

/// Gets the first queue that supports a specific flag.
ptrdiff_t getFirstQueueFor(VkQueueFamilyProperties[] props, VkQueueFlags flags) @nogc {
    foreach(i, prop; props) {
        if (prop.queueFlags & flags)
            return i;
    }
    return -1;
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

/// Gets whether an extension list has a given extension.
bool hasInstanceExtension(const(char)*[] list, string ext) {
    foreach(item; list) {
        if (item.fromStringz() == ext)
            return true;
    }
    return false;
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