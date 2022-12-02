"""
Run simulations of sweeping kon and alpha

!!! explain difference of params_iter and occupancy params
- one is fixed
- the other varies across iterations
"""
function run_occupancy_simulation(
		params_iter, occupancy_params,
	)

	# unpacking parameters
	Ω = occupancy_params["Ω"]
	γ = occupancy_params["γ"]
	L = occupancy_params["L"]
	Δt = occupancy_params["Δt"]
	n_steps = occupancy_params["n_steps"]
	n_sites = occupancy_params["n_sites"]
	n_end_sites = occupancy_params["n_end_sites"]
	n_events = occupancy_params["n_events"]

	# defining saved variables
    occupancy = []
	promoter_occ = []
	params_occ = []

	for (α, β, k_on_vec) in params_iter
			k_off = max(0, 1/Ω-α)
			
			occupancy_crt = []
			prom_occ_crt = []
			params_list = []
	
			for k_on in k_on_vec

				# adaptively select the Δt and γ
				if Δt === nothing
					Δt_crt = set_Δt(α, β, β/8, k_on, k_off, γ)
				else
					Δt_crt = Δt
				end

				if γ === nothing
					γ_crt = 1/Δt_crt
				else
					γ_crt = γ
				end

				if n_events !== nothing
					n_steps = Int(round(n_events/k_on))
				end
			
				params_crt = Params(
					α, β, γ_crt, L, k_on, k_off, 
					Δt_crt, n_steps, 
					n_sites, n_end_sites, 
					β/8
				)

				_, density, _, _ = run_walker(params_crt);

				# only works with L = 1
				push!(
					occupancy_crt, 
					get_total_occupancy(
						density, params_crt; start_bp=2
					)
				)
				push!(
					prom_occ_crt, 
					get_total_occupancy(
						density, params_crt; start_bp=1, end_bp = 1
					)
				)
				push!(params_list, params_crt)
				
			end
	
			push!(occupancy, occupancy_crt)
			push!(promoter_occ, prom_occ_crt)
			push!(params_occ, params_list)
			
	end

    return occupancy, promoter_occ, params_occ
end


"""
Do a sweep in the parameters.
"""
function sweep_params(α_vec, p_vec, param_name; params=DEFAULT_PARAMS)

	params_dict = Dict()
	trans_rates = Dict()
	residence_times = Dict() # in number of steps
	densities = Dict()

	for p in ProgressBar(p_vec)

		params_dict[p] = []
		trans_rates[p] = []
		residence_times[p] = []
		densities[p] = Dict()
	
		for α in α_vec

			if param_name == "γ"
				β = params.β*params.L
				γ = p 
				L = params.L
				n_steps = params.n_steps
				n_sites = params.n_sites*params.L
				n_end_sites = params.n_end_sites*params.L
				β2 = params.β2*params.L
			elseif param_name == "L"
				β = params.β*p
				γ = params.γ
				L = p 
				n_steps = params.n_steps
				n_sites = params.n_sites*p
				n_end_sites = params.n_end_sites*p
				β2 = params.β2*p
			end
			
			Δt = 1/3 * minimum([1/α, 1/β, 1/γ])

			params_crt = Params(
				α, β, γ, L, Δt, n_steps, n_sites, n_end_sites, β2
			)

			exits_, density_, _, tracker_ = run_walker(params_crt);

			push!(params_dict[p], params_crt)
			push!(trans_rates[p], get_trans_rate(exits_, params_crt))
			push!(residence_times[p], mean(tracker_["terminated"]))
			densities[p][α] = density_
		
		end
		
	end

	return params_dict, trans_rates, residence_times, densities
end

reshape_occ_screen(x) = reshape(
    hcat(hcat(x...)...), length(x[1][2]), length(x[1]), :  
) 

function get_feasible_pts(fnm)

    # unpack the results
    results_fs = JLD2.load(fnm)
    occupancy = results_fs["occupancy"]
    promoter_occ = results_fs["promoter_occ"]

	# dims are (nk, nα, n_iter)
    occupancy = reshape_occ_screen(occupancy)
    promoter_occ = reshape_occ_screen(promoter_occ)

	@show size(occupancy), size(promoter_occ)

	nα = size(occupancy, 2)

    # taking the median over potentially many different simulations
    occ_median = [vec(median(occupancy[:, k, :], dims=2)) for k in 1:nα]
    prom_occ_median = [vec(median(promoter_occ[:, k, :], dims=2)) for k in 1:nα]

    # determine feasible points
    occ_mat = reduce(hcat, occ_median)
    occ_mat = (occ_mat .< RNApIIModels.max_ρ_g) .& (occ_mat .> RNApIIModels.min_ρ_g)
    prom_occ_mat = reduce(hcat, prom_occ_median)
    prom_occ_mat = (prom_occ_mat .< RNApIIModels.max_ρ_p) .& (prom_occ_mat .> RNApIIModels.min_ρ_p)
    feasible = (occ_mat .& prom_occ_mat)

	@show size(occ_mat), size(prom_occ_mat)

    feasible_pts = []
    for (idx_k, idx_α) in Tuple.(findall(feasible .== 1))
        push!(feasible_pts, (k_on_vec_screen[idx_k], α_vec_screen[idx_α]))
    end

    return feasible, feasible_pts

end