﻿using Interpolations
using Mimi

# Moore et al Agriculture component (with linear interpolation between gtap temperature points)
@defcomp Agriculture begin

    fund_regions = Index()

    gdp90 = Parameter(index=[fund_regions])
    income = Parameter(index=[time,fund_regions])
    pop90 = Parameter(index=[fund_regions])
    population = Parameter(index=[time,fund_regions])

    agrish = Variable(index=[time,fund_regions])     # agricultural share of the economy
    agrish0 = Parameter(index=[fund_regions])        # initial share 
    agel = Parameter(default = 0.31)            # elasticity

    agcost = Variable(index=[time,fund_regions])     # This is the main damage variable (positive means benefits)

    temp = Parameter(index=[time])              # Moore et al uses global temperature (original FUND ImpactAgriculture component uses regional temperature)

    # Moore additions:

    AgLossGTAP = Variable(index=[time,fund_regions]) # Moore's fractional loss (intermediate variable for calculating agcost)

    gtap_spec = Parameter{String}()
    gtap_df_all = Parameter(index = [fund_regions, 3, 5])
    gtap_df = Variable(index=[fund_regions, 3])  # three temperature data points per region

    floor_on_damages = Parameter{Bool}(default = true)
    ceiling_on_benefits = Parameter{Bool}(default = false)

    function run_timestep(p, v, d, t)

        # Access which of the 5 possible DFs to use for the damage function
        gtap_idx = findfirst(isequal(p.gtap_spec), gtaps)
        gtap_idx === nothing ? error("Unknown GTAP dataframe specification: \"$(p.gtap_spec)\". Must be one of the following: $gtaps") : nothing
        v.gtap_df[:, :] = p.gtap_df_all[:, :, gtap_idx]
                
        for r in d.fund_regions
            ypc = p.income[t, r] / p.population[t, r] * 1000.0
            ypc90 = p.gdp90[r] / p.pop90[r] * 1000.0

            v.agrish[t, r] = p.agrish0[r] * (ypc / ypc90)^(-p.agel)

            # Interpolate for p.temp, using the three gtap welfare points with the additional origin (0,0) point
            loss = linear_interpolate([0, v.gtap_df[r, :]...], collect(0:3), p.temp[t])
            loss = p.floor_on_damages ? max(-100, loss) : loss
            loss = p.ceiling_on_benefits ? min(100, loss)  : loss
            v.AgLossGTAP[t, r] = loss / 100

            # Calculate total cost for the ag sector based on the percent loss
            v.agcost[t, r] = p.income[t, r] * v.agrish[t, r] * v.AgLossGTAP[t, r]  # take out the -1 from original fund component here because damages are the other sign in Moore data
        end
    end
end
