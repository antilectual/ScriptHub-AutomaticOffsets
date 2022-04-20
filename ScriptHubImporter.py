import json
import os.path
import sys
import re

# global for storing dictionary of output strings (which reduces redundancy in code execution)
outputStringsDict = {}
importedJson = ""
# recursive function that will search for the current indexValue of variablesStringArray and call itself for the rest of the variables in variablesStringArray
# appending strings for final output as it goes
def buildMemoryString(classType, variablesStringArray, indexValue):
    global importedJson
    isFound = False
    if indexValue >= len(variablesStringArray):
        return isFound
    if classType == "System.Object":
        return isFound
    classTypeOriginal = classType
    # could not find the class (Parse Error?)
    if classType not in importedJson:
        subClassCheckString = '+'.join(classType.rsplit('.',1))
        if subClassCheckString not in importedJson:
            appended = ""
            if indexValue+1 < (len(variablesStringArray)):
                appended = "." + '.'.join(variablesStringArray[indexValue+1:])
            variableInQuestion = '.'.join(variablesStringArray[:indexValue]) + ".[" + variablesStringArray[indexValue] + "]" + appended
            print("Class \"" + classType + "\" not found when looking up " + variableInQuestion + ". Continuing...")
            return isFound
        else:
            classType = subClassCheckString 
    # could not find the variable (Check parents?)
    if variablesStringArray[indexValue] not in importedJson[classType]['fields']:
        # blessingsStoreDialogHack
        if classType == "UnityGameEngine.Dialogs.Dialog":
            isFound = buildMemoryString( "CrusadersGame.Dialogs.BlessingsStore.BlessingsStoreDialog", variablesStringArray, indexValue) or buildMemoryString(importedJson[classType]['Parent'], variablesStringArray, indexValue)
        elif not classType == "CrusadersGame.Dialogs.BlessingsStore.BlessingsStoreDialog":
            isFound = buildMemoryString(importedJson[classType]['Parent'], variablesStringArray, indexValue)
        else:
            return
        # After fix found for BlessingsStoreDialog, remove above and replace with original line:
        # found = buildMemoryString(importedJson[classType]['Parent'], variablesStringArray, indexValue)

        # test for case mis-match and print alert if found
        for fieldName in importedJson[classType]['fields']:
            if variablesStringArray[indexValue].lower() == fieldName.lower():
                print("Did you mean \'" + fieldName + "'?")
        # show diagnostic info for failure to find variable
        if not isFound:
            print("Variable " + variablesStringArray[indexValue] + " not found in class " + classType + ". Checking Parent (" + importedJson[classType]['Parent'] + ")...")
            appended = ""
            if indexValue+1 < (len(variablesStringArray)):
                appended = "." + '.'.join(variablesStringArray[indexValue+1:])
            print('.'.join(variablesStringArray[:indexValue]) + ".[" + variablesStringArray[indexValue] + "]" + appended)
        return isFound
    if importedJson[classType]['fields'][variablesStringArray[indexValue]] is not None:
        offset = hex(int(importedJson[classType]['fields'][variablesStringArray[indexValue]]['offset']))
        static = importedJson[classType]['fields'][variablesStringArray[indexValue]]['static']
        classType = importedJson[classType]['fields'][variablesStringArray[indexValue]]['type']
        #TODO: temporary - create better solution
        isFound = True
    else:
        return isFound
    
    isList = False
    isDict = False
    # list/dict test
    # e.g. list<list<CrusadersGame.Dialog>>
    # TODO: check if this ignores <[SOMETYPE]>k__BackingField 
    # TODO: Determine list vs Dict
    # TODO: Transition override dictionary using action?
    tempClassType = classType
    lastClassType = tempClassType
    while True:
        # regular expression to find if part of the string is wrapped in angle brackets
        # match = re.search("(?<=<).*(?=>)", classType)        
        match = re.search("<.*>", tempClassType)
        if match is None:
            break
        isList = True
        lastClassType = tempClassType
        tempClassType = match.group(0)
        # remove angle brackets
        tempClassType = tempClassType[1:-1]
    
    match = re.search("Dictionary", lastClassType)
    if match:
        isList = False
        isDict = True
    classType = tempClassType
    if lastClassType.find("k__BackingField"):
        classType = classType + "_k__BackingField"

    # read class type and pick appropriate type for memory reading
    varType = ""
    if isList:
        varType = "List"
    elif isDict:
        varType = "Dict"
    elif classType == "System.Int32":
        varType = "Int"
    elif classType == "System.Boolean":
        varType = "Char"
    elif classType == "System.String":
        varType = "UTF-16"
    elif classType == "System.Double":
        varType = "Double"
    elif classType == "System.Single":
        varType = ""
    elif classType == "Engine.Numeric.Quad":
        varType = "Quad"                        # actually 2 sequential Int64
    elif classType == "UnityGameEngine.Utilities.ProtectedInt":
        varType = "Int"
        offset = hex(int(offset, 16) + int('0x8', 16))
    else:
        varType = "Int"

    indexValue += 1
    # add new value to dictionary if it doesn't exist, then build next value
    #TODO: Test for static variables
    fullNameOfCurrentVariable = '.'.join(variablesStringArray[:indexValue])
    if fullNameOfCurrentVariable not in outputStringsDict:
        parentValue = '.'.join(variablesStringArray[:indexValue-1]) if indexValue > 1 else classTypeOriginal 
        if static == "false":
            outputStringsDict[fullNameOfCurrentVariable] = "this." + fullNameOfCurrentVariable + " := New GameObjectStructure(this." + parentValue + ",\"" + varType + "\", [" + str(offset) + "])\n"      #Game,, [0x54])
        else:
            outputStringsDict[fullNameOfCurrentVariable] = "this." + fullNameOfCurrentVariable + " := New GameObjectStructure(this." + parentValue + ",\"" + varType + "\", [this.StaticOffset + " + str(offset) + "])\n"      #Game,, [0x54])
        buildMemoryString(classType, variablesStringArray, indexValue) 
    else:
        buildMemoryString(classType, variablesStringArray, indexValue) 
    return isFound

def Import(baseClass, is64Bit = False):
    global importedJson
    # Make sure output is clear before doing an import
    global outputStringsDict
    outputStringsDict = {}
    # read input file with list of offsets to find
    memoryFile = ""
    baseClassParts = baseClass.split('.')
    fileNameBase = baseClassParts[len(baseClassParts) - 1]
    memoryFileLocation = ".\\MemoryLocations_" + fileNameBase + ".txt"
    if os.path.exists(memoryFileLocation):
        memoryFile = open(memoryFileLocation, 'r')
    else:
        print("Could not open " + memoryFileLocation + ". It does not exist.")
        return
    # read lines from text file without newline breaks
    memoryFileLines = memoryFile.read().splitlines() 
    memoryFile.close()
    # remove empty strings
    memoryFileLines = [i for i in memoryFileLines if i != '']
    # remove commented lines
    memoryFileLines = [i for i in memoryFileLines if i[0] != '#']

    # iterate lines and build ahk file to outputStringsDict
    for line in memoryFileLines:
        offsetsLocationStringSplit = line.split(".")
        buildMemoryString(baseClass, offsetsLocationStringSplit, 0)

    # Output to AHK file
    memoryFileString = "; This file was automatically generated by ScriptHubImporter.py\n"
    for k,v in outputStringsDict.items():
        memoryFileString = memoryFileString + v
    version = "64" if is64Bit else "32"
    outputFile = open(".\\IC_" + fileNameBase + version + "_Export.ahk", 'w')
    outputFile.write(memoryFileString)
    outputFile.close()
    print(baseClass + " " + version + "bit output complete.")

# read json file exported from CE ScriptHubExporter addon
memoryStructureLoc = ".\\ScriptHubExport32.json"
if os.path.exists(memoryStructureLoc):
    jsonFile = open(memoryStructureLoc, 'r')
    importedJson = json.load(jsonFile)
    jsonFile.close()
    # get classes object    
    importedJson = importedJson['classes']
    # set the base class starting point
    baseClassType = "CrusadersGame.Defs.CrusadersGameDataSet"
    Import(baseClassType)
    baseClassType = "UnityGameEngine.Dialogs.DialogManager"
    Import(baseClassType)
    baseClassType = "UnityGameEngine.Core.EngineSettings"
    Import(baseClassType)
    baseClassType = "IdleGameManager"
    Import(baseClassType)
    baseClassType = "CrusadersGame.GameSettings"
    Import(baseClassType)
else:
    print("Could not open " + memoryStructureLoc + ". It does not exist.")

# read json file exported from CE ScriptHubExporter addon
memoryStructureLoc = ".\\ScriptHubExport64.json"
if os.path.exists(memoryStructureLoc):
    jsonFile = open(memoryStructureLoc, 'r')
    importedJson = json.load(jsonFile)
    jsonFile.close()
    # get classes object    
    importedJson = importedJson['classes']
    # set the base class starting point
    baseClassType = "CrusadersGame.Defs.CrusadersGameDataSet"
    Import(baseClassType, True)
    baseClassType = "UnityGameEngine.Dialogs.DialogManager"
    Import(baseClassType, True)
    baseClassType = "UnityGameEngine.Core.EngineSettings"
    Import(baseClassType, True)
    baseClassType = "IdleGameManager"
    Import(baseClassType, True)
    baseClassType = "CrusadersGame.GameSettings"
    Import(baseClassType, True)
else:
    print("Could not open " + memoryStructureLoc + ". It does not exist.")