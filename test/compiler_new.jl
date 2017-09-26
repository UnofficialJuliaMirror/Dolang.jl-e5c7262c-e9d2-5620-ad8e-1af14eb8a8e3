using StaticArrays
using Dolang, DataStructures, Base.Test

eqs = [:(foo(0) = log(a(0))+b(0)/x(-1)), :(bar(0) = c(1)+u*d(1))]
args = [(:a, -1), (:a, 0), (:b, 0), (:c, 0), (:c, 1), (:d, 1)]
params = [:u]
defs = Dict(:x=>:(a(0)/(1-c(1))))
targets = [(:foo, 0), (:bar, 0)]
funname = :myfun

const flat_args = [(:a, 0), (:b, 1), (:c, -1)]
const grouped_args = OrderedDict(:x=>[(:a, -1),], :y=>[(:a, 0), (:b, 0), (:c, 0)], :z=>[(:c, 1), (:d, 1)])
const flat_params = [:beta, :delta]
const grouped_params = Dict(:p => [:u])

args2 = vcat(args, targets)::Vector{Tuple{Symbol,Int}}


ff = Dolang.FunctionFactory(eqs, args, params, targets=targets, defs=defs,
                            funname=funname)

ff2 = Dolang.FunctionFactory(eqs, grouped_args, params, targets=targets, defs=defs,
                            funname=funname)


# we're all static arrays
x = @SVector [1.0]
y = @SVector [2.0, 0.5, 0.3]
z = @SVector [0.4, 0.2]
p = @SVector [0.1]
#
# we're all vectors
xv = Vector(x)
yv = Vector(y)
zv = Vector(z)
pv = Vector(p)

# we're list of points
N=5
x_vec = reinterpret(SVector{1,Float64}, 1+rand(1,N), (N,))
y_vec = reinterpret(SVector{3,Float64}, rand(3,N), (N,))
z_vec = reinterpret(SVector{2,Float64}, rand(2,N), (N,))
p_vec = reinterpret(SVector{1,Float64}, rand(1,N), (N,))

# as matrices
x_mat = Dolang.from_SA(x_vec)
y_mat = Dolang.from_SA(y_vec)
z_mat = Dolang.from_SA(z_vec)
p_mat = Dolang.from_SA(p_vec)


@testset "Static Arrays Functions" begin


    @testset "Flat Function Factory" begin
        fff = Dolang.FlatFunctionFactory(ff)
        fff2 = Dolang.FlatFunctionFactory(ff2)
    end


    @testset "Kernel" begin
        fff = Dolang.FlatFunctionFactory(ff2)
        cc = Dolang.gen_kernel(fff, [0,1,3], funname=:kernel)
        kernel = eval(Dolang, cc)
        res = kernel(x,y,z,p)
        @test ( typeof(res) <: Tuple{SVector{2,Float64},SMatrix{2,1,Float64},SMatrix{2,2,Float64}} )
    end


    @testset "GuFun" begin
        fff = Dolang.FlatFunctionFactory(ff2)
        cc = Dolang.gen_gufun(fff, [0,1,3], funname=:gufun)
        gufun = eval(Dolang, cc)
        # behaves like a kernel
        res = gufun(x,y,z,p)
        @test typeof(res) <: Tuple{SVector{2,Float64},SMatrix{2,1,Float64},SMatrix{2,2,Float64}}
        # doesn't like allocated vectors but does it anyway
        res = gufun(xv,yv,zv,pv)
        @test typeof(res) <: Tuple{Array{Float64,1}, Array{Float64,2}, Array{Float64,2}}
        # vectorized calls
        res = gufun(x_vec,y_vec,z_vec,p_vec)
        @test typeof(res) <:Tuple{Array{SVector{2,Float64},1},Array{StaticArrays.SArray{Tuple{2,1},Float64,2,2},1},Array{StaticArrays.SArray{Tuple{2,2},Float64,2,4},1}}
        @test (length(res[1]) == length(res[2]) == length(x_vec))
        res2 = gufun(x,y_vec,z,p_vec)
        @test typeof(res2) <: Tuple{Array{SVector{2,Float64},1},Array{StaticArrays.SArray{Tuple{2,1},Float64,2,2},1},Array{StaticArrays.SArray{Tuple{2,2},Float64,2,4},1}}
        res3 = gufun(x_vec,y,z,p)
        @test typeof(res3) <: Tuple{Array{SVector{2,Float64},1},Array{StaticArrays.SArray{Tuple{2,1},Float64,2,2},1},Array{StaticArrays.SArray{Tuple{2,2},Float64,2,4},1}}
        # vectorized calls with matrix inputs
        res4 = gufun(x_mat, y_mat, z_mat, p_mat)
        @test typeof(res4) <: Tuple{Matrix{Float64},Array{Float64,3},Array{Float64,3}}
        res5 = gufun(x_mat, y_mat, z_mat, pv)
        @test typeof(res5) <: Tuple{Matrix{Float64},Array{Float64,3},Array{Float64,3}}
        res6 = gufun(xv, yv, zv, pv)
        @test typeof(res6) <: Tuple{Vector{Float64},Matrix{Float64},Matrix{Float64}}

    end

    @testset "Generated Gufuns" begin
        fff = Dolang.FlatFunctionFactory(ff2)
        cc = Dolang.gen_generated_gufun(fff; funname=:gengufun)
        gengufun = eval(Dolang, cc)
        # behaves like a kernel
        res = gengufun((Val(0),Val(1),Val(3)),x,y,z,p)
        @test typeof(res) <: Tuple{SVector{2,Float64},SMatrix{2,1,Float64},SMatrix{2,2,Float64}}
        # doesn't like allocated vectors but does it anyway
        res = gengufun((Val(0),Val(1),Val(3)),xv,yv,zv,pv)
        @test typeof(res) <: Tuple{Array{Float64,1},Array{Float64,2},Array{Float64,2}}
        # vectorized calls
        res = gengufun((Val(0),Val(1),Val(3)),x_vec,y_vec,z_vec,p_vec)
        @test typeof(res) <: Tuple{Array{SVector{2,Float64},1},Array{StaticArrays.SArray{Tuple{2,1},Float64,2,2},1},Array{StaticArrays.SArray{Tuple{2,2},Float64,2,4},1}}
        @test (length(res[1]) == length(res[2]) == length(x_vec))
        res2 = gengufun((Val(0),Val(1),Val(3)),x,y_vec,z,p_vec)
        @test typeof(res2) <: Tuple{Array{SVector{2,Float64},1},Array{StaticArrays.SArray{Tuple{2,1},Float64,2,2},1},Array{StaticArrays.SArray{Tuple{2,2},Float64,2,4},1}}
        res3 = gengufun((Val(0),Val(1),Val(3)),x_vec,y,z,p)
        @test typeof(res3) <: Tuple{Array{SVector{2,Float64},1},Array{StaticArrays.SArray{Tuple{2,1},Float64,2,2},1},Array{StaticArrays.SArray{Tuple{2,2},Float64,2,4},1}}

    end

end