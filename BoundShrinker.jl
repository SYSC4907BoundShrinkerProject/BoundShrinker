#Andrew Venus
#November 26, 2014

using JuMP

#Global Variables
#Constants
reductionFactor=0.9
increaseFactor=1.1
randomPoints=50
maximiumVariables=100                       #How many variables the software can support
modelName="model2.jl"                       #The name of the model file.

randomNumberGenerator = MersenneTwister()
numberOfVariable=0
m = Model()                                 #JuMP model
@defVar(m,x[1:maximiumVariables])           #Varaible array must be declared ahead of time

#make three lists of values for expressions, equality strings and right hand side values
#expressions[i], equalityTypes[i] and rightHandSides[i] all together represent one constriant
equalityTypes = String[]
rightHandSides = Float64[]
expressions=Any[]

#x[i], lowerBounds[i] and upperBounds[i] all together represent one variable bound
lowerBounds=Float64[]
upperBounds=Float64[]

lowestPoint=Float64
highestPoint=Float64

#checks if a constriant is satisified
#note that jump only supports <=, >= and =
function constriantSatified(equalityType,rightHandSide,leftHandSide)
    if (isequal(equalityType,"<="))
            return (leftHandSide <= rightHandSide)
    elseif (isequal(equalityType,">="))
            return (leftHandSide >= rightHandSide)
    #equality constriant is satisfied if the rightHandSide is between lowest and highest point
    #lowest and hightest points are updated when random points are generated
    elseif (isequal(equalityType,"="))
            return ((rightHandSide >= lowestPoint) && (rightHandSide <= highestPoint))
    end
end

#checks if all the constrians are satisfied
function allConstrinatsSatisfied()
    for j=1:numberOfVariable
          leftHandSide = getValue(expressions[j])

          if (leftHandSide<lowestPoint)
                global lowestPoint=leftHandSide
          end
          if (leftHandSide>highestPoint)
                global highestPoint=leftHandSide
          end
          value =  constriantSatified(equalityTypes[j],rightHandSides[j],leftHandSide)
          if (!value)
                 return false
          end
    end
    return true
end

#note that jump only supports <=, >= and =
function addConstraint(expression,equalityType,rightHandSide)
        if (isequal(equalityType,"<="))
                @addConstraint(m, expression <= rightHandSide)
        elseif (isequal(equalityType,">="))
                @addConstraint(m, expression >= rightHandSide)
        elseif (isequal(equalityType,"="))
                @addConstraint(m, expression == rightHandSide)
        end
        push!(equalityTypes,equalityType)
        push!(rightHandSides,rightHandSide)
        push!(expressions,expression)
end

function addBound(lowerBound,upperBound)
        global numberOfVariable+=1
        @defVar(m, lowerBound <= x[numberOfVariable] <= upperBound )
        push!(lowerBounds,lowerBound)
        push!(upperBounds,upperBound)
end

#shrinks upper and lower bounds of each variable
function shrinkBounds()
    for i=1:numberOfVariable
        upperReference = @spawn shrinkUpperBond(i)
        lowerReference = @spawn shrinkLowerBound(i)
        wait(upperReference)
        wait(lowerReference)
    end
end

#shrinks the upper bound of variable x[i]
function shrinkUpperBond(i)
    keepGoing=true
    #upper bound
    while(keepGoing)
        oldUpper=upperBounds[i]
        upperBounds[i]=upperBounds[i]*reductionFactor

        #random point between 0 and the width of the cut, or (old top bound - new top bound)
        #offset the point to be from the bottom of the cut to the top of the cut
        range=(oldUpper-upperBounds[i])
        offset=(lowerBounds[i] + (upperBounds[i]-lowerBounds[i]))

        global lowestPoint=offset
        global highestPoint=upperBounds[i]

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
                  upperBounds[i]=oldUpper
                  keepGoing=false
                  h=randomPoints #break
            else
                 keepGoing=true
            end
        end
    end
end

#shrinks the lower bound of variable x[i]
function shrinkLowerBound(i)
    keepGoing=true
    #upper bound
    while(keepGoing)
        oldLower=lowerBounds[i]
        lowerBounds[i]=lowerBounds[i]*increaseFactor

        #random point between 0 and the width of the cut, or (new bottom bound - old bottom bound)
        #offset the point to be from the bottom of the cut to the top of the cut
        range=(lowerBounds[i]-oldLower)
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
                  lowerBounds[i]=oldLower
                  keepGoing=false
                  h=randomPoints #break
            else
                 keepGoing=true
            end
        end
    end
end

function main()
    include(modelName)
    shrinkBounds()
    #display shrunk bounds
    for i=1:numberOfVariable
        print(lowerBounds[i]," <= x[", i,"] <= ")
        println(upperBounds[i])
    end
end
main()
