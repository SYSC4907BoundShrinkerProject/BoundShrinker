#Andrew Venus
#November 26, 2014

@everywhere module pointsModule

export makePoints
function makePoints(range,offset,numberOfPoints)
	randomNumberGenerator = MersenneTwister()
	points=Float64[]
	for h= 1:numberOfPoints
		point = ((rand(randomNumberGenerator) * range) + offset)
		push!(points,point)
	end
	return points
end
end

using pointsModule

using JuMP

#Global Variables
#Constants
numberOfThreads=nprocs()
changeSize=0.1
maximiumVariables=1000                      #How many variables the software can support
modelName="500model.jl"                        #The name of the model file.
randomPoints=3000

function main()
	startTime=time_ns()
    include(modelName)
    shrinkBounds()
    endTime=time_ns()
    duruation=endTime-startTime

    #display shrunk bounds
    for i=1:numberOfVariable
        if(lowerBounds[i]>=upperBounds[i])
            println("No bounds have been shrunk for variable x[", i,"]")
        else
            print(lowerBounds[i]," <= x[", i,"] <= ")
            println(upperBounds[i])
        end
    end

    println("Time with ",numberOfThreads," simultaneous executions: ", duruation/1000000000, " seconds")
end


randomNumberGenerator = MersenneTwister()
numberOfVariable=0
numberOfConstriants=0
m = Model()                                 #JuMP model
@defVar(m,x[1:maximiumVariables])           #Varaible array must be declared ahead of time


#make three lists of values for expressions, equality strings and right hand side values
#expressions[i], equalityOrInequalities[i] and rightHandSides[i] all together represent one constraint
equalityOrInequalities = String[]
rightHandSides = Float64[]
expressions=Any[]

#x[i], lowerBounds[i] and upperBounds[i] all together represent one variable bound
lowerBounds=Float64[]
upperBounds=Float64[]

lowestPoint=Float64
highestPoint=Float64

function generatePoints(range,offset)
        #check n random points
        #if none are feasible then cut
        for h= 1:(randomPoints)
            #for each random point you are making, generate a x,y,z,... value
			points=Float64[]
			tempPoints=Float64[]
			refs=Any[]
			
			ref = @spawn makePoints(range,offset,mainVariables)
			push!(refs,ref)
			for j=1:(numberOfThreads-1)
				ref = @spawn makePoints(range,offset,variablesPerThread)
				push!(refs,ref)
			end
			
			tempPoints=fetch(refs[numberOfThreads])
			append!(points,tempPoints)
			for j=1:(numberOfThreads-1)
				tempPoints=fetch(refs[j])
				append!(points,tempPoints)
			end

            if (allConstraintSatisfied(numberOfVariable,points))
                return true
            else
                return false
            end
        end
end

#note that jump only supports <=, >= and =
function addConstraint(expression,equalityOrInequality,rightHandSide)
        global numberOfConstriants+=1
        if (isequal(equalityOrInequality,"<="))
                @addNLConstraint(m, expression <= rightHandSide)
        elseif (isequal(equalityOrInequality,">="))
                @addNLConstraint(m, expression >= rightHandSide)
        elseif (isequal(equalityOrInequality,"="))
                @addNLConstraint(m, expression == rightHandSide)
        end
        push!(equalityOrInequalities,equalityOrInequality)
        push!(rightHandSides,rightHandSide)
        push!(expressions,expression)
end

function addBound(lowerBound,upperBound)
        global numberOfVariable+=1
        @defVar(m, lowerBound <= x[numberOfVariable] <= upperBound )
        push!(lowerBounds,lowerBound)
        push!(upperBounds,upperBound)
end

#checks if a constraint is satisified
#note that jump only supports <=, >= and =
function constraintSatified(equalityOrInequality,rightHandSide,leftHandSide)
    if (isequal(equalityOrInequality,"<="))
            return (leftHandSide <= rightHandSide)
    elseif (isequal(equalityOrInequality,">="))
            return (leftHandSide >= rightHandSide)
    #equality constraint is satisfied if the rightHandSide is between lowest and highest point
    #lowest and hightest points are updated when random points are generated
    elseif (isequal(equalityOrInequality,"="))
            return ((rightHandSide >= lowestPoint) && (rightHandSide <= highestPoint))
    end
end

#checks if all the constraints are satisfied
function allConstraintSatisfied(numberOfVariable,points)
	 for j=1:numberOfVariable
			setValue(x[j],points[j])
	end
    for j=1:numberOfConstriants
              leftHandSide = getValue(expressions[j])

              if (leftHandSide<lowestPoint)
                    global lowestPoint=leftHandSide
              end
              if (leftHandSide>highestPoint)
                    global highestPoint=leftHandSide
              end
              value =  constraintSatified(equalityOrInequalities[j],rightHandSides[j],leftHandSide)
              if (!value)
                     return false
              end
        end
        return true
end




#If a bound is exactly zero then multiplying won't change it.
#In this case you add or subtract a small number instead.
#This number is calculated before hand and is small compared
#to the intial difference between the upper and lower bound.
function findZeroOffset(i)
   difference = upperBounds[i] - lowerBounds[i]
   zeroOffset = difference*changeSize
   if(changeSize<zeroOffset)
           return changeSize
   else
           return zeroOffset
    end
end

#shrinks upper and lower bounds of each variable
function shrinkBounds()
	global variablesPerThread=numberOfVariable/numberOfThreads
	global remainder=numberOfVariable%numberOfThreads
	global mainVariables=variablesPerThread+remainder

    for i=1:numberOfVariable
        zeroOffset = findZeroOffset(i)
        global initialLower=lowerBounds[i]
        global initialUpper=upperBounds[i]
        shrinkUpperBond(i,zeroOffset)
        shrinkLowerBound(i,zeroOffset)
    end
end

#shrinks the upper bound of variable x[i]
function shrinkUpperBond(i,zeroOffset)
    keepGoing=true
    while(keepGoing)
        oldUpper=upperBounds[i]

        #If the bound is exactly zero then multiplying it won't change it.
        #Subtract the zeroOffset instead.
        if(upperBounds[i]==0)
             upperBounds[i]-=zeroOffset;
        else
            upperBounds[i]=upperBounds[i]*(1-changeSize)
        end

        if(upperBounds[i]<=initialLower)
                keepGoing=false
                break
        end

        #random point between 0 and the width of the cut, or (old top bound - new top bound)
        #offset the point to be from the bottom of the cut to the top of the cut
        range=(oldUpper-upperBounds[i])
        offset=(lowerBounds[i] + (upperBounds[i]-lowerBounds[i]))

        global lowestPoint=offset
        global highestPoint=upperBounds[i]

        
        result = generatePoints(range,offset)
        if (result)
                #undo last cut
                upperBounds[i]=oldUpper
                keepGoing=false
                h=randomPoints #break
        else
                keepGoing=true
        end
    end
end

#shrinks the lower bound of variable x[i]
function shrinkLowerBound(i,zeroOffset)
    keepGoing=true
    while(keepGoing)
        oldLower=lowerBounds[i]

        #If the bound is exactly zero then multiplying it won't change it.
        #Add the zeroOffset instead.
        if(lowerBounds[i]==0)
             lowerBounds[i]+=zeroOffset;
        else
            lowerBounds[i]=lowerBounds[i]*(1+changeSize)
        end

        if(lowerBounds[i]>=initialUpper)
                keepGoing=false
                break
        end

        #random point between 0 and the width of the cut, or (new bottom bound - old bottom bound)
        #offset the point to be from the bottom of the cut to the top of the cut
        range=(lowerBounds[i]-oldLower)
        offset=oldLower

        global lowestPoint=offset
        global highestPoint=upperBounds[i]

       result = generatePoints(range,offset)
        if (result)
                #undo last cut
                lowerBounds[i]=oldLower
                keepGoing=false
                h=randomPoints #break
        else
                keepGoing=true
        end
    end
end

main()

