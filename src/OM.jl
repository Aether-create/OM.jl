module OM

import Absyn
import SCode
import DAE
#= Frontend Components =#
import OMBackend
import OMFrontend
import Plots
#= Use DifferentialEquations s.t solvers can be passed in a sensible way=#
using DifferentialEquations
using DiffEqBase
#= Utility packages =#
using ImmutableList
using MetaModelica

#= Auxilary Julia packages =#
import CSV
import DataFrames
import Pkg


"""
  List models that are currently available for direct simulation.
"""
function listAvailableModels()
  println("Lists currently compiled modules...")
  println(OMBackend.availableModels())
end

"""
 Given the name of a model and a specified file.
 Flattens the model and return a Tuple of Flat Modelica and the function cache.
"""
function flattenFM(modelName::String, modelFile::String; scalarize=true)::Tuple
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, scodeProgram, scalarize=scalarize)
  return FM, cache
end

"""
 Given the name of a model,  a specified file and a library
 Flattens the model and return a Tuple of Flat Modelica and the function cache.
"""
function flattenFM(modelName::String, modelFile::String, library::String; scalarize=true)::Tuple
  local p = OMFrontend.parseFile(modelFile)
  if !haskey(OMFrontend.LIBRARY_CACHE, library)
    throw("Library $(library) not loaded")
  end
  local libAsSCode = OMFrontend.LIBRARY_CACHE[library]
  local scodeProgram = OMFrontend.translateToSCode(p)
  scodeProgram = listAppend(libAsSCode, scodeProgram)
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, scodeProgram; scalarize=scalarize)
  return FM, cache
end


function simulate(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0, MSL=false, MSL_VERSION="MSL:3.2.3", solver=:(Rodas5()))
  translate(modelName, modelFile; MSL=MSL, MSL_VERSION=MSL_VERSION)
  OMBackend.simulateModel(modelName; tspan=(startTime, stopTime), solver=solver)
end

function simulate(modelName::String; startTime=0.0, stopTime=1.0, solver=:(Rodas5()))
  OMBackend.simulateModel(modelName; tspan=(startTime, stopTime), solver=solver)
end

function translate(modelName::String, modelFile::String; MSL=false, MSL_VERSION="MSL:3.2.3")
  (dae, cache) = MSL ? OMFrontend.flattenModelWithMSL(modelName, modelFile; MSL_Version=MSL_VERSION) : flattenFM(modelName, modelFile)
  OMBackend.translate(dae)
end

"""
  Resimulates an already compiled model.
  If no compiled model with the specific name it throws an error.
"""
function resimulate(modelName; startTime=0.0, stopTime=1.0, solver=:(Rodas5()))
  try
    OMBackend.resimulateModel(modelName, tspan=(startTime, stopTime), solver=solver)
  catch
    @error("Failed to resimulate: {" * modelName * "} make sure that the model is compiled by calling 'translate'")
    println("Available models are:\n")
    println(availableModels())
  end
end

"""
  Produces the DAE representation given a modelName and a scodeProgram.
"""
function translateModelFromSCode(modelName, scodeProgram::SCode.Program)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

"""
  Plots the Modelica equations like a directed acyclic graph
"""
function plotEquationGraph(b)
  OMBackend.plotGraph(b)
end

"""
  Parse a Modelica file
"""
function parseFile(file)
  OMFrontend.parseFile(file)
end

"""
Given the name of a model as a string and the file of said model as a string.
Translate the model to the SCode representation.
"""
function translateToSCode(modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
end

function toString(flatModel)
  return OMFrontend.toString(flatModel)
end

"""
  Returns the flat Modelica representation as a String.
"""
function generateFlatModelica(modelName::String, file::String; MSL=false, MSL_Version="MSL:4.0.0")
  return MSL ? toString(first(OMFrontend.flattenModelWithMSL(modelName, file; MSL_Version=MSL_Version))) : toString(first(flattenFM(modelName, file)))
end

"""
  Turns on debugging for the backend.
"""
function LogBackend()
  ENV["JULIA_DEBUG"] = "OMBackend"
end

"""
  Turns on debugging for the frontend.
"""
function LogFrontend()
  ENV["JULIA_DEBUG"] = "OMFrontend"
end

"""
Loads the specified MSL version.
Supported versions are:
  MSL_3_2_3,
  MSL_4_0_0
"""
function loadMSL(; MSL_Version)
  OMFrontend.loadMSL(MSL_Version=MSL_Version)
end

end # module
