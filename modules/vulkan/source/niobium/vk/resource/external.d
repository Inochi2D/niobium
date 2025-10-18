/**
    Niobium Vulkan External Resources
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.resource.external;
import niobium.vk.device;
import niobium.resource;
import vulkan.core;
import vulkan.khr.external_memory_win32;
import vulkan.khr.external_memory_fd;
import vulkan.khr.external_memory;
import numem;

version(Windows) enum NIO_VK_SHARED_HANDLE_TYPE = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT;
else version(linux) enum NIO_VK_SHARED_HANDLE_TYPE = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;
else enum NIO_VK_SHARED_HANDLE_TYPE = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT;

/**
    A handle to a shared resource, abstracting away the low level
    details of shared resources.
*/
class NioVkSharedResourceHandle : NioSharedResourceHandle {
private:
@nogc:
    VkDeviceMemory deviceMemory_;
    void* handle_;

public:

    /**
        Underlying Vulkan Device Memory.
    */
    final @property VkDeviceMemory deviceMemory() => deviceMemory_; 

    /**
        The backend-specific handle for the foreign texture.
    */
    override @property void* handle() => handle_;

    /**
        Constructs a new shared texture handle object.

        Params:
            device =        The device that "owns" this object.
            deviceMemory =  The device memory for the texture.
    */
    this(NioDevice device, VkDeviceMemory deviceMemory) {
        super(device);

        this.deviceMemory_ = deviceMemory;
        auto nvkDevice = cast(NioVkDevice)device;

        // Get the handle for the device memory.
        version(Windows) {

            auto vkGetMemoryWin32HandleKHR = cast(PFN_vkGetMemoryWin32HandleKHR)vkGetDeviceProcAddr(nvkDevice.handle, "vkGetMemoryWin32HandleKHR");
            auto handleInfo = VkMemoryGetWin32HandleInfoKHR(
                memory: deviceMemory,
                handleType: NIO_VK_SHARED_HANDLE_TYPE
            );
            vkGetMemoryWin32HandleKHR(nvkDevice.handle, &handleInfo, &handle_);
        } else version(linux) {

            auto vkGetMemoryFdKHR = cast(PFN_vkGetMemoryFdKHR)vkGetDeviceProcAddr(nvkDevice.handle, "vkGetMemoryFdKHR");
            auto handleInfo = VkMemoryGetFdInfoKHR(
                memory: deviceMemory,
                handleType: NIO_VK_SHARED_HANDLE_TYPE
            );
            vkGetMemoryFdKHR(nvkDevice.handle, &handleInfo, cast(int*)&handle_);
        } else {

            auto vkGetMemoryFdKHR = cast(PFN_vkGetMemoryFdKHR)vkGetDeviceProcAddr(nvkDevice.handle, "vkGetMemoryFdKHR");
            auto handleInfo = VkMemoryGetFdInfoKHR(
                memory: deviceMemory,
                handleType: NIO_VK_SHARED_HANDLE_TYPE
            );
            vkGetMemoryFdKHR(nvkDevice.handle, &handleInfo, cast(int*)&handle_);
        }
    }

    /**
        Constructs a new shared texture handle object.

        Params:
            device =        The device that "owns" this object.
            nativeHandle =  The native handle of the texture.
    */
    this(NioDevice device, void* nativeHandle) {
        super(device);

        this.handle_ = nativeHandle;
        auto nvkDevice = cast(NioVkDevice)device;

        // "Allocate" new memory objects for the given native handle.
        version(Windows) {

            auto importInfo = VkImportMemoryWin32HandleInfoKHR(
                handleType: NIO_VK_SHARED_HANDLE_TYPE,
                handle: nativeHandle,
            );
            auto allocInfo = VkMemoryAllocateInfo(pNext: &importInfo);
            vkAllocateMemory(nvkDevice.handle, &allocInfo, null, deviceMemory_);
        } else version(linux) {

            auto importInfo = VkImportMemoryFdInfoKHR(
                handleType: NIO_VK_SHARED_HANDLE_TYPE,
                fd: cast(int)*cast(ptrdiff_t*)&nativeHandle,
            );
            auto allocInfo = VkMemoryAllocateInfo(pNext: &importInfo);
            vkAllocateMemory(nvkDevice.handle, &allocInfo, null, deviceMemory_);
        } else {

            auto importInfo = VkImportMemoryFdInfoKHR(
                handleType: NIO_VK_SHARED_HANDLE_TYPE,
                fd: cast(int)*cast(ptrdiff_t*)&nativeHandle,
            );
            auto allocInfo = VkMemoryAllocateInfo(pNext: &importInfo);
            vkAllocateMemory(nvkDevice.handle, &allocInfo, null, deviceMemory_);
        }
    }
}

/**
    Creates a new shared resource handle from a system handle.

    Params:
        device =    The device which will be importing the handle.
        handle =    The underlying system handle to create a shared 
                    resource handle for.
*/
export extern(C) NioSharedResourceHandle nio_shared_resource_handle_create(NioDevice device, void* handle) @nogc {
    return nogc_new!NioVkSharedResourceHandle(cast(NioVkDevice)device, handle);
}