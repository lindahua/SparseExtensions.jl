
### Types

immutable SparseVector{Tv,Ti<:Integer} <: AbstractSparseVector{Tv,Ti}
    n::Int              # the number of elements
    nzind::Vector{Ti}   # the indices of nonzeros
    nzval::Vector{Tv}   # the values of nonzeros

    function SparseVector(n::Integer, nzind::Vector{Ti}, nzval::Vector{Tv})
        n >= 0 || throw(ArgumentError("The number of elements must be non-negative."))
        length(nzind) == length(nzval) ||
            throw(DimensionMismatch("The lengths of nzind and nzval are inconsistent."))
        new(convert(Int, n), nzind, nzval)
    end
end

### Basic properties

length(x::SparseVector) = x.n
size(x::SparseVector) = (x.n,)
nnz(x::SparseVector) = length(x.nzval)
countnz(x::SparseVector) = countnz(x.nzval)
nonzeros(x::SparseVector) = x.nzval
nonzeroinds(x::SparseVector) = x.nzind

### Construction

SparseVector{Tv,Ti}(n::Integer, nzind::Vector{Ti}, nzval::Vector{Tv}) =
    SparseVector{Tv,Ti}(n, nzind, nzval)

SparseVector(n::Integer) = SparseVector(n, Int[], Float64[])
SparseVector{Tv}(::Type{Tv}, n::Integer) = SparseVector(n, Int[], Tv[])
SparseVector{Tv,Ti<:Integer}(::Type{Tv}, ::Type{Ti}, n::Integer) = SparseVector(n, Ti[], Tv[])

### Construction from lists of indices and values

function _sparsevector!{Ti<:Integer}(I::Vector{Ti}, V::Vector, len::Integer)
    p = sortperm(I)
    permute!(I, p)
    permute!(V, p)
    SparseVector(len, I, V)
end


### Construction from dictionary

function sparsevector{Tv,Ti<:Integer}(dict::Associative{Ti,Tv})
    m = length(dict)
    nzind = Array(Ti, m)
    nzval = Array(Tv, m)

    cnt = 0
    len = zero(Ti)
    for (k, v) in dict
        k >= 1 || error("An index (key) is out of bound.")
        if k > len
            len = k
        end
        if v != zero(v)
            cnt += 1
            @inbounds nzind[cnt] = k
            @inbounds nzval[cnt] = v
        end
    end
    resize!(nzind, cnt)
    resize!(nzval, cnt)
    _sparsevector!(nzind, nzval, len)
end

function sparsevector{Tv,Ti<:Integer}(dict::Associative{Ti,Tv}, len::Integer)
    m = length(dict)
    nzind = Array(Ti, m)
    nzval = Array(Tv, m)

    cnt = 0
    maxk = convert(Ti, len)
    for (k, v) in dict
        1 <= k <= maxk || error("An index (key) is out of bound.")
        if v != zero(v)
            cnt += 1
            @inbounds nzind[cnt] = k
            @inbounds nzval[cnt] = v
        end
    end
    resize!(nzind, cnt)
    resize!(nzval, cnt)
    _sparsevector!(nzind, nzval, len)
end


### Element access

function setindex!{Tv,Ti<:Integer}(x::SparseVector{Tv,Ti}, v::Tv, i::Ti)
    nzind = nonzeroinds(x)
    nzval = nonzeros(x)

    m = length(nzind)
    k = searchsortedfirst(nzind, i)
    if 1 <= k <= m && nzind[k] == i  # i found
        if v == zero(v)
            deleteat!(nzind, k)
            deleteat!(nzval, k)
        else
            nzval[k] = v
        end
    else  # i not found
        if v != zero(v)
            insert!(nzind, k, i)
            insert!(nzval, k, v)
        end
    end
    x
end

setindex!{Tv, Ti<:Integer}(x::SparseVector{Tv,Ti}, v, i::Integer) =
    setindex!(x, convert(Tv, v), convert(Ti, i))


### Conversion

# convert SparseMatrixCSC to SparseVector
function convert{Tv,Ti<:Integer}(::Type{SparseVector{Tv,Ti}}, s::SparseMatrixCSC{Tv,Ti})
    size(s, 2) == 1 || throw(ArgumentError("The input argument must have a single-column."))
    SparseVector(s.m, s.rowval, s.nzval)
end

convert{Tv,Ti}(::Type{SparseVector{Tv}}, s::SparseMatrixCSC{Tv,Ti}) =
    convert(SparseVector{Tv,Ti}, s)

convert{Tv,Ti}(::Type{SparseVector}, s::SparseMatrixCSC{Tv,Ti}) =
    convert(SparseVector{Tv,Ti}, s)

# convert Vector to SparseVector
function convert{Tv}(::Type{SparseVector{Tv,Int}}, s::Vector{Tv})
    n = length(s)
    nzind = Array(Int, 0)
    nzval = Array(Tv, 0)
    for i = 1:n
        @inbounds v = s[i]
        if v != zero(v)
            push!(nzind, i)
            push!(nzval, v)
        end
    end
    return SparseVector(n, nzind, nzval)
end

convert{Tv}(::Type{SparseVector{Tv}}, s::Vector{Tv}) =
    convert(SparseVector{Tv,Int}, s)

convert{Tv}(::Type{SparseVector}, s::Vector{Tv}) =
    convert(SparseVector{Tv,Int}, s)


# convert between different types of SparseVector
convert{Tv,Ti,TvS,TiS}(::Type{SparseVector{Tv,Ti}}, s::SparseVector{TvS,TiS}) =
    SparseVector{Tv,Ti}(s.n, convert(Vector{Ti}, s.nzind), convert(Vector{Tv}, s.nzval))

convert{Tv,TvS,TiS}(::Type{SparseVector{Tv}}, s::SparseVector{TvS,TiS}) =
    SparseVector{Tv,TiS}(s.n, s.nzind, convert(Vector{Tv}, s.nzval))


### Rand Construction

function sprand{T}(n::Integer, p::FloatingPoint, rfn::Function, ::Type{T})
    I = randsubseq(1:convert(Int, n), p)
    V = rfn(T, length(I))
    SparseVector(n, I, V)
end

function sprand(n::Integer, p::FloatingPoint, rfn::Function)
    I = randsubseq(1:convert(Int, n), p)
    V = rfn(length(I))
    SparseVector(n, I, V)
end

sprand{T}(n::Integer, p::FloatingPoint, ::Type{T}) = sprand(n, p, rand, T)
sprand(n::Integer, p::FloatingPoint) = sprand(n, p, rand)
sprandn(n::Integer, p::FloatingPoint) = sprand(n, p, randn)
