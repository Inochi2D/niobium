/**
    NIR Compiler Type System
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.ir.type;
import nir.ir.atom;
import numem;

/**
    Type kind
*/
enum NirTypeKind : uint {
    unknown         = 0x00000000U,
    void_           = 0x00000001U,
    bool_           = 0x00000002U,
    int_            = 0x00000003U,
    float_          = 0x00000004U,
    vector          = 0x00000005U,
    array           = 0x00000006U,
    matrix          = 0x00000007U,
    struct_         = 0x00000008U,
    function_       = 0x00000009U,
    opaque          = 0x0000000AU,
    image           = 0x0000000BU,
    sampler         = 0x0000000CU,
    sampledImage    = 0x0000000DU,
    event           = 0x0000000EU,
    deviceEvent     = 0x0000000FU,
    queue           = 0x00000011U,
    reserveId       = 0x00000012U,
    pipe            = 0x00000013U,
    pointer         = 0x00000014U,
    fwdPointer      = 0x00000015U,
}

/**
    Gets the $(D NirTypeKind) associated with a given $(D Op).

    Params:
        opcode = The opcode to query.
    
    Returns:
        A non-zero $(D NirTypeKind) on success,
        $(D NirTypeKind.unknown) otherwise.
*/
NirTypeKind toTypeKind(Op opcode) @nogc {
    switch(opcode) with(Op) {
        default:                        return NirTypeKind.unknown;
        case OpTypeVoid:                return NirTypeKind.void_;
        case OpTypeBool:                return NirTypeKind.bool_;
        case OpTypeInt:                 return NirTypeKind.int_;
        case OpTypeFloat:               return NirTypeKind.float_;
        case OpTypeVector:              return NirTypeKind.vector;
        case OpTypeRuntimeArray:        return NirTypeKind.array;  
        case OpTypeArray:               return NirTypeKind.array;
        case OpTypeMatrix:              return NirTypeKind.matrix;
        case OpTypeStruct:              return NirTypeKind.struct_;
        case OpTypeFunction:            return NirTypeKind.function_;
        case OpTypeOpaque:              return NirTypeKind.opaque;
        case OpTypeImage:               return NirTypeKind.image;
        case OpTypeSampler:             return NirTypeKind.sampler;
        case OpTypeSampledImage:        return NirTypeKind.sampledImage;
        case OpTypeEvent:               return NirTypeKind.event;
        case OpTypeDeviceEvent:         return NirTypeKind.deviceEvent;
        case OpTypeQueue:               return NirTypeKind.queue;
        case OpTypeReserveId:           return NirTypeKind.reserveId;
        case OpTypePointer:             return NirTypeKind.pointer;
        case OpTypePipe:                return NirTypeKind.pipe;
        case OpTypeForwardPointer:      return NirTypeKind.fwdPointer;
    }
}

/**
    Represents a type within a NIR Atom stream.
*/
abstract
class NirType : NirAtomObject {
private:
@nogc:
    NirTypeKind kind_;

protected:

    /**
        Base constructor for type atoms.
    */
    this(Op opcode) {
        super(opcode);
        this.kind_ = opcode.toTypeKind();
    }

public:

    /**
        The kind of type this is.
    */
    @property NirTypeKind kind() => kind_;

    /**
        The width of this type
    */
    abstract @property uint width();
}

/**
    A $(D void) type.
*/
class NirTypeVoid : NirType {
public:
@nogc:

    /**
        The width of this type
    */
    override @property uint width() => 0;

    /**
        Constructs a void type.
    */
    this() { super(Op.OpTypeVoid); }
}

/**
    A $(D float) type.
*/
class NirTypeFloat : NirType {
private:
@nogc:
    uint width_;

public:

    /**
        The width of this type
    */
    override @property uint width() => width_;
    
    /**
        Constructs a void type.
    */
    this(uint width) { 
        super(Op.OpTypeFloat);
        this.width_ = width;
    }
}

/**
    Base type of scalar types.
*/
abstract
class NirTypeScalar : NirType {
protected:
@nogc:

    /**
        Base constructor for type atoms.
    */
    this(Op opcode) { super(opcode); }
}

/**
    A $(D int) type.
*/
class NirTypeInt : NirTypeScalar {
private:
@nogc:
    bool signed_;
    uint width_;

public:

    /**
        Whether this type is signed.
    */
    @property bool isSigned() => signed_;

    /**
        The width of this type
    */
    override @property uint width() => width_;
    
    /**
        Constructs a void type.
    */
    this(bool signed, uint width) { 
        super(Op.OpTypeInt);
        this.signed_ = signed;
        this.width_ = width;
    }
}

/**
    A vector type.
*/
class NirTypeVector : NirTypeScalar {
private:
@nogc:
    NirTypeScalar baseType_;
    uint components_;

public:

    /**
        The base type of this vector
    */
    @property NirTypeScalar baseType() => baseType_;

    /**
        The amount of components in this vector
    */
    @property uint components() => components_;

    /**
        The width of this type
    */
    override @property uint width() => baseType_.width*components_;
    
    /// Destructor
    ~this() {
        baseType_.release();
    }
    
    /**
        Constructs a void type.
    */
    this(NirTypeScalar baseType, uint components) { 
        super(Op.OpTypeVector);
        this.baseType_ = baseType.retained; 
        this.components_ = components;
    }
}

/**
    A matrix type.
*/
class NirTypeMatrix : NirType {
private:
@nogc:
    NirTypeVector baseType_;
    uint components_;

public:

    /**
        The base type of this matrix
    */
    @property NirTypeVector baseType() => baseType_;

    /**
        The amount of components in this matrix
    */
    @property uint components() => components_;

    /**
        The width of this type
    */
    override @property uint width() => baseType_.width*components_;
    
    /// Destructor
    ~this() {
        baseType_.release();
    }
    
    /**
        Constructs a void type.
    */
    this(NirTypeVector baseType, uint components) { 
        super(Op.OpTypeMatrix);
        this.baseType_ = baseType.retained(); 
        this.components_ = components;
    }
}

/**
    A structure type.
*/
class NirTypeStruct : NirType {
private:
@nogc:
    NirType[] members_;

public:

    /**
        The members of this struct
    */
    @property NirType[] members() => members_;

    /**
        The width of this type
    */
    override @property uint width() {
        uint result = 0;
        foreach(member; members_)
            result += member.width;
        
        return result;
    }
    
    /// Destructor
    ~this() {
        foreach(member; members)
            member.release();
        nu_freea(members_);
    }

    /**
        Constructs a void type.
    */
    this(NirType[] members) { 
        super(Op.OpTypeStruct);
        this.members_ = members.nu_dup();
        foreach(member; members) {
            member.retain();
        }
    }
}

/**
    A function type.
*/
class NirTypeFunction : NirType {
private:
@nogc:
    NirType returnType_;
    NirType[] arguments_;

public:

    /**
        The return type of the function.
    */
    @property NirType returnType() => returnType_;

    /**
        The types of the arguments of this function.
    */
    @property NirType[] arguments() => arguments_;

    /**
        The width of this type
    */
    override @property uint width() => 0;
    
    /// Destructor
    ~this() {
        returnType_.release();
        foreach(argument; arguments_)
            argument.release();
        nu_freea(arguments_);
    }

    /**
        Constructs a void type.
    */
    this(NirType returnType, NirType[] arguments) { 
        super(Op.OpTypeFunction);
        this.returnType_ = returnType.retained();
        this.arguments_ = arguments.nu_dup();
        foreach(argument; arguments_) {
            argument.retain();
        }
    }
}

/**
    An array type.
*/
class NirTypeArray : NirType {
private:
@nogc:
    NirType elementType_;

public:

    /**
        The type of the elements in the array.
    */
    @property NirType elementType() => elementType_;

    /**
        The width of this type
    */
    override @property uint width() => 0;

    /// Destructor
    ~this() {
        elementType_.release();
    }

    /**
        Constructs a new array type
    */
    this(NirType elementType) {
        super(Op.OpTypeRuntimeArray);
        this.elementType_ = elementType;
    }
}

/**
    A pointer type.
*/
class NirTypePointer : NirType {
private:
    NirType elementType_;
    StorageClass storageClass_;

public:
@nogc:

    /**
        The type of the element being pointed to.
    */
    @property NirType elementType() => elementType_;

    /**
        The storage class of the pointer.
    */
    @property StorageClass storageClass() => storageClass_;

    /**
        The width of this type
    */
    override @property uint width() => 0;

    /// Destructor
    ~this() {
        elementType_.release();
    }

    /**
        Constructs a new sampler type
    */
    this(StorageClass storageClass, NirType elementType) {
        super(Op.OpTypeSampler);
        this.storageClass_ = storageClass;
        this.elementType_ = elementType.retained();
    }
}

/**
    A image type.
*/
class NirTypeImage : NirType {
private:
@nogc:
    NirTypeScalar sampledType_;
    Dim dim_;
    bool array_;
    bool multisampled_;
    ImageFormat format_;

public:

    /**
        The type of the image data
    */
    @property NirTypeScalar sampledType() => sampledType_;

    /**
        The dimensionality of the image.
    */
    @property Dim dim() => dim_;

    /**
        Whether the image is an array.
    */
    @property bool isArray() => array_;

    /**
        Whether the image is multisampled.
    */
    @property bool isMultisampled() => multisampled_;

    /**
        Format of the image.
    */
    @property ImageFormat format() => format_;

    /**
        The width of this type
    */
    override @property uint width() => 0;
    
    /// Destructor
    ~this() { }

    /**
        Constructs a void type.
    */
    this(NirTypeScalar sampledType, Dim dim, bool array, bool multisampled, ImageFormat format) { 
        super(Op.OpTypeImage);
        this.sampledType_ = sampledType.retained();
        this.dim_ = dim;
        this.array_ = array;
        this.multisampled_ = multisampled;
        this.format_ = format;
    }
}

/**
    A sampler type.
*/
class NirTypeSampler : NirType {
public:
@nogc:

    /**
        The width of this type
    */
    override @property uint width() => 0;

    /**
        Constructs a new sampler type
    */
    this() { super(Op.OpTypeSampler); }
}