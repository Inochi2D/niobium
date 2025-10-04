/**
    nioinfo Utility Application
    
    Lists information about GPUs supported by niobium.

    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module app;
import niobium;
import std.stdio;

void main() {
	writefln("Devices: %s", NioDevice.systemDevices().length);
	foreach(i, device; NioDevice.systemDevices()) {
		NioDeviceFeatures features = device.features;
		NioDeviceLimits limits = device.limits;
		
		writefln("%s: (%s):", i, device.name);
		writefln("  Type: %s", device.type);
		writefln("  Features:");
		static foreach(member; __traits(allMembers, NioDeviceFeatures)) {
			writefln("    %s=%s", member, __traits(getMember, features, member));
		}
		writefln("  Limits:");
		static foreach(member; __traits(allMembers, NioDeviceLimits)) {
			writefln("    %s=%s", member, __traits(getMember, limits, member));
		}
	}
}