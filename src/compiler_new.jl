immutable FlatFunctionFactory
        # normalized equations
        equations::Vector{Expr}
        # list of group of (normalized) variables
        arguments::OrderedDict{Symbol, Vector{Symbol}}
        # list of assigned variables
        targets::Vector{Symbol}
        # preamble: definitions
        preamble::OrderedDict{Symbol, Expr}
        # name of function
        funname::Symbol
end

function FlatFunctionFactory(ff::FunctionFactory)

    equations = Expr[]
    for eq in ff.eqs
        # we remove lhs if it is there
        if eq.head == :(=)
            ee = eq.args[2]
        else
            ee = eq
        end
        push!(equations, ee)
    end

    arguments = OrderedDict{Symbol, Vector{Symbol}}()
    # we assume silently :p is not given as an argument in ff
    if isa(ff.args, OrderedDict)
        for k in keys(ff.args)
            arguments[k] = [Dolang.normalize(e) for e in ff.args[k]]
        end
    else
        arguments[:x] = [Dolang.normalize(e) for e in ff.args]
    end
    arguments[:p] = [Dolang.normalize(p) for p in ff.params]

    targets = ff.targets

    preamble = OrderedDict{Symbol, Expr}()
    for k in keys(ff.defs)
        preamble[Dolang.normalize(k)] = Dolang.normalize(ff.defs[k])
    end

    funname = ff.funname
    # return equations, arguments, targets, preamble, funname
    FlatFunctionFactory(equations, arguments, targets, preamble, funname)

end


function sym_to_sarray(v::Vector{Symbol})
    Expr(:call,:SVector, v...)
end

function sym_to_sarray(v::Matrix{Symbol})
    p,q = size(v)
    Expr(:call,:(SMatrix{$p,$q}), v[:]...)
end

get_first(x) = x[1]

function gen_fun(fff::FlatFunctionFactory, diff::Vector{Int})
    # diff indices of vars to differentiate
    # 0 for residuals, i for i-th argument




    # prepare equations to write
    outputs = OrderedDict()
    targets = OrderedDict()
    if 0 in diff
        outputs[0] = collect(zip(fff.targets, fff.equations))
    end
    p = length(fff.targets)
    argnames = collect(keys(fff.arguments))
    for d in filter(x->x!=0, diff)
        argname = argnames[d]
        vars = fff.arguments[argname]
        q = length(vars)
        jacexpr = Matrix(p, q)
        for i=1:p
            v_out = fff.targets[i]
            for j=1:q

                expr = Dolang.deriv(fff.equations[i], vars[j])
                sym = Symbol(string("d_",v_out,"_d_",vars[j]))
                jacexpr[i,j] = (sym, expr)
            end
        end
        outputs[d] = jacexpr
    end


    code = []

    for (k,args) in fff.arguments
        for (i,a) in enumerate(args)
            push!(code, :($a = ($k)[$i]))
        end
    end

    for (k,v) in fff.preamble
        push!(code, :($k = $v))
    end

    for (d,out) in outputs
        for k in out[:]
            push!(code, :($(k[1])=$(k[2])))
        end
    end

    return_args = []
    for (d,out) in outputs
        names = get_first.(out)
        outname = Symbol(string("out_",d))
        push!(code, :($outname = $(sym_to_sarray(names))))
        push!(return_args, outname)
    end

    push!(code, Expr(:return, Expr(:tuple, return_args...)))

end
