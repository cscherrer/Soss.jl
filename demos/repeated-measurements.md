---
author: "Chad Scherrer"
title: "Soss Example: Industrial Quality Control"
---


This is a very simplified example of how Soss might be used for quality control of an industrial process. To make things concrete, let's say we observe data like this:

````
5×14 Named Array{Int64,2}
Reviewer ╲ Sample │  1   2   3   4   5   6   7   8   9  10  11  12  13  14
──────────────────┼───────────────────────────────────────────────────────
1                 │  0   0   0   0   1   1   1   0   0   0   1   0   0   0
2                 │  1   0   1   0   1   1   1   0   1   0   1   0   0   1
3                 │  0   0   0   0   1   0   1   0   1   0   1   0   0   0
4                 │  0   0   0   0   0   0   1   0   0   0   1   0   0   0
5                 │  0   1   0   0   1   1   1   0   0   1   1   0   1   1
````





Here we have 20 samples, each being "reviewed" by 5 independent reviewers, with a `1` indicating a reviewer rejecting a given sample as defective. Our goal is to estimate the probability of defectiveness for each sample.

On the surface, this is simple enough, and it might seem that all we really need is the counts for each column. Unfortunately, that's not quite right. 

Each review has some _false positive_ and _true positive_ rate,

$$
\begin{aligned}
\text{FPR} &= P(\text{rejected } | \text{ not defective}) \\
\text{TPR} &= P(\text{rejected } | \text{ defective}) 
\end{aligned}
$$

So for example, if we have a sample that gets some rejections, our assessment needs to depend on _which reviewers made the rejections_. If those rejections often disagree with their peers, we might be more likely to expect their rejecitons to be false positives. A similar analysis can account for false negatives.

If we have `r` reviewers for `s` samples, we can model this problem in Soss as

````julia
m = @model r,s begin
    # Probability of defect for each sample
    p_bad ~ Beta(1,3) |> iid(s)

    # Realization of sample quality
    bad ~ For(s) do j
            Bernoulli(p_bad[j])
        end
    
    # FPR and TPR for each reviewer
    fpr ~ Beta(2,10) |> iid(r)
    tpr ~ Beta(10,2) |> iid(r)

    # Caching reviewer probabilities (need to optimize this away later)
    pos_rate = hcat(fpr, tpr)

    # Quality assessments, indexed by reviewer and sample
    y ~ For(r,s) do i,j
            Bernoulli(pos_rate[i, bad[j] + 1])
        end
end
````





The `logdensity` for this model is surprisingly complex, requiring a summation of the following terms:

````
r                           
      ___                          
      ╲                            
       ╲                           
1.0⋅   ╱    log(1.0 - 1.0⋅tpr[_j1])
      ╱                            
      ‾‾‾                          
    _j1 = 1                        
------------------------------------------------------

       r                 
      ___                
      ╲                  
       ╲                 
1.0⋅   ╱    log(fpr[_j1])
      ╱                  
      ‾‾‾                
    _j1 = 1              
------------------------------------------------------

       s                             
      ___                            
      ╲                              
       ╲                             
2.0⋅   ╱    log(1.0 - 1.0⋅p_bad[_j1])
      ╱                              
      ‾‾‾                            
    _j1 = 1                          
------------------------------------------------------

       r                           
      ___                          
      ╲                            
       ╲                           
9.0⋅   ╱    log(1.0 - 1.0⋅fpr[_j1])
      ╱                            
      ‾‾‾                          
    _j1 = 1                        
------------------------------------------------------

       r                 
      ___                
      ╲                  
       ╲                 
9.0⋅   ╱    log(tpr[_j1])
      ╱                  
      ‾‾‾                
    _j1 = 1              
------------------------------------------------------

1.1⋅s
------------------------------------------------------

9.4⋅r
------------------------------------------------------

        s                                      
       ___                                     
       ╲                                       
        ╲                                      
-1.0⋅   ╱    log(1.0 - 1.0⋅p_bad[_j1])⋅bad[_j1]
       ╱                                       
       ‾‾‾                                     
     _j1 = 1                                   
------------------------------------------------------

        r       s                                                          
       ___     ___                                                         
       ╲       ╲                                                           
        ╲       ╲                                                          
-1.0⋅   ╱       ╱    log(1.0 - 1.0⋅pos_rate[_j1, bad[_j2] + 1])⋅y[_j1, _j2]
       ╱       ╱                                                           
       ‾‾‾     ‾‾‾                                                         
     _j1 = 1 _j2 = 1                                                       
------------------------------------------------------

   s                            
  ___                           
  ╲                             
   ╲                            
   ╱    log(p_bad[_j1])⋅bad[_j1]
  ╱                             
  ‾‾‾                           
_j1 = 1                         
------------------------------------------------------

   s                             
  ___                            
  ╲                              
   ╲                             
   ╱    log(1.0 - 1.0⋅p_bad[_j1])
  ╱                              
  ‾‾‾                            
_j1 = 1                          
------------------------------------------------------

   r       s                                                
  ___     ___                                               
  ╲       ╲                                                 
   ╲       ╲                                                
   ╱       ╱    log(pos_rate[_j1, bad[_j2] + 1])⋅y[_j1, _j2]
  ╱       ╱                                                 
  ‾‾‾     ‾‾‾                                               
_j1 = 1 _j2 = 1                                             
------------------------------------------------------

   r       s                                              
  ___     ___                                             
  ╲       ╲                                               
   ╲       ╲                                              
   ╱       ╱    log(1.0 - 1.0⋅pos_rate[_j1, bad[_j2] + 1])
  ╱       ╱                                               
  ‾‾‾     ‾‾‾                                             
_j1 = 1 _j2 = 1                                           
------------------------------------------------------
````





<!--
using BenchmarkTools
@btime logdensity_def(m(),truth)
@btime logdensity_def(m(),truth, codegen)

f1 = Soss._codegen(m, true);
f2 = Soss._codegen(m,false);

@btime f1((),truth)
@btime f2((),truth)

codegen(m(),truth)



logdensity_def(m(), merge(truth, (p_bad=shuffle(truth.p_bad),)), codegen)


@time result = dynamicHMC(m(), (y=truth.y,), codegen) ;

# result = @time advancedHMC(m(), (y=truth.y,))

pairs(truth)
result |> particles |> pairs

-->
