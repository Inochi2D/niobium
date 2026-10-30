module niobium.meta;
import niobium.types;
import niobium.buffer;
import niobium.texture;
import niobium.sampler;
import numem.core.traits;

/**
    Gets the NioDataType assocated with type T.
*/
template toNioDataType(T) {
         static if (is(T == bool))          enum toNioDataType = NioDataType.bool1;
    else static if (is(T == ubyte))         enum toNioDataType = NioDataType.ubyte1;
    else static if (is(T == byte))          enum toNioDataType = NioDataType.byte1;
    else static if (is(T == ushort))        enum toNioDataType = NioDataType.ushort1;
    else static if (is(T == short))         enum toNioDataType = NioDataType.short1;
    else static if (is(T == uint))          enum toNioDataType = NioDataType.uint1;
    else static if (is(T == int))           enum toNioDataType = NioDataType.int1;
    else static if (is(T == ulong))         enum toNioDataType = NioDataType.ulong1;
    else static if (is(T == long))          enum toNioDataType = NioDataType.long1;
    else static if (is(T == float))         enum toNioDataType = NioDataType.float1;
    else static if (is(T == NioTexture))    enum toNioDataType = NioDataType.texture;
    else static if (is(T == NioSampler))    enum toNioDataType = NioDataType.sampler;
    else static if (is(typeof(T.matrix)) && is(typeof(T.rows)) && is(typeof(T.columns)) && __traits(isStaticArray, typeof(T.matrix))) {

        // Matrix types.
        static if (!is(ElementType!(T.data) == void)) {
            enum toNioDataType = __traits(getMember, NioDataType, ElementType!(T.data).stringof~(cast(int)T.rows).stringof~"x"~~(cast(int)T.columns).stringof);
        } else {
            enum toNioDataType = NioDataType.unknown;
        }
    } else static if (is(typeof(T.data)) && __traits(isStaticArray, typeof(T.data))) {
        // Vector types.
        static if (!is(ElementType!(T.data) == void)) {
            enum toNioDataType = __traits(getMember, NioDataType, ElementType!(T.data).stringof~(cast(int)T.data.length).stringof);
        } else {
            enum toNioDataType = NioDataType.unknown;
        }
    } else static assert(0, "Unknown type "~T.stringof);
}