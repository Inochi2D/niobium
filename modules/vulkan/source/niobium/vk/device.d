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
import niobium.vk.resource;
import niobium.vk.sampler;
import niobium.vk.render;
import niobium.vk.shader;
import niobium.vk.video;
import niobium.vk.heap;
import niobium.vk.sync;
import niobium.vk.cmd;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;
import nulib.math : min;

import niobium.pipeline;

public import niobium.device;
public import niobium.types;

/**
    A device which is capable of doing 3D rendering and/or
    GPGPU computations.
*/
class NioVkDevice : NioDevice {
private:
@nogc:
    // Device related data
    string              deviceName_;
    NioDeviceType       deviceType_;
    NioDeviceFeatures   deviceFeatures_;
    NioDeviceLimits     deviceLimits_;

    // Memory related data
    VkPhysicalDeviceMemoryProperties memoryProps_;

    // Queue related data
    NioVkQueueTable queueTable;
    VkQueue mainQueue;
    VkQueue encodeQueue;
    VkQueue decodeQueue;

    // Handles
    VkPhysicalDevice physicalDevice_;
    VkDevice handle_;

    // Memory
    NioAllocator allocator_;

    // Internal immediate upload queue
    NioCommandQueue uploadQueue;
    NioBuffer stagingBuffer;

    void createDevice(NioVkQueueTable queueTable, const(char)*[] deviceExtensions) {
        this.queueTable = queueTable;

        // Fetch temporaries.
        auto tmpQueuePriorities = nu_malloca!float(32);
        tmpQueuePriorities[0..$] = 1.0f;

        // Build queues.
        vector!VkDeviceQueueCreateInfo queueCreateInfos;
        if (queueTable.mainQueueFamily.queueFamilyIndex >= 0) {
            queueCreateInfos ~= VkDeviceQueueCreateInfo(
                queueFamilyIndex: cast(uint)queueTable.mainQueueFamily.queueFamilyIndex,
                queueCount: 1,
                pQueuePriorities: tmpQueuePriorities.ptr
            );
        }

        // Video encode queues.
        if (queueTable.videoEncodeQueueFamily.queueFamilyIndex >= 0) {
            queueCreateInfos ~= VkDeviceQueueCreateInfo(
                queueFamilyIndex: cast(uint)queueTable.videoEncodeQueueFamily.queueFamilyIndex,
                queueCount: 1,
                pQueuePriorities: tmpQueuePriorities.ptr
            );
            deviceFeatures_.videoEncode = true;
        }

        // Video decode queues.
        if (queueTable.videoDecodeQueueFamily.queueFamilyIndex >= 0) {
            queueCreateInfos ~= VkDeviceQueueCreateInfo(
                queueFamilyIndex: cast(uint)queueTable.videoDecodeQueueFamily.queueFamilyIndex,
                queueCount: 1,
                pQueuePriorities: tmpQueuePriorities.ptr
            );
            deviceFeatures_.videoDecode = true;
        }

        // Get memory properties.
        VkPhysicalDeviceMemoryProperties memoryProperties;
        vkGetPhysicalDeviceMemoryProperties(physicalDevice_, &memoryProperties);

        // Build Properties.
        VkPhysicalDeviceExtendedDynamicState3PropertiesEXT dyn3p = VkPhysicalDeviceExtendedDynamicState3PropertiesEXT();
        VkPhysicalDeviceVulkan13Properties vk13p = VkPhysicalDeviceVulkan13Properties(pNext: &dyn3p);
        VkPhysicalDeviceVulkan12Properties vk12p = VkPhysicalDeviceVulkan12Properties(pNext: &vk13p);
        VkPhysicalDeviceVulkan11Properties vk11p = VkPhysicalDeviceVulkan11Properties(pNext: &vk12p);
        VkPhysicalDeviceProperties2 vkp = VkPhysicalDeviceProperties2(pNext: &vk11p);
        vkGetPhysicalDeviceProperties2(physicalDevice_, &vkp);
        
        // Device Info
        this.deviceType_ = vkp.properties.deviceType.toNioDeviceType();
        this.deviceName_ = nstring(vkp.properties.deviceName.ptr).take();

        // Build features
        VkPhysicalDeviceExtendedDynamicState3FeaturesEXT dyn3 = VkPhysicalDeviceExtendedDynamicState3FeaturesEXT();
        VkPhysicalDeviceVulkan13Features vk13 = VkPhysicalDeviceVulkan13Features(pNext: &dyn3);
        VkPhysicalDeviceVulkan12Features vk12 = VkPhysicalDeviceVulkan12Features(pNext: &vk13);
        VkPhysicalDeviceVulkan11Features vk11 = VkPhysicalDeviceVulkan11Features(pNext: &vk12);
        VkPhysicalDeviceFeatures2 vkf =         VkPhysicalDeviceFeatures2(pNext: &vk11);
        vkGetPhysicalDeviceFeatures2(physicalDevice_, &vkf);

        // Check features & extensions
        this.deviceFeatures_.dualSourceBlend = cast(bool)vkf.features.dualSrcBlend;
        this.deviceFeatures_.geometryShaders = cast(bool)vkf.features.geometryShader;
        this.deviceFeatures_.tesselationShaders = cast(bool)vkf.features.tessellationShader;
        this.deviceFeatures_.anisotropicFiltering = cast(bool)vkf.features.samplerAnisotropy;
        this.deviceFeatures_.alphaToCoverage = cast(bool)vkf.features.alphaToOne;
        this.deviceFeatures_.presentation = deviceExtensions.hasExtension("VK_KHR_swapchain");
        this.deviceFeatures_.meshShaders  = deviceExtensions.hasExtension("VK_EXT_mesh_shader");

        // Check device limits.
        this.deviceLimits_.maxBufferSize = vk13p.maxBufferSize;
        foreach_reverse(i; 0..7) {
            if ((vkp.properties.limits.sampledImageColorSampleCounts >> i) & 0x01) {
                this.deviceLimits_.maxSamples = 1 << i;
                break;
            }
        }
        foreach(i; 0..memoryProperties.memoryHeapCount) {
            auto prop = memoryProperties.memoryHeaps[i];
            if (prop.flags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) {
                this.deviceLimits_.totalMemory += prop.size;
            }
        }

        // Build extensions list.
        vector!(const(char)*) extensions;
        extensions ~= nstring("VK_EXT_extended_dynamic_state3").take().ptr;
        if (deviceFeatures_.presentation)
            extensions ~= nstring("VK_KHR_swapchain").take().ptr;
        if (deviceFeatures_.meshShaders)
            extensions ~= nstring("VK_EXT_mesh_shader").take().ptr;

        // Create Device
        auto createInfo = VkDeviceCreateInfo(
            pNext: &vkf,
            queueCreateInfoCount: cast(uint)queueCreateInfos.length,
            pQueueCreateInfos: queueCreateInfos.ptr,
            enabledExtensionCount: cast(uint)extensions.length,
            ppEnabledExtensionNames: extensions.ptr
        );
        vkEnforce(vkCreateDevice(physicalDevice_, &createInfo, null, &handle_));
        nu_freea(tmpQueuePriorities);
        
        // Free the pointers we allocated.
        foreach(ext; deviceExtensions) nu_free(cast(void*)ext);
        foreach(ext; extensions) nu_free(cast(void*)ext);
        nu_freea(deviceExtensions);
        extensions.clear();

        // Create queues
        this.createQueues(queueTable);

        // Internal upload queue.
        this.uploadQueue = this.createQueue(NioCommandQueueDescriptor(maxCommandBuffers: 1));
    }

    void createQueues(NioVkQueueTable queueTable) {
        this.mainQueue = queueTable.mainQueueFamily.queueFamilyIndex >= 0 ? 
            this.getQueue(cast(uint)queueTable.mainQueueFamily.queueFamilyIndex, 0) :
            null;

        this.encodeQueue = queueTable.videoEncodeQueueFamily.queueFamilyIndex >= 0 ? 
            this.getQueue(cast(uint)queueTable.videoEncodeQueueFamily.queueFamilyIndex, 0) :
            null;
        
        this.decodeQueue = queueTable.videoDecodeQueueFamily.queueFamilyIndex >= 0 ? 
            this.getQueue(cast(uint)queueTable.videoDecodeQueueFamily.queueFamilyIndex, 0) :
            null;
    }

    VkQueue getQueue(uint queueFamily, uint index) {
        VkQueue queue_;
        vkGetDeviceQueue(handle_, queueFamily, index, &queue_);
        return queue_;
    }

    /// Updates the staging buffer to fit a new size if it's greater
    /// than its current size.
    void updateStagingBuffer(uint size) {
        if (!stagingBuffer || size > stagingBuffer.size) {
            if (stagingBuffer) {
                stagingBuffer.release();
                stagingBuffer = null;
            }

            stagingBuffer = this.createBuffer(NioBufferDescriptor(
                usage: NioBufferUsage.transfer,
                storage: NioStorageMode.sharedStorage,
                size: size
            ));
        }
    }

public:

    /**
        Low level handle for the device.
    */
    final @property VkDevice handle() => handle_;

    /**
        Low level handle for the physical device.
    */
    final @property VkPhysicalDevice vkPhysicalDevice() => physicalDevice_;

    /**
        Name of the device.
    */
    override @property string name() => deviceName_;

    /**
        Features supported by the device.
    */
    override @property NioDeviceFeatures features() => deviceFeatures_;

    /**
        Limits of the device.
    */
    override @property NioDeviceLimits limits() => deviceLimits_;

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
        if (stagingBuffer)
            stagingBuffer.release();
        
        uploadQueue.release();

        // Free containers and handles.
        nu_freea(deviceName_);
        nogc_delete(allocator_);
        vkDestroyDevice(handle_, null);
    }

    /**
        Creates a Vulkan Device from its physical device handle.
    */
    this(VkPhysicalDevice physicalDevice, NioVkQueueTable queueTable, const(char)*[] extensions) {
        this.physicalDevice_ = physicalDevice;

        this.createDevice(queueTable, extensions);
        this.allocator_ = nogc_new!NioPoolAllocator(physicalDevice_, handle_, NioPoolAllocatorDescriptor(
            size: 134_217_728, 
        ));
    }

    /**
        Creates a new video encode queue from the device.

        Queues created this way may only be used by a single thread
        at a time.
        
        Returns:
            A $(D NioVideoEncodeQueue) or $(D null) on failure.
    */
    override NioVideoEncodeQueue createVideoEncodeQueue() {
        return encodeQueue ?
            nogc_new!NioVkVideoEncodeQueue(this, encodeQueue) :
            null;
    }

    /**
        Creates a new video decode queue from the device.

        Queues created this way may only be used by a single thread
        at a time.
        
        Returns:
            A $(D NioVideoDecodeQueue) or $(D null) on failure.
    */
    override NioVideoDecodeQueue createVideoDecodeQueue() {
        return decodeQueue ?
            nogc_new!NioVkVideoDecodeQueue(this, decodeQueue) :
            null;
    }

    /**
        Creates a new command queue from the device submitting to
        the given logical device queue.

        Queues created this way may only be used by a single thread
        at a time.

        Params:
            index = The index of the queue to get.
        
        Returns:
            A $(D NioCommandQueue) or $(D null) on failure.
    */
    override NioCommandQueue createQueue(NioCommandQueueDescriptor desc) {
        return nogc_new!NioVkCommandQueue(this, desc, mainQueue, cast(uint)queueTable.mainQueueFamily.queueFamilyIndex);
    }

    /**
        Creates a new fence.
        
        Returns:
            A new $(D NioFence) or $(D null) on failure.
    */
    override NioFence createFence() {
        return nogc_new!NioVkFence(this);
    }

    /**
        Creates a new semaphore.
        
        Returns:
            A new $(D NioFence) or $(D null) on failure.
    */
    override NioSemaphore createSemaphore() {
        return nogc_new!NioVkSemaphore(this);
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

    /**
        Creates a new shader from a library.

        Params:
            library = The NIR Library.
        
        Returns:
            A new $(D NioShader) on success,
            $(D null) otherwise.
    */
    override NioShader createShader(NirLibrary library) {
        return nogc_new!NioVkShader(this, library);
    }

    /**
        Creates a new render pipeline object.

        Params:
            desc = Descriptor for the pipeline.
        
        Returns:
            A new $(D NioRenderPipeline) on success,
            $(D null) otherwise.
    */
    override NioRenderPipeline createRenderPipeline(NioRenderPipelineDescriptor desc) {
        return nogc_new!NioVkRenderPipeline(this, desc);
    }

    /**
        Creates a new sampler.

        Params:
            desc = Descriptor for the sampler.
        
        Returns:
            A new $(D NioSampler) on success,
            $(D null) otherwise.
    */
    override NioSampler createSampler(NioSamplerDescriptor desc) {
        return nogc_new!NioVkSampler(this, desc);
    }
    
    /**
        Uploads data to the texture using a device-internal
        transfer queue.

        Params:
            texture =   Target texture
            region =    The region of the texture to upload to.
            level =     The mipmap level of the texture to upload to.
            slice =     The array slice of the texture to upload to, for non-array textures, set to 0.
            data =      The data to upload.
            rowStride = The stride of a single row of pixels.
    */
    void uploadDataToTexture(NioTexture texture, NioRegion3D region, uint level, uint slice, void[] data, uint rowStride) {
        this.updateStagingBuffer(texture.size);

        stagingBuffer.upload(data, 0);
        if (auto cmdbuffer = uploadQueue.fetch()) {
            auto transferPass = cmdbuffer.beginTransferPass();
                transferPass.copy(
                    NioBufferSrcInfo(
                        buffer: stagingBuffer, 
                        offset: 0, 
                        rowLength: rowStride,
                        extent: region.extent
                    ), 
                    NioTextureDstInfo(
                        texture: texture,
                        slice: slice,
                        level: level,
                        origin: region.origin
                    )
                );
            transferPass.endEncoding();

            uploadQueue.commit(cmdbuffer);
            cmdbuffer.await();
            cmdbuffer.release();
        }
    }
    
    /**
        Downloads data from the texture using a device-internal
        transfer queue.

        Params:
            texture =   Source texture
            region =    The region of the texture to upload to.
            level =     The mipmap level of the texture to upload to.
            slice =     The array slice of the texture to upload to, for non-array textures, set to 0.
            rowStride = The stride of a single row of pixels.
    
        Returns:
            A nogc slice of the data from the texture,
            or $(D null) on failure.
    */
    void[] downloadDataFromTexture(NioTexture texture, NioRegion3D region, uint level, uint slice, uint rowStride) {
        void[] result;
        this.updateStagingBuffer(texture.size);

        if (auto cmdbuffer = uploadQueue.fetch()) {
            auto transferPass = cmdbuffer.beginTransferPass();
                transferPass.copy(
                    NioTextureSrcInfo(
                        texture: texture,
                        slice: slice,
                        level: level,
                        origin: region.origin,
                        extent: region.extent
                    ), 
                    NioBufferDstInfo(
                        buffer: stagingBuffer,
                        offset: 0,
                        rowLength: rowStride
                    )
                );
            transferPass.endEncoding();

            uploadQueue.commit(cmdbuffer);
            cmdbuffer.await();
            cmdbuffer.release();

            result = nu_malloc(texture.size)[0..texture.size];
            result[0..$] = stagingBuffer.map()[0..result.length];
        }

        return result;
    }
    
    /**
        Uploads data to the buffer using a device-internal
        transfer queue.

        Params:
            buffer =    Target buffer
            offset =    Offset into buffer to write to
            data =      The data to write.
    */
    void uploadDataToBuffer(NioBuffer buffer, size_t offset, void[] data) {
        this.updateStagingBuffer(buffer.size);

        stagingBuffer.upload(data, 0);
        if (auto cmdbuffer = uploadQueue.fetch()) {
            auto transferPass = cmdbuffer.beginTransferPass();
                transferPass.copy(
                    NioBufferSrcInfo(
                        buffer: stagingBuffer, 
                        offset: 0,
                        length: cast(uint)data.length
                    ), 
                    NioBufferDstInfo(
                        buffer: buffer,
                        offset: offset,
                    )
                );
            transferPass.endEncoding();

            uploadQueue.commit(cmdbuffer);
            cmdbuffer.await();
            cmdbuffer.release();
        }
    }
    
    /**
        Uploads data to the texture using a device-internal
        transfer queue.

        Params:
            buffer =    Source buffer
            offset =    Offset into the buffer to download.
            length =    Length of the data to download, in bytes.
    
        Returns:
            A nogc slice of the data from the buffer,
            or $(D null) on failure.
    */
    void[] downloadDataFromBuffer(NioBuffer buffer, size_t offset, size_t length) {
        void[] result;
        this.updateStagingBuffer(buffer.size);

        if (auto cmdbuffer = uploadQueue.fetch()) {
            auto transferPass = cmdbuffer.beginTransferPass();
                transferPass.copy(
                    NioBufferSrcInfo(
                        buffer: buffer,
                        offset: offset,
                        length: length
                    ), 
                    NioBufferDstInfo(
                        buffer: stagingBuffer,
                        offset: 0,
                    )
                );
            transferPass.endEncoding();

            uploadQueue.commit(cmdbuffer);
            cmdbuffer.await();
            cmdbuffer.release();

            result = nu_malloc(buffer.size)[0..buffer.size];
            result[0..$] = stagingBuffer.map()[0..result.length];
        }

        return result;
    }

    /// Stringification override
    override string toString() => name; // @suppress(dscanner.suspicious.object_const)
}

/**
    Converts a $(D VkPhysicalDeviceType) bitmask to its $(D NioDeviceType) equivalent.

    Params:
        usage = The $(D VkPhysicalDeviceType)
    
    Returns:
        The $(D NioDeviceType) equivalent.
*/
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
    Pushes a debug group to a command buffer.
*/
void pushDebugGroup(VkCommandBuffer buffer, string label, float[4] color) @nogc {
    if (__nio_vk_debug_utils.vkCmdBeginDebugUtilsLabelEXT) {
        auto createInfo = VkDebugUtilsLabelEXT(
            pLabelName: nstring(label).take.ptr,
            color: color
        );
    
        __nio_vk_debug_utils.vkCmdBeginDebugUtilsLabelEXT(buffer, &createInfo);
        nu_free(cast(void*)createInfo.pLabelName);
    }
}

/**
    Pops a debug group from a command buffer.
*/
void popDebugGroup(VkCommandBuffer buffer) @nogc {
    if (__nio_vk_debug_utils.vkCmdEndDebugUtilsLabelEXT) {
        __nio_vk_debug_utils.vkCmdEndDebugUtilsLabelEXT(buffer);
    }
}

struct VK_EXT_extended_dynamic_state3 {
extern(System) @nogc nothrow:
    
    @VkProcName("vkCmdSetDepthClampEnableEXT")
    void function(VkCommandBuffer, VkBool32) vkCmdSetDepthClampEnableEXT;
    
    @VkProcName("vkCmdSetPolygonModeEXT")
    void function(VkCommandBuffer, VkPolygonMode) vkCmdSetPolygonModeEXT;
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
const(char)*[] fetchDeviceExtensions(VkPhysicalDevice device) @nogc nothrow {
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

__gshared extern(C) bool __nio_vk_has_enumerated;
__gshared extern(C) NioDevice[] __nio_vk_devices;

/// Gets the devices available.
export extern(C) @property NioDevice[] __nio_enumerate_devices() @nogc {
    if (!__nio_vk_has_enumerated) {
        auto physicalDevices = getPhysicalDevices();
        __nio_vk_has_enumerated = true;
        vector!NioDevice devices;

        foreach(i, physicalDevice; physicalDevices) {
            auto queueTable = physicalDevice.fetchQueues();
            auto extensions = physicalDevice.fetchDeviceExtensions();
            if (physicalDevice.isSupported(queueTable, extensions))
                devices ~= nogc_new!NioVkDevice(physicalDevice, queueTable, extensions);
        }
        __nio_vk_devices = devices.take();

        nu_freea(physicalDevices);
    }
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

bool isSupported(VkPhysicalDevice device, NioVkQueueTable queueTable, const(char)*[] extensions) @nogc {
    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(device, &props);

    // API too low, skip.
    if (props.apiVersion < VK_API_VERSION_1_3)
        return false;

    // No graphics-transfer queues?
    if (queueTable.mainQueueFamily.queueFamilyIndex == -1)
        return false;
    
    // VK_EXT_extended_dynamic_state3 is required for Metal parity. 
    if (!extensions.hasExtension("VK_EXT_extended_dynamic_state3"))
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
    VkQueueFlags flags;
}

/// Fetches a table of queues that should be used.
NioVkQueueTable fetchQueues(VkPhysicalDevice device) @nogc {
    NioVkQueueTable table;
    VkQueueFamilyProperties[] props = device.getQueueProperties();

    uint maxQueueFlagCount = 0;
    foreach(i, VkQueueFamilyProperties prop; props) {
        uint flagCount = 0;

        if ((prop.queueFlags & VK_QUEUE_GRAPHICS_BIT) && (prop.queueFlags & VK_QUEUE_TRANSFER_BIT)) {
            foreach(j; 0..32)
                flagCount += ((prop.queueFlags >> j) & 0x01);

            if (flagCount > maxQueueFlagCount) {
                table.mainQueueFamily = NioVkQueueInfo(
                    queueFamilyIndex: i, 
                    flags: prop.queueFlags
                );
                maxQueueFlagCount = flagCount;
            }
        }

        if (prop.queueFlags & VK_QUEUE_VIDEO_ENCODE_BIT_KHR) {
            table.videoEncodeQueueFamily = NioVkQueueInfo(
                queueFamilyIndex: i, 
                flags: prop.queueFlags
            );
        }

        if (prop.queueFlags & VK_QUEUE_VIDEO_DECODE_BIT_KHR) {
            table.videoDecodeQueueFamily = NioVkQueueInfo(
                queueFamilyIndex: i, 
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
    auto extensions = getInstanceExtensions();
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

struct VkDebugUtilsLabelEXT {
    VkStructureType    sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT;
    const(void)*       pNext;
    const(char)*       pLabelName;
    float[4]           color;
} 

struct VK_EXT_debug_utils {
extern(System) @nogc nothrow:

    @VkProcName("vkSetDebugUtilsObjectNameEXT")
    VkResult function(VkDevice, const(VkDebugUtilsObjectNameInfoEXT)*) vkSetDebugUtilsObjectNameEXT;
    
    @VkProcName("vkCmdBeginDebugUtilsLabelEXT")
    void function (VkCommandBuffer, const(VkDebugUtilsLabelEXT)*) vkCmdBeginDebugUtilsLabelEXT;
    
    @VkProcName("vkCmdEndDebugUtilsLabelEXT")
    void function (VkCommandBuffer) vkCmdEndDebugUtilsLabelEXT;
}


//
//              VK_EXT_extended_dynamic_state3
//
struct VkPhysicalDeviceExtendedDynamicState3FeaturesEXT {
    VkStructureType    sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT;
    void*              pNext;
    VkBool32           extendedDynamicState3TessellationDomainOrigin;
    VkBool32           extendedDynamicState3DepthClampEnable;
    VkBool32           extendedDynamicState3PolygonMode;
    VkBool32           extendedDynamicState3RasterizationSamples;
    VkBool32           extendedDynamicState3SampleMask;
    VkBool32           extendedDynamicState3AlphaToCoverageEnable;
    VkBool32           extendedDynamicState3AlphaToOneEnable;
    VkBool32           extendedDynamicState3LogicOpEnable;
    VkBool32           extendedDynamicState3ColorBlendEnable;
    VkBool32           extendedDynamicState3ColorBlendEquation;
    VkBool32           extendedDynamicState3ColorWriteMask;
    VkBool32           extendedDynamicState3RasterizationStream;
    VkBool32           extendedDynamicState3ConservativeRasterizationMode;
    VkBool32           extendedDynamicState3ExtraPrimitiveOverestimationSize;
    VkBool32           extendedDynamicState3DepthClipEnable;
    VkBool32           extendedDynamicState3SampleLocationsEnable;
    VkBool32           extendedDynamicState3ColorBlendAdvanced;
    VkBool32           extendedDynamicState3ProvokingVertexMode;
    VkBool32           extendedDynamicState3LineRasterizationMode;
    VkBool32           extendedDynamicState3LineStippleEnable;
    VkBool32           extendedDynamicState3DepthClipNegativeOneToOne;
    VkBool32           extendedDynamicState3ViewportWScalingEnable;
    VkBool32           extendedDynamicState3ViewportSwizzle;
    VkBool32           extendedDynamicState3CoverageToColorEnable;
    VkBool32           extendedDynamicState3CoverageToColorLocation;
    VkBool32           extendedDynamicState3CoverageModulationMode;
    VkBool32           extendedDynamicState3CoverageModulationTableEnable;
    VkBool32           extendedDynamicState3CoverageModulationTable;
    VkBool32           extendedDynamicState3CoverageReductionMode;
    VkBool32           extendedDynamicState3RepresentativeFragmentTestEnable;
    VkBool32           extendedDynamicState3ShadingRateImageEnable;
}

struct VkPhysicalDeviceExtendedDynamicState3PropertiesEXT {
    VkStructureType    sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_PROPERTIES_EXT;
    void*              pNext;
    VkBool32           dynamicPrimitiveTopologyUnrestricted;
}