import json
import os
import sys
import re

from pathlib import Path

# global for storing dictionary of output strings (which reduces redundancy in code execution)
outputStringsDict = {}
exportedJson = ""
effectClassTypeList = []
currentEffectClass = ""

# Save over JSON export with pretty formatting?
prettyFormat = False

# Set to build imports for earlier version of script hub.
isLegacy = False
isWarningWritten = False


# Main
def main():
    global exportedJson
    os.chdir(Path(__file__).resolve().parent)
    memoryStructureLoc = Path(".") / "ScriptHubExport32.json"
    StartImport(memoryStructureLoc, False)
    if memoryStructureLoc.exists() and "value" in exportedJson["CrusadersGame.GameSettings"]["fields"]["MobileClientVersion"]:
        CreateVersionFile(32)
    memoryStructureLoc = Path(".") / "ScriptHubExport64.json"
    StartImport(memoryStructureLoc, True)
    if memoryStructureLoc.exists() and "value" in exportedJson["CrusadersGame.GameSettings"]["fields"]["MobileClientVersion"]:
        CreateVersionFile(64)
    os.system("pause")

# Read json file exported from CE ScriptHubExporter addon and import from files based on types
def StartImport(memFileLoc, is64Bit):
    global exportedJson
    global currentEffectClass
    if not memFileLoc.exists():
        print("Could not open " + str(memFileLoc) + ". It does not exist.")
        return
    Path(".", "Imports", "ActiveEffectHandlers").mkdir(parents=True, exist_ok=True)
    with memFileLoc.open('r') as jsonFile:
        exportedJson = json.load(jsonFile)
    if prettyFormat:
        with memFileLoc.open('w') as jsonFile:
            json.dump(exportedJson, jsonFile, sort_keys=True, indent=4)
    # get classes object
    exportedJson = exportedJson['classes']
    # set the base class starting point (object the base pointer points to)
    # filename is based on the last chunk
    Import(is64Bit)

# Reads file names for files with target variables and builds them into ScriptHub import code (AHK).
def Import(is64Bit = False, isEffectHandler = False):
    global exportedJson
    # Make sure output is clear before doing an import
    global outputStringsDict
    outputStringsDict = {}
    # read input file with list of offsets to find
    memoryFile = ""
    currentBlock = -1
    files = []
    # TODO: create files list - 1 loop base, 1 loop effects
    files = [f for f in os.listdir(Path(".", "Settings_BaseClassTypeList")) if f.endswith(".txt")]
    ImportClasses(is64Bit, files, isBaseTypes = True)
    files = [f for f in os.listdir(Path(".", "Settings_EffectClassTypeList")) if f.endswith(".txt")]
    ImportClasses(is64Bit, files, isBaseTypes = False)
    OutputHandlerIncludeFile(len(files), is64Bit)

# Reads files, parses them, and builds valid variables into ScriptHub import code files (AHK).
def ImportClasses(is64bit, files, isBaseTypes = True):
    global outputStringsDict
    global currentEffectClass
    for f in files:
        if(isBaseTypes):
            memoryFileLocation = Path(".", "Settings_BaseClassTypeList", f)
        else:
            memoryFileLocation = Path(".", "Settings_EffectClassTypeList", f)
        if not memoryFileLocation.exists():
            print("Could not open " + str(memoryFileLocation) + ". It does not exist.")
            continue
        # read lines from text file without newline breaks
        memoryFileLines = memoryFileLocation.read_text().splitlines()
        # remove unused lines (blank/comments)
        memoryFileLines = [i for i in memoryFileLines if isValidLine(i)]
        # ensure an initial class name exists
        if(memoryFileLines[0][0] != '#' or memoryFileLines[0][1] != '!'):
            print("File format invalid in " + str(memoryFileLocation) + ". Class definition header not found.")
            return
        className = ""
        memoryFileBlocks = {}
        # split by #! sections
        for line in memoryFileLines:
            if line[0] == '#' and line[1] == '!':
                className = line[2:].strip()
                if not className in memoryFileBlocks:
                    memoryFileBlocks[className] = []
                else:
                    print("Duplicate class not expected. (" + str(className) + ").")
                continue
            memoryFileBlocks[className].append(line)
        for className, classBlock in memoryFileBlocks.items():

            baseClassParts = className.split('.')
            fileNameBase = baseClassParts[len(baseClassParts) - 1]

            if not isBaseTypes:
                currentEffectClass = className.rsplit('.',1)[-1:][0]
                effectClassTypeList.append(className)

            # iterate lines and build ahk file to outputStringsDict
            for line in classBlock:
                offsetsLocationStringSplit = line.split(".")
                BuildMemoryString(className, offsetsLocationStringSplit, 0, not isBaseTypes ) 
            version = "64" if is64bit else "32"
            OutputImportToFile(fileNameBase, version, not isBaseTypes)
            outputStringsDict = {}
            print(className + " " + version + "bit output complete.")

# Writes outputStringsDict to the appropriate file.
def OutputImportToFile(fileNameBase, version, isEffectHandler):
    # Output to AHK file
    global isWarningWritten
    global isLegacy
    memoryFileString = "; This file was automatically generated by ScriptHubImporter.py\n"
    for k,v in outputStringsDict.items():
        memoryFileString = memoryFileString + v
    if isEffectHandler and not isWarningWritten and isLegacy:
        isWarningWritten = True
        warningMsg = """\nif (!IsObject(IC_ActiveEffectKeyHandler_Class.BuildBrivUnnaturalHasteHandler))\n\tMsgBox % \"Please update ScriptHub to use these imports\""""
        memoryFileString = memoryFileString + warningMsg
    if isEffectHandler and not isWarningWritten and not isLegacy:
        isWarningWritten = True
        warningMsg = """\nif (!IsObject(IC_ActiveEffectKeyHandler_Class.NewHandlerObject))\n\tMsgBox % \"Please update importer and/or imports to match this script.\""""
        memoryFileString = memoryFileString + warningMsg
    extraFolder = "ActiveEffectHandlers" if isEffectHandler else ""
    outputFile = Path(".", "Imports", extraFolder, "IC_" + fileNameBase + version + "_Import.ahk")
    outputFile.write_text(memoryFileString)

# Writes a single include file that includes all other hero handlers.
def OutputHandlerIncludeFile(count, is64Bit):
    if count > 0:
        version = "64" if is64Bit else "32"
        handlerImportsString = "; This file was automatically generated by ScriptHubImporter.py\n"
        for effectClassType in effectClassTypeList:
            baseClassParts = effectClassType.split('.')
            fileNameBase = baseClassParts[len(baseClassParts) - 1]
            # legacy does not use functions
            if isLegacy:
                handlerImportsString = handlerImportsString + "#include %A_LineFile%\\..\\" + "IC_" + fileNameBase + version + "_Import.ahk\n"
            else:
                handlerImportsString = handlerImportsString + "Build" + fileNameBase + "()\n{\n\t"
                handlerImportsString = handlerImportsString + "#include %A_LineFile%\\..\\" + "IC_" + fileNameBase + version + "_Import.ahk\n}\n"
        handlerImportsFile = Path(".", "Imports", "ActiveEffectHandlers", "IC_HeroHandlerIncludes" + version + "_Import.ahk")
        handlerImportsFile.write_text(handlerImportsString)

# recursive function that will search for the current indexValue of variablesStringArray and call itself for the rest of the variables in variablesStringArray
# appending strings for final output as it goes
def BuildMemoryString(classType, variablesStringArray, indexValue, isEffectHandler, checkParent = True, checkSubClass = True): #Iri- need to handle parents and subclasses separately. 
    #Iri notes:
    #Parent - don't check subclasses (different chain of extends)
    #Parent - check parent (chain of extends)
    #Subclass - don't check parent (that's the one we're checking FROM!)
    #Subclass - don't check extends or we could recurse for days; function has the 2 levels we want
    global exportedJson
    isFound = False
    if indexValue >= len(variablesStringArray):
        return isFound
    if classType == "System.Object":
        return isFound
    if classType == "CrusadersGame.Effects.IEffectSource":
        return isFound
    classTypeOriginal = classType
    #fix for timescale using GameManager (IdleGameManager extends GameManager) instead of its starting top level of IdleGameManager
    if classType == "GameManager":
        classTypeOriginal = "IdleGameManager"
    # could not find the class, test for variation with + (e.g. 'CrusadersGame.User.UserModronHandler.ModronCoreData' -> 'CrusadersGame.User.UserModronHandler+ModronCoreData') 
    if classType not in exportedJson:
        #fix for subclasses
        subClassCheckString = '+'.join(classType.rsplit('.',1))
        #fix for ActiveEffectKeyHandler classes that use the new typed BaseActiveEffectKeyHandler
        typedClassCheckString = classType.rsplit('[',1)[0] + "[T]"
        if subClassCheckString in exportedJson:
            classType = subClassCheckString
        elif typedClassCheckString in exportedJson:
            classType = typedClassCheckString
        else:
            # class still not found, lookup failed. Pass.
            NotificationForMissingClass(classType, variablesStringArray, indexValue)
            return isFound        

    # could not find the variable in the class (Check parent classes?)
    if variablesStringArray[indexValue] not in exportedJson[classType]['fields']:
        # Check special cases of collections that include derived objects
        if checkSubClass:
            isFound = SpecialSubClassCaseCheck(classType, variablesStringArray, indexValue, isEffectHandler)
        # otherwise, check the parent class
        if checkParent:
            if isFound or BuildMemoryString(exportedJson[classType]['Parent'], variablesStringArray, indexValue, isEffectHandler, checkParent, checkSubClass= False):
                return True
            else:
                NotificationForMissingFields(classType, variablesStringArray, indexValue)
        return isFound

    # passed existence checks, set variables
    isFound = True
    offset = hex(int(exportedJson[classType]['fields'][variablesStringArray[indexValue]]['offset']))
    static = exportedJson[classType]['fields'][variablesStringArray[indexValue]]['static']
    classType = exportedJson[classType]['fields'][variablesStringArray[indexValue]]['type']

    currClassType = classType
    preMatch = None
    specialType = None
    keyType = None
    valType = None
    abstractMatch = None
    # Collection test:
    match = re.search("[^<]*<", currClassType)
    if match is not None:
        preMatch = match.group(0)[:-1]
        # find inner collection type if exists
        currClassType = FindCollectionValueType(currClassType) # strip <> from type (normal)
        currClassType = FindCollectionValueType(currClassType) # strip <> from type again (collection) OR if not found - not a collection.
        # add a special collection type to value string if the field has multiple collections
        if currClassType is not None:
            keyType = FindCollectionValueType(classType, key = True) # strip <> and select key type in collection
            subType = FindCollectionValueType(classType) # strip <> and select item right of , to find collection value type
            valType = GetMemoryTypeFromClassType(subType)
            match = re.search("[^<]*<", subType) # if there are still brackets, the collection contains other collections.
            if match is not None:
                collectionType = match.group(0)[:-1]
                collectionSubType = FindCollectionValueType(subType)
            specialType = GetMemoryTypeFromClassType(collectionType)
            # output current (Increment indexValue in call)
            AppendToOutput(variablesStringArray, indexValue + 1, classTypeOriginal, static, offset, GetMemoryTypeFromClassType(preMatch), isEffectHandler, keyType, subType)
            indexValue += 1 
            variablesStringArray.insert(indexValue, collectionType.rsplit('.',1)[-1:][0])
            # output subcollection
            AppendToOutput(variablesStringArray, indexValue + 1, classTypeOriginal, static, "", specialType, isEffectHandler, keyType, collectionSubType)
            # build from current + subcollection
            BuildMemoryString(currClassType, variablesStringArray, indexValue + 1, isEffectHandler) 
            return isFound

    elif currClassType in exportedJson:   
        abstractMatch = IsAbstractClass(classToTest = exportedJson[classType]['Parent'])
    if abstractMatch is not None:
        currClassType = abstractMatch[0][:-1]
        innerClassType = exportedJson[classType]['Parent'][len(currClassType)+3:-1] # previous + '`1['
    if preMatch is not None:
        if currClassType is None:
            currClassType = FindCollectionValueType(classType)
        varType = GetMemoryTypeFromClassType(preMatch)
    else:
        varType = GetMemoryTypeFromClassType(currClassType)

    # Fix field name if it includes invalid characters for AHK
    variablesStringArray[indexValue] = SpecialInvalidCharacterInFieldCheck(variablesStringArray, indexValue)

    # True location of int value from ProtectedInt
    if currClassType == "UnityGameEngine.Utilities.ProtectedInt":
        offset = hex(int(offset, 16) + int('0x8', 16))

    if(varType == "List" or varType == "Queue" or varType == "Stack"):
        valType = currClassType
    elif(varType == "Dict"):
        keyType = FindCollectionValueType(classType, key = True)
        valType = FindCollectionValueType(classType)
    elif(varType == "HashSet"):
        keyType = innerClassType if abstractMatch else FindCollectionValueType(classType, key = True)

    indexValue += 1
    AppendToOutput(variablesStringArray, indexValue, classTypeOriginal, static, offset, varType, isEffectHandler, keyType, valType)
    currClassType = classType if abstractMatch else currClassType # reset current class before checking next item in chain.
    BuildMemoryString(currClassType, variablesStringArray, indexValue, isEffectHandler) 
    return isFound

# returns the match if an abstract class is detected, otherwise returns None
def IsAbstractClass(classToTest):  #e.g. CrusadersGame.Effects.BaseActiveEffectKeyHandler`1[T] parent is ActiveEffectKeyHandler 
    match = re.match("[^`1[]*`", classToTest) # match[0] everything until '`1[', match[1] is next set up to next '`1[' or all chars if none.
    return match

def Iri_HandleAbstractClass(subClassParent, baseClass, subClass): #Iri - Handle abstract classes 
    if baseClass.endswith("`1[T]"):
        cName = baseClass.replace("`1[T]","`1[" + subClass + "]") #CrusadersGame.Effects.BaseActiveEffectKeyHandler`1[T] becomes CrusadersGame.Effects.BaseActiveEffectKeyHandler`1[CrusadersGame.Effects.EllywickDeckOfManyThingsHandler]
        return cName==subClassParent
    return baseClass==subClassParent

def GetInnerCollectionType(currClassType):
    # find inner collection type if exists
    currClassType = FindCollectionValueType(currClassType) # strip <> from type (normal)
    currClassType = FindCollectionValueType(currClassType) # strip <> from type again (collection) OR if not found - not a collection.
    return currClassType

# For cases where there is a collection of a base class that can contain objects that may be sub classes of the base class.
# If the object is not found in the base class, check the derived class, but not its parents.
def SpecialSubClassCaseCheck(classType, variablesStringArray, indexValue, isEffectHandler):
    isFound = False
    # TODO: If multiple sub classes have the same field, the wrong one could be selected. Find a method to verify correct sub class is found.
    for subClass in exportedJson:
        if exportedJson[subClass]['Parent'] == classType:
            isFound = BuildMemoryString( subClass, variablesStringArray, indexValue, isEffectHandler, False)
        if isFound:
            return isFound
    return isFound

# For cases where a field name uses reserved characters in AHK code
def SpecialInvalidCharacterInFieldCheck(variablesStringArray, indexValue):
    # AHK Can't handle <> in names, such as k__BackingField
    if variablesStringArray[indexValue].find("k__BackingField") >= 0:
        match = re.search("<.*>", variablesStringArray[indexValue])
        # fix for activeeffectkeyhandlers using k_backingfields
        if variablesStringArray[indexValue] == "<effectKey>k__BackingField":
            return match.group(0)[1:-1]
        return match.group(0)[1:-1] + "_k__BackingField"
    else:
        return variablesStringArray[indexValue]

# Get the type from inside the collection params (inside <>)
def FindCollectionValueType(classType, key = False):
    global exportedJson
    if classType is None:
        return None
    match = re.search("<.*>", classType)
    if match is not None:
        currClassType = match.group(0)
        currClassType = currClassType[1:-1] # trim <> from match edges 
        if key:
            dicClassType = currClassType.split(",",1)[0]   
        else:
            dicClassType = currClassType.split(",",1)[-1:][0]      
        # Special test to check if a value is an enum.
        parentTest = dicClassType.split(".")
        parentTest = ".".join(parentTest[:-1]) + "+" + parentTest[-1]
        if parentTest in exportedJson and 'Parent' in exportedJson[parentTest] and exportedJson[parentTest]['Parent'] == "System.Enum":
            return "System.Enum"
        return dicClassType
    else:
        return None

# When a class is not found, print a messsage displaying the offending class type and variable.
def NotificationForMissingClass(classType, variablesStringArray, indexValue):
    appended = ""
    if indexValue+1 < (len(variablesStringArray)):
        appended = "." + '.'.join(variablesStringArray[indexValue+1:])
    variableInQuestion = '.'.join(variablesStringArray[:indexValue]) + ".[" + variablesStringArray[indexValue] + "]" + appended
    print("Class \"" + classType + "\" not found when looking up " + variableInQuestion + ". Continuing...")

# When a field is not found, print a messsage displaying suggested alternative (if available), as well as the offending offset.
def NotificationForMissingFields(classType, variablesStringArray, indexValue):
    # When the class is still not found, test for case mis-match and print alert if found
    for fieldName in exportedJson[classType]['fields']:
        if variablesStringArray[indexValue].lower() == fieldName.lower():
            print("Did you mean \'" + fieldName + "'?")
            break
    # show diagnostic info for failure to find variable
    print("Variable '" + variablesStringArray[indexValue] + "' not found in class " + classType + ". Checking Parent (" + exportedJson[classType]['Parent'] + ")...")
    appended = ""
    if indexValue+1 < (len(variablesStringArray)):
        appended = "." + '.'.join(variablesStringArray[indexValue+1:])
    print('.'.join(variablesStringArray[:indexValue]) + ".[" + variablesStringArray[indexValue] + "]" + appended)

# Given a class type, return the memory read type to be used.
def GetMemoryTypeFromClassType(classType):
    # read class type and pick appropriate type for memory reading
    # Standard cases:
    varType = None
    if classType == "System.Int32":
        varType = "Int"
    elif classType == "System.Boolean":
        varType = "Char"
    elif classType == "System.String":
        varType = "UTF-16"
    elif classType == "System.Double":
        varType = "Double"
    elif classType == "System.Single":
        varType = "Float"
    elif classType == "System.Int64":
        varType = "Int64"

            # _classMemory - aTypeSize := {    
            #         "UChar":    1, 
            #         "UShort":   2,
            #         "Short":    2
            #         "UInt":     4
            #         "UFloat":   4,
            #         "Int64":    8,
            #         "Double":   8}  
    # Special Cases:        
    elif classType == "Engine.Numeric.Quad":
        varType = "Quad"                        # actually 2 sequential Int64
    elif classType == "UnityGameEngine.Utilities.ProtectedInt":
        varType = "Int"
    elif classType == "System.Collections.Generic.List":
        varType = "List"
    elif classType == "System.Collections.Generic.Dictionary":
        varType = "Dict"
    elif classType == "System.Collections.Generic.HashSet":
        varType = "HashSet"
    elif classType == "System.Collections.Generic.Queue":
        varType = "Queue"
    elif classType == "System.Collections.Generic.Stack":
        varType = "Stack"
    else:
        varType = "Int"
    return varType

# Adds an item to the output strings dictionary if it does not already exist
def AppendToOutput(variablesStringArray, indexValue, classTypeOriginal, static, offset, varType, isEffectHandler, keyType = "", valType = ""):
    global currentEffectClass
    # add new value to dictionary if it is not already there, then build next value

    fullNameOfCurrentVariable = '.'.join(variablesStringArray[:indexValue])
    if isEffectHandler:
        fullNameOfCurrentVariable =  currentEffectClass + "." + fullNameOfCurrentVariable
    if fullNameOfCurrentVariable not in outputStringsDict:
        parentValue = '.'.join(variablesStringArray[:indexValue-1]) if indexValue > 1 else classTypeOriginal 
        if isEffectHandler:
            if indexValue > 1:
                parentValue = '.'.join(variablesStringArray[:indexValue-1])
                parentValue = currentEffectClass + "." + parentValue
            else:
                parentValue = currentEffectClass
        if static == "false" or static == False:
            outputStringsDict[fullNameOfCurrentVariable] = "this." + fullNameOfCurrentVariable + " := New GameObjectStructure(this." + parentValue + ",\"" + varType + "\", [" + str(offset) + "])\n"
            # if varType != "Int" and varType != "UTF-16" and varType != "Char" and varType != "Double" and varType != "Float" and varType != "Quad" :
            if varType == "Dict":
                outputStringsDict[fullNameOfCurrentVariable + "_key"] = "this." + fullNameOfCurrentVariable + "._CollectionKeyType := \"" + keyType + "\"\n"
                outputStringsDict[fullNameOfCurrentVariable + "_value"] = "this." + fullNameOfCurrentVariable + "._CollectionValType := \"" + valType + "\"\n"
            elif ((varType == "List" or varType == "Queue" or varType == "Stack")  and valType is not None):
                outputStringsDict[fullNameOfCurrentVariable + "_key"] = "this." + fullNameOfCurrentVariable + "._CollectionValType := \"" + valType + "\"\n"
            elif varType == "HashSet":
                outputStringsDict[fullNameOfCurrentVariable + "_key"] = "this." + fullNameOfCurrentVariable + "._CollectionKeyType := \"" + keyType + "\"\n"
        else:
            outputStringsDict[fullNameOfCurrentVariable] = "this." + fullNameOfCurrentVariable + " := New GameObjectStructure(this." + parentValue + ",\"" + varType + "\", [this.StaticOffset + " + str(offset) + "])\n"

# Creates a game version file.
def CreateVersionFile(architecture):
    # Output to AHK file
    version = exportedJson["CrusadersGame.GameSettings"]["fields"]["MobileClientVersion"]["value"]
    versionPostFix = ''
    if "value" in exportedJson["CrusadersGame.GameSettings"]["fields"]["VersionPostFix"]:
        versionPostFix = exportedJson["CrusadersGame.GameSettings"]["fields"]["VersionPostFix"]["value"]
    versionFileString = "; This file was automatically generated by ScriptHubImporter.py\n"
    versionFileString = versionFileString + "global g_ImportsGameVersion" + str(architecture) + " := " + str(version) + "\n"
    versionFileString = versionFileString + "global g_ImportsGameVersionPostFix" + str(architecture) + " := \"" + str(versionPostFix) + "\""
    if len(sys.argv) >= 2 and sys.argv[1] != "":
        versionFileString = versionFileString + "\nglobal g_ImportsGameVersionPlatform" + str(architecture) + " := \"" + str(sys.argv[1]) + "\""
    outputFile = Path(".", "Imports", "IC_GameVersion" + str(architecture) + "_Import.ahk")
    outputFile.write_text(versionFileString)

# Only allows a text line that is not blank and is not a comment.
def isValidLine(line: str):
        line = line.strip()
        # remove blank lines
        if line == '':
            return False
        # remove commented lines
        if line[0] == "#":
            # except commented bang lines - special use
            if line[0:2] == "#!":
                return True
            return False
        return True

if __name__ == "__main__":
    main()
