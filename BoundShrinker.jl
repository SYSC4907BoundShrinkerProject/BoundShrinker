#Andrew Venus
#November 26, 2014

using JuMP

#how many model variables there are
numberOfVariable=2

#Global Variables
randomNumberGenerator = MersenneTwister()
reductionFactor=0.9
increaseFactor=1.1
randomPoints=50

#checks if a constriant is satisified
function constriantSatified(equalityType,rightHandSide,expr)
    leftHandSide = getValue(expr)
#    println ("lefthand side: ", leftHandSide)

    if (isequal(equalityType,"<="))
            return (leftHandSide <= rightHandSide)
    elseif (isequal(equalityType,"<"))
            return (leftHandSide < rightHandSide)
    elseif (isequal(equalityType,">="))
            return (leftHandSide >= rightHandSide)
    elseif (isequal(equalityType,">"))
            return (leftHandSide > rightHandSide)
    elseif (isequal(equalityType,"="))
            return (leftHandSide = rightHandSide)
    end
end

#checks if all the constrians are satisfied
function allConstrinatsSatisfied()
    for j=1:numberOfVariable
          value =  constriantSatified(equalityTypes[j],rightHandSides[j],expressions[j])
          if (!value)
                 return false
          end 
    end
    return true
end

#-------------------------------------Model Setup--------------------------------#

#make the JuMP model
#should read model from a file
m = Model()
@defVar(m, 0.5 <= x[1:2] <= 5.0)
@setObjective(m, Max, x[1] +x[2] )
#iteratable expressions seem to be a problem
@defExpr(expression, ((x[1]*x[1]) + (x[2]*x[2])))
@addConstraint(m, expression >= 1.0) #constriant[1] =
@addConstraint(m, expression <= 2.0) #constriant[2] =

#make three lists of values for expressions, equality strings and right hand side values
#expressions[i], equalityTypes[i] and rightHandSides[i] all together represent one constriant
equalityTypes = String[]
rightHandSides = Float64[]
expressions=Any[]
push!(equalityTypes,">=")
push!(rightHandSides,1.0)
push!(expressions,expression)
push!(equalityTypes,"<=")
push!(rightHandSides,2.0)
push!(expressions,expression)

#x[i], lowerBound[i] and upperBound[i] all together represent one variable bound
lowerBound=Float64[]
upperBound=Float64[]
push!(lowerBound,0.5)
push!(upperBound,5.0)
push!(lowerBound,0.5)
push!(upperBound,5.0)

#-----------------Bound Shrinking-------------------------------------------#

#upper bounds
for i=1:numberOfVariable
    keepGoing=true
    #upper bound
    while(keepGoing)
        oldUpper=upperBound[i]
        upperBound[i]=upperBound[i]*reductionFactor

        #random point between 0 and the width of the cut, or (old top bound - new top bound)
        #offset the point to be from the bottom of the cut to the top of the cut
        range=(oldUpper-upperBound[i])
        offset=(lowerBound[i] + (upperBound[i]-lowerBound[i]))

        #check n random points
        #if none are feasible then cut
        for h= 1:randomPoints
            #for each random point you are making, generate a x,y,z,... value
            for j=1:numberOfVariable
                    point = (rand(randomNumberGenerator) * range) + offset
#                    println(point);
                setValue(x[j],point)
            end

            if (allConstrinatsSatisfied())
                  #undo last cut
                  upperBound[i]=oldUpper
                  keepGoing=false
                  h=randomPoints #break
            else
                 keepGoing=true
            end
        end
    end
end


#lower bounds
for i=1:numberOfVariable
    keepGoing=true
    #upper bound
    while(keepGoing)
        oldLower=lowerBound[i]
        lowerBound[i]=lowerBound[i]*increaseFactor

        #random point between 0 and the width of the cut, or (new bottom bound - old bottom bound)
        #offset the point to be from the bottom of the cut to the top of the cut
        range=(lowerBound[i]-oldLower)
        offset=oldLower

        #check n random points
        #if none are feasible then cut
        for h= 1:randomPoints
            #for each random point you are making, generate a x,y,z,... value
            for j=1:numberOfVariable
                    point = (rand(randomNumberGenerator) * range) + offset
                setValue(x[j],point)
            end

            if (allConstrinatsSatisfied())
                  #undo last cut
                  lowerBound[i]=oldLower
                  keepGoing=false
                  h=randomPoints #break
            else
                 keepGoing=true
            end
        end
    end
end

#---------------------------------------Result Display--------------------------#


#display shrunk bounds
print(lowerBound[1])
println(" <= x[1] <= ",upperBound[1])
print(lowerBound[2])
println(" <= x[2] <= ",upperBound[2])
