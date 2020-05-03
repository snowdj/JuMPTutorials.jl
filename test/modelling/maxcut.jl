
using LinearAlgebra
using SparseArrays
using Test
import Random

using JuMP
using GLPK
using LightGraphs
using GraphPlot
import SCS
using Colors: @colorant_str


# TODO explain problem


function compute_cut_value(g::LightGraphs.AbstractGraph, w::AbstractMatrix, vertex_subset)
    return sum(w[i,j] for i in vertices(g) for j in neighbors(g, i) if in(i, vertex_subset)  != in(j, vertex_subset))
end


g = SimpleGraph(6)
add_edge!(g, 1, 2)
add_edge!(g, 1, 5)
add_edge!(g, 2, 3)
add_edge!(g, 2, 5)
add_edge!(g, 3, 4)
add_edge!(g, 4, 5)
add_edge!(g, 4, 6);

GraphPlot.gplot(g, nodelabel=1:6)


w = spzeros(6, 6)

for e in edges(g)
   (i, j) = Tuple(e)
   w[i,j] = 1
end


@test compute_cut_value(g, w, (2, 5, 6)) ≈ 5
@show compute_cut_value(g, w, (2, 5, 6));


n = nv(g)

linear_max_cut = Model(GLPK.Optimizer)

@variable(linear_max_cut, z[1:n,1:n], Bin)
@variable(linear_max_cut, x[1:n], Bin)
@constraint(linear_max_cut, [i = 1:n, j = 1:n; (i, j) in edges(g)], z[i,j] <= x[i] + x[j])
@constraint(linear_max_cut, [i = 1:n, j = 1:n; (i, j) in edges(g)], z[i,j] <= 2 - (x[i] + x[j]))

@objective(linear_max_cut, Max, dot(w, z))

optimize!(linear_max_cut)

@test objective_value(linear_max_cut) ≈ 6.0
@show objective_value(linear_max_cut);

x_linear = value.(x)
@show x_linear;
@show [(i,j) for i in 1:n-1 for j in i+1:n if JuMP.value.(z)[i,j] > 0.5];


nodecolor = [colorant"lightseagreen", colorant"orange"]
all_node_colors = [nodecolor[round(Int, xi + 1)]  for xi in x_linear]
GraphPlot.gplot(g, nodelabel=1:6, nodefillc=all_node_colors)


sdp_max_cut = Model(optimizer_with_attributes(SCS.Optimizer, "verbose" => 0))

@variable(sdp_max_cut, Y[1:n,1:n] in PSDCone())
@constraint(sdp_max_cut, [i = 1:n], Y[i,i] == 1)
@objective(sdp_max_cut, Max, 1/4 * sum(w[i,j] * (1 - Y[i,j]) for i in 1:n for j in 1:n))

optimize!(sdp_max_cut)

@test objective_value(linear_max_cut) >= 6.0
@show objective_value(linear_max_cut);


F = svd(value.(Y))
U = F.U * Diagonal(sqrt.(F.S))

Random.seed!(33)


x = randn(size(U, 2))
xhat = sign.(U * x) .> 0

@show collect(zip(round.(Int, x_linear), xhat))
@test LinearAlgebra.norm1(round.(Int, x_linear) .- xhat) == 0 || LinearAlgebra.norm1(round.(Int, x_linear) .- xhat) == n


nodecolor = [colorant"lightseagreen", colorant"orange"]
all_node_colors = [nodecolor[xi + 1] for xi in xhat]
GraphPlot.gplot(g, nodelabel=1:6, nodefillc=all_node_colors)

