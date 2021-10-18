### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ 1b7dcdce-2907-4770-a788-63c9024749e5
begin
	import Pkg
	Pkg.activate(".")
end

# ╔═╡ c0ed1caa-a3fa-48fb-979f-f1378f190c13
begin
	using Soss, MeasureTheory, ArviZ, SampleChainsDynamicHMC, PyPlot
	using TupleVectors
	using TupleVectors: unwrap, chainvec
	pygui(true)
	PyPlot.svg(true)
end

# ╔═╡ 5516e98c-a934-4e35-90a2-f346ccae4903
begin
	J = 8
	y = [28.0, 8.0, -3.0, 7.0, -1.0, 1.0, 18.0, 12.0]
	σ = [15.0, 10.0, 16.0, 11.0, 9.0, 11.0, 10.0, 18.0]
	schools = [
    	"Choate",
    	"Deerfield",
    	"Phillips Andover",
    	"Phillips Exeter",
    	"Hotchkiss",
   	 	"Lawrenceville",
    	"St. Paul's",
    	"Mt. Hermon",
	];

	nwarmup, nsamples, nchains = 1000, 1000, 4;
end

# ╔═╡ 742872b0-138c-4acd-b40c-a30dead9db59
m1 = Soss.@model (J, σ) begin
    μ ~ Normal(μ=0, σ=5)
    τ ~ HalfCauchy(σ=5)
    θ ~ Normal(μ=μ, σ=τ) |> iid(J)
    y ~ For(1:J) do j
        Normal(μ=θ[j], σ=σ[j])
    end
end;

# ╔═╡ 09add5d0-8dc5-4d08-aba8-634a5cc2b358
m1_prior = prior(m1, :y)

# ╔═╡ efc4ee76-bbb3-4412-913a-7ee21ad88efc
prior_samples = sample(m1_prior(J=J), dynamichmc())

# ╔═╡ cf524ffa-4c43-465e-875d-ad122ffecfcd
priorpred_samples = predict(m1(;J, σ), prior_samples)

# ╔═╡ d61b3404-2566-41a9-86a0-2baaae02c8e3
obs = (;y)

# ╔═╡ a58b1cf6-9265-4ddd-85cf-3cd3c80c6c77
post = m1(;J, σ) | obs

# ╔═╡ 49aabdf1-b3db-4595-a30f-5286188ab4ac
post_samples = sample(m1(;J, σ) | obs, dynamichmc())

# ╔═╡ 93600263-85b8-4052-be8c-dd78a7c662f1
loglik = Float64[logdensity(post, post_samples[j]) for j in eachindex(post_samples)]

# ╔═╡ 5ef23f2f-3ae3-4880-8fd9-ba1500193a45
lik = Soss.withmeasures(likelihood(m1, :y))

# ╔═╡ b6d07442-0082-4563-8649-72908b8ec579
foo=[rand(lik(σ=σ,J=J,θ=θ)) for θ in post_samples.θ]

# ╔═╡ e1fcdd17-6b18-4371-9f29-a64494739216
foo[1]

# ╔═╡ 4babaa5a-b6d9-4d9e-b0e2-d8e7936c50c6
a = TupleVector(foo);

# ╔═╡ 480eeadb-afc8-45d0-b05b-b2654ddbd8c7
a._y_dist

# ╔═╡ 6665d813-1f08-4328-b979-43d7f34deaba
post_samples[1].θ

# ╔═╡ 4b7bcb35-9471-4d28-960c-ca46ac376efc
postpred_samples = predict(m1(;J, σ), post_samples)

# ╔═╡ 52377e59-18a8-4332-ab51-ccf08d219b39
idata = from_samplechains(post_samples
	; prior=prior_samples
	, prior_predictive = priorpred_samples
	, posterior_predictive=postpred_samples
	, log_likelihood = loglik
	, observed_data=obs
	)

# ╔═╡ f72a346f-cce2-4e84-abab-30b48a83b4ba
begin
	plot_trace(idata)
	gcf()
end

# ╔═╡ 941e5494-e834-486c-9cd1-1df4d12419be
begin
	plot_bpv(idata)
	gcf()
end

# ╔═╡ 1992791b-5e9e-4d06-9206-15477afc9ff2
begin
	plot_loo_pit(idata; y=:y, ecdf=true);
	gcf()
end

# ╔═╡ e8036fb2-868f-4a95-a596-d4a1e75678d9
begin
	plot_ess(idata)
	gcf()
end

# ╔═╡ 70a0a84c-3713-47bd-81a6-eeafdf1f1410
plot_hdi(idata)

# ╔═╡ 48cd2cd1-b011-4f74-8ca6-f43bbe0fc41d
begin
	plot_pair(
    	idata;
    	coords=Dict("school" => ["Choate", "Deerfield", "Phillips Andover"]),
    	divergences=true,
	);
	gcf()
end

# ╔═╡ f2fc67a6-15e3-4bb4-ba1a-b03aa016dc6b
plot_kde(idata)

# ╔═╡ 9e2bd496-74c6-4557-89c4-bf8fff124514
begin
	plot_ppc(idata)
	gcf()
end

# ╔═╡ ddda3b8e-d216-452f-835d-af2acb57f53c


# ╔═╡ 7c320ebb-fd53-4c69-8bc9-56136d108ad6
begin
	plot_autocorr(idata)
	gcf()
end

# ╔═╡ 67a22f2d-2504-45fc-9f90-682d4a660a77
begin
	plot_energy(idata)
	gcf()
end

# ╔═╡ fed3c006-d78e-4d42-bf23-e98f4af49da4
begin
	plot_ess(idata)
	gcf()
end

# ╔═╡ 1a8d2b57-500b-463b-b996-86d651f5dc72
begin
	plot_forest(idata)
	gcf()
end

# ╔═╡ 103c9c69-2675-442f-81ad-e4f3c77a247f
begin
	plot_mcse(idata)
	gcf()
end

# ╔═╡ 2e192759-c88c-4970-85d2-e60573d50b6a
begin
	plot_rank(idata);
	gcf()
end

# ╔═╡ b2f9dc02-f3e5-421c-8b83-b8a8a1344e12
loo(idata) # higher is better

# ╔═╡ efe977e4-de7d-41bf-a3bb-95d51dd704c6
begin
	plot_loo_pit(idata; y="y", ecdf=true);
	gcf()
end

# ╔═╡ ed9e35b9-406b-4641-a8c4-a9511248de6f
begin
	plot_density(
    	[idata.posterior_predictive, idata.prior_predictive];
    	data_labels=["Post-pred", "Prior-pred"],
    	var_names=["y"],
	)
	gcf()
end

# ╔═╡ Cell order:
# ╠═1b7dcdce-2907-4770-a788-63c9024749e5
# ╠═c0ed1caa-a3fa-48fb-979f-f1378f190c13
# ╠═5516e98c-a934-4e35-90a2-f346ccae4903
# ╠═742872b0-138c-4acd-b40c-a30dead9db59
# ╠═09add5d0-8dc5-4d08-aba8-634a5cc2b358
# ╠═efc4ee76-bbb3-4412-913a-7ee21ad88efc
# ╠═cf524ffa-4c43-465e-875d-ad122ffecfcd
# ╠═d61b3404-2566-41a9-86a0-2baaae02c8e3
# ╠═a58b1cf6-9265-4ddd-85cf-3cd3c80c6c77
# ╠═49aabdf1-b3db-4595-a30f-5286188ab4ac
# ╠═93600263-85b8-4052-be8c-dd78a7c662f1
# ╠═5ef23f2f-3ae3-4880-8fd9-ba1500193a45
# ╠═b6d07442-0082-4563-8649-72908b8ec579
# ╠═e1fcdd17-6b18-4371-9f29-a64494739216
# ╠═4babaa5a-b6d9-4d9e-b0e2-d8e7936c50c6
# ╠═480eeadb-afc8-45d0-b05b-b2654ddbd8c7
# ╠═6665d813-1f08-4328-b979-43d7f34deaba
# ╠═4b7bcb35-9471-4d28-960c-ca46ac376efc
# ╠═52377e59-18a8-4332-ab51-ccf08d219b39
# ╠═f72a346f-cce2-4e84-abab-30b48a83b4ba
# ╠═941e5494-e834-486c-9cd1-1df4d12419be
# ╠═1992791b-5e9e-4d06-9206-15477afc9ff2
# ╠═e8036fb2-868f-4a95-a596-d4a1e75678d9
# ╠═70a0a84c-3713-47bd-81a6-eeafdf1f1410
# ╠═48cd2cd1-b011-4f74-8ca6-f43bbe0fc41d
# ╠═f2fc67a6-15e3-4bb4-ba1a-b03aa016dc6b
# ╠═9e2bd496-74c6-4557-89c4-bf8fff124514
# ╠═ddda3b8e-d216-452f-835d-af2acb57f53c
# ╠═7c320ebb-fd53-4c69-8bc9-56136d108ad6
# ╠═67a22f2d-2504-45fc-9f90-682d4a660a77
# ╠═fed3c006-d78e-4d42-bf23-e98f4af49da4
# ╠═1a8d2b57-500b-463b-b996-86d651f5dc72
# ╠═103c9c69-2675-442f-81ad-e4f3c77a247f
# ╠═2e192759-c88c-4970-85d2-e60573d50b6a
# ╠═b2f9dc02-f3e5-421c-8b83-b8a8a1344e12
# ╠═efe977e4-de7d-41bf-a3bb-95d51dd704c6
# ╠═ed9e35b9-406b-4641-a8c4-a9511248de6f
