using Distributions

"""
Define a parameter object
"""
struct Params
	α
	β
	δ
	Δt
	n_steps
	n_sites
	n_end_sites
	β2
end


"""
Runs the walker for a specified number of steps.
"""
function run_walker(
	α, β, δ, Δt, n_steps, n_sites, n_end_sites; 
	β2=nothing, model="continuous_detachment"
)

	if β2==nothing
		β2 = β/5 #slower rate in the second part
	end

	exits = zeros(n_steps)
	gene = zeros(n_sites + n_end_sites); # initializing the sites
	density = zeros(n_sites + n_end_sites); 

	tracker_end = Dict(
		"current" => zeros(n_end_sites), 
		"terminated" => [], 
	) # tracks every RNA getting into the last strand
	
	for k in 1:n_steps # number of timesteps
	
		gene, finish_flag, tracker_end = step(
			α, β, β2, δ, gene, n_sites, Δt, tracker_end; 
			model=model
		)
		density += gene

		exits[k] = finish_flag

	end

	return exits, density, gene, tracker_end
	
end

run_walker(params, model) = run_walker(
	params.α, params.β, params.δ, params.Δt, params.n_steps, params.n_sites, 
	params.n_end_sites; β2=params.β2, model=model
)

"""
Takes a step forward, for a given model. The kwarg `model` defines the behavior of the RNAs on the second strand. 


Notes: 
* Right now the function is run linearly. But for a real MC approach you would have to pick the location at random, for a sufficient number of times that it actually represents one real time step across the entire strand. 
* I have to check the Poisson process document again to make sure the probabilities are properly encoded. 
"""
function step(
	α, β, β2, δ, gene, n_sites, Δt, tracker_end; 
	model="continuous_detachment"
)

	# update tracker for RNAs present on the second strand
	tracker_end["current"][tracker_end["current"].>0] .+= 1
	
	# iterate on the termination strand
	if model == "continuous_detachment"
		
		# detachment can occur at any point, with increasing probability with time
		for j in length(gene):-1:n_sites+1
			x = j - n_sites
			p = 1 - exp(-δ/β2*x)
	
			if (gene[j]==1) & (rand(Bernoulli(p))) # detach
				gene[j] = 0

				push!(tracker_end["terminated"], tracker_end["current"][j-n_sites])
				tracker_end["current"][j-n_sites] = 0
				
			elseif (j<length(gene)) && (gene[j]==1) && (gene[j+1]==0) &&(rand(Bernoulli(β2*Δt))) # advances
				gene[j+1] = 1
				gene[j] = 0

				tracker_end["current"][j-n_sites+1] = tracker_end["current"][j-n_sites]
				tracker_end["current"][j-n_sites] = 0
			end
			
		end
		
	elseif model == "end_site"

		t_d = get_t_d(δ, length(gene) - n_sites, β2)
		
		# detachment can occur only at the end site, with increasing probability with time

		if (gene[end]==1) & (rand(Bernoulli(Δt/t_d)))
			gene[end] = 0
			push!(tracker_end["terminated"], tracker_end["current"][end])
			tracker_end["current"][end] = 0
		end

		for j in length(gene)-1:-1:n_sites+1
			if (gene[j]==1) & (gene[j+1]==0) * (rand(Bernoulli(β2*Δt)))
				gene[j+1] = 1
				gene[j] = 0

				tracker_end["current"][j-n_sites+1] = tracker_end["current"][j-n_sites]
				tracker_end["current"][j-n_sites] = 0
			end
		end
		
	end

	
	finish_flag = false
	
	for j in n_sites:-1:1
		if (gene[j]==1.) & (gene[j+1]==0.) & (rand(Bernoulli(β*Δt)))
			gene[j+1]=1.
			gene[j]=0.

			if j == n_sites
				finish_flag = true
				tracker_end["current"][1]=1
			end
			
		end
	end

	# entrance of new RNAp
	if (rand(Bernoulli(α*Δt))) & (gene[1]==0.)
		gene[1]=1.
	end

	return gene, finish_flag, tracker_end
	
end

get_t_d(δ, n_end_sites, β2) = 1/δ - (n_end_sites)/β2

get_t_d(params) = get_t_d(params.δ, params.n_end_sites, params.β2)

get_trans_rate(exits, β, Δt) = mean(exits)/β/Δt

get_trans_rate(exits, params) = get_trans_rate(exits, params.β, params.Δt)

"""
Theoretical model for infinite termination rate
"""
function J(α, β, L)
	αc = β/(1+L^(1/2))

	if α<αc
		return α.*(β.-α) ./ (β .+ α.*(L-1))
	else 
		return β./(1 .+L^(1/2)).^2
	end
end