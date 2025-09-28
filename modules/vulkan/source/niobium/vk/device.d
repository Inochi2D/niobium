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
import niobium.device;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;

/**
    A device which is capable of doing 3D rendering and/or
    GPGPU computations.
*/
class NioVkDevice : NioDevice {
private:
@nogc:
    string deviceName_;
    NioDeviceType deviceType_;
    VkPhysicalDeviceLimits deviceLimits_;

    VkPhysicalDevice phandle_;
    VkDevice handle_;

    void createDevice() {

    }

public:

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
    }

    /**
        Name of the device.
    */
    override @property string name() => deviceName_;

    /**
        Type of the device.
    */
    override @property NioDeviceType type() => deviceType_;

    /**
        The native underlying handle of the object.
    */
    override @property VkDevice handle() => handle_;

    /// Stringification override
    override
    string toString() { return name; } // @suppress(dscanner.suspicious.object_const)
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
    Global Vulkan Instance.
*/
package(niobium.vk)
extern(C) __gshared VkInstance __nio_vk_instance;

//
//          IMPLEMENTATION DETAILS
//
private:





//
//          DEVICE ITERATION  IMPLEMENTATIONDETAILS
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
        vkf.features.logicOp & vkf.features.independentBlend;
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