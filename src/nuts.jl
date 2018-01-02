function nuts(θ0, δ, L, ∇L, L∇L=θ->(L(θ),∇L(θ)), M=100, Madapt=M, verbose=true, Δ_max=1000)
  doc"""
    - θ0      : initial model parameter
    - δ       : desirable average accept rate
    - L       : likelihood function
    - ∇L      : gradient of L
    - L∇L     : function to compute both L and ∇L, ideally in one pass
    - M       : sample number
    - Madapt  : number of samples for step size adaptation
    - verbose : whether to show log
  """

  function leapfrog(θ, r, ϵ)
    doc"""
      - θ : model parameter
      - r : momentum variable
      - ϵ : leapfrog step size
    """
    r̃ = r + 0.5 * ϵ * ∇L(θ)
    θ̃ = θ + ϵ * r̃
    r̃ = r̃ + 0.5 * ϵ * ∇L(θ̃)
    return θ̃, r̃
  end

  function find_reasonable_ϵ(θ)
    ϵ, r = 1, randn(length(θ))
    θ′, r′ = leapfrog(θ, r, ϵ)

    # This trick prevents the log-joint or its graident from being infinte
    # Ref: code start from Line 111 in https://github.com/mfouesneau/NUTS/blob/master/nuts.py
    # QUES: will this lead to some bias of the sampler?
    (l,g) = L∇L(θ′)
    while isinf(l) || any(isinf.(g))
      ϵ = ϵ * 0.5
      θ′, r′ = leapfrog(θ, r, ϵ)
      (l,g) = L∇L(θ′)
    end

    a = 2 * (exp(L(θ′) - 0.5 * dot(r′, r′)) / exp(L(θ) - 0.5 * dot(r, r)) > 0.5) - 1
    while (exp(L(θ′) - 0.5 * dot(r′, r′)) / exp(L(θ) - 0.5 * dot(r, r)))^float(a) > 2^float(-a)
      ϵ = 2^float(a) * ϵ
      θ′, r′ = leapfrog(θ, r, ϵ)
    end
    return ϵ
  end

  function build_tree(θ, r, u, v, j, ϵ, θ0, r0)
    doc"""
      - θ   : model parameter
      - r   : momentum variable
      - u   : slice variable
      - v   : direction ∈ {-1, 1}
      - j   : depth of tree
      - ϵ   : leapfrog step size
      - θ0  : initial model parameter
      - r0  : initial mometum variable
    """
    if j == 0
      # Base case - take one leapfrog step in the direction v.
      θ′, r′ = leapfrog(θ, r, v * ϵ)
      # NOTE: this trick prevents the log-joint or its graident from being infinte
      (l,g) = L∇L(θ′)
      while isinf(l) || any(isinf.(g))
        ϵ = ϵ * 0.5
        θ′, r′ = leapfrog(θ, r, ϵ)
        (l,g) = L∇L(θ′)
      end

      n′ = u <= exp(L(θ′) - 0.5 * dot(r′, r′))
      s′ = u < exp(Δ_max + L(θ′) - 0.5 * dot(r′, r′))
      return θ′, r′, θ′, r′, θ′, n′, s′, min(1, exp(L(θ′) - 0.5 * dot(r′, r′) - L(θ0) + 0.5 * dot(r0, r0))), 1
    else
      # Recursion - build the left and right subtrees.
      θm, rm, θp, rp, θ′, n′, s′, α′, n′_α = build_tree(θ, r, u, v, j - 1, ϵ, θ0, r0)
      if s′ == 1
        if v == -1
          θm, rm, _, _, θ′′, n′′, s′′, α′′, n′′_α = build_tree(θm, rm, u, v, j - 1, ϵ, θ0, r0)
        else
          _, _, θp, rp, θ′′, n′′, s′′, α′′, n′′_α = build_tree(θp, rp, u, v, j - 1, ϵ, θ0, r0)
        end
        if rand() < n′′ / (n′ + n′′)
          θ′ = θ′′
        end
        α′ = α′ + α′′
        n′_α = n′_α + n′′_α
        s′ = s′′ & (dot(θp - θm, rm) >= 0) & (dot(θp - θm, rp) >= 0)
        n′ = n′ + n′′
      end
      return θm, rm, θp, rp, θ′, n′, s′, α′, n′_α
    end
  end

  θs = Array{Array}(M + 1)

  θs[1], ϵ = θ0, find_reasonable_ϵ(θ0)
  μ, γ, t_0, κ = log(10 * ϵ), 0.05, 10, 0.75
  ϵ̄, H̄ = 1, 0

  if verbose println("[NUTS] start sampling for $M samples with inital ϵ=$ϵ") end

  for m = 1:M
    if verbose print('.') end
    r0 = randn(length(θ0))
    u = rand() * exp(L(θs[m]) - 0.5 * dot(r0, r0)) # Note: θ^{m-1} in the paper corresponds to
                                                   #       `θs[m]` in the code
    θm, θp, rm, rp, j, θs[m + 1], n, s = θs[m], θs[m], r0, r0, 0, θs[m], 1, 1
    α, n_α = NaN, NaN
    while s == 1
      v = rand([-1, 1])
      if v == -1
        θm, rm, _, _, θ′, n′, s′, α, n_α = build_tree(θm, rm, u, v, j, ϵ, θs[m], r0)
      else
        _, _, θp, rp, θ′, n′, s′, α, n_α = build_tree(θp, rp, u, v, j, ϵ, θs[m], r0)
      end
      if s′ == 1
        if rand() < min(1, n′ / n)
          θs[m + 1] = θ′
        end
      end
      n = n + n′
      s = s′ & (dot(θp - θm, rm) >= 0) & (dot(θp - θm, rp) >= 0)
      j = j + 1
    end
    if m + 1 <= Madapt + 1
      # NOTE: H̄ goes to negative when δ - α / n_α < 0
      H̄ = (1 - 1 / (m + t_0)) * H̄ + 1 / (m + t_0) * (δ - α / n_α)
      ϵ = exp(μ - sqrt(m) / γ * H̄)
      ϵ̄ = exp(m^float(-κ) * log(ϵ) + (1 - m^float(-κ)) * log(ϵ̄))
    else
      ϵ = ϵ̄
    end
  end

  if verbose println() end
  if verbose println("[NUTS] sampling complete with final apated ϵ = $ϵ") end

  return θs
end
