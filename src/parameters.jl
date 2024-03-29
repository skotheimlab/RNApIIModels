"""
Define a parameter object for the walker.
"""
struct Params
	α::Float32 # initiation rate from promoter to gene body
	β::Float32 # elongation rate
	γ::Float32 # termination rate
	L::Int # footprint of the body
	kon::Float32 # rate of binding to the promoter
	koff::Float32 # rate of unbinding to the promoter
	Δt::Float32 # timestep
	n_steps::Int # number of steps in the simulation
	n_sites::Int # number of sites on the gene
	n_end_sites::Int # number of sites where termination is possible
	β2::Float32 # elongation rate on the termination sites
end

Params(
	α, β, γ, Δt, n_steps, n_sites, n_end_sites, β2
) = Params(
	α, β, γ, 1, Δt, n_steps, n_sites, n_end_sites, β2
)



"""
Default parameters
"""
# gene length for average gene [bp]
gL = 1e3

# average cell size [fL]
avg_cell_size = 50

LARGE_γ = 1000

α_default = 0.0033
β_default = 0.57
γ_default = 0.014
Δt_default = .01
ratio_β2_default = 8
β2_default = β_default/ratio_β2_default
L_default = 1
kon_default = 1
koff_default = 1

δ_default = 35 / L_default

DEFAULT_nsteps = 1e6
DEFAULT_n_events = 1e3

DEFAULT_n_sites = Int(round(gL/δ_default))
DEFAULT_n_end_sites = 3 # small termination region as we neglect the termination rate in the end

"""
Ranges of acceptable metrics from the literature
"""

# residence time of RNAp on promoter [s]
min_Ω = 2
max_Ω = 4

# number of RNAp on promoter [-]
min_ρ_p = 0.017
max_ρ_p = 0.055

# number of RNAp in gene body [-]
min_ρ_g = 0.177 - max_ρ_p
max_ρ_g = .67 - min_ρ_p

# total residence time on promoter + gene body [-]
min_Ψ = 23
max_Ψ = 26

# elongation rates [s-1]
min_β = 13
max_β = 33

# residence time in the gene body
min_Λ = min_Ψ - max_Ω
max_Λ = max_Ψ - min_Ω

# on rate or the promoter
max_k_on = max_ρ_p/(1-max_ρ_p)/min_Ω
min_k_on = min_ρ_p/(1-min_ρ_p)/max_Ω

# initiation rate
max_α = max_Λ * max_β/min_Ω/gL
min_α = min_Λ * min_β/max_Ω/gL

# off rate from the promoter
max_k_off = 1/min_Ω-min_α
min_k_off = max(0, 1/max_Ω - max_α)

LITERATURE_PARAMS = Dict(
	"min_α" => min_α, 
	"max_α" => max_α, 
	"min_k_on" => min_k_on, 
	"max_k_on" => max_k_on, 
	"min_k_off" => min_k_off, 
	"max_k_off" => max_k_off, 
	"min_β" => min_β, 
	"max_β" => max_β
)


###########################
# parameters for the occupancy simulations
###########################

OCCUPANCY_PARAMS = Dict(
    "Ω" => min_Ω, 
    "n_steps" => DEFAULT_nsteps, 
    "L" => L_default,
    "δ" => δ_default,
    "n_sites" => DEFAULT_n_sites, 
    "n_end_sites" => DEFAULT_n_end_sites,
    "γ" => nothing, 
    "Δt" => nothing, # we will set it adaptively
    "n_events" => DEFAULT_n_events
)

DEFAULT_PARAMS = Params(
	α_default, β_default, γ_default, L_default, kon_default, koff_default, Δt_default, 
	DEFAULT_nsteps, DEFAULT_n_sites, DEFAULT_n_end_sites, β2_default
)

# other parameters for the screening experiments

n_kon_pts_screen = 10 # how many different values of kon to simulate for
n_α_values_screen = 8 # how many different values of α to simulate for

# Parameters for a narrow screen with feasible and infeasible points
k_on_vec_screen = 10 .^(LinRange(
    log10(LITERATURE_PARAMS["min_k_on"]/1.2), 
	log10(LITERATURE_PARAMS["max_k_on"]*1.2), 
	n_kon_pts_screen
))

α_vec_screen = LinRange(
	LITERATURE_PARAMS["min_α"], 
	LITERATURE_PARAMS["max_α"] * 1.5, 
	n_α_values_screen
	)

β_screen = LITERATURE_PARAMS["max_β"] / OCCUPANCY_PARAMS["δ"]