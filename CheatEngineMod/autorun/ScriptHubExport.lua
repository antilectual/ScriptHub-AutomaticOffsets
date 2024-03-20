-- Creates a table of assemblies which each have a table of all of their classes in the global variable classTable
function PreComputeClasses()
  if (monopipe==nil)  then
    LaunchMonoDataCollector()
  end
  local classTable = {}
  local assemblies=mono_enumAssemblies()
  for i=1, #assemblies do
    local assembly = mono_getImageFromAssembly(assemblies[i])
    local assemblyName = mono_image_get_name(assembly)
    classTable[assemblyName] = {}
    classTable[assemblyName]["image"] = assembly
    classTable[assemblyName]["classes"] = {}
    local classes = mono_image_enumClasses(assembly)
    classTable[assemblyName]["class_count"] = #classes
    for classIndex=1, #classes do
      local name = mono_class_getFullName(classes[classIndex].class) -- classes[classIndex].namespace.."."..classes[classIndex].classname
      if name==nil or name=='' then
        name=classes[classIndex].classname
        if name==nil or name=='' then
          name='<unnamed>'
        end
      end
      if name~=nil and name~='' and name~='<unnamed>' and not string.find(name, "<") then
        classTable[assemblyName]["classes"][name] = classes[classIndex]
        classTable[assemblyName]["classes"][name].fqname = name
      end
    end
  end
  return classTable
end

function ScriptHubAddMenuItem()
  local mfm=getMainForm().Menu
  local miSHTopMenuItem
  
  if mfm then
    local mi
    miSHTopMenuItem=createMenuItem(mfm)
    mfm.Items.insert(mfm.Items.Count-1, miSHTopMenuItem) --add it before help
    mi=createMenuItem(miSHTopMenuItem)
    mi.Caption=translate("Export")
    mi.OnClick=monoform_miSaveClickTargeted
    mi.Name='miScriptHubExport'
    miSHTopMenuItem.Add(mi)
  end
  miSHTopMenuItem.miScriptHubExport.Visible=true
  miSHTopMenuItem.Caption=translate("Script Hub")
end

function ScriptHubExport()
  local classTable = PreComputeClasses()
  if (monopipe==nil)  then
    LaunchMonoDataCollector()
  end
  local assemblyNames = {}
  assemblyNames[1] = "Assembly-CSharp"
  assemblyNames[2] = "Assembly-CSharp.dll"
  local classes = nil
  local i, assemblyIndex
  -- Find first working assembly
  for i = 1, #assemblyNames do
    classes = classTable[assemblyNames[i]]["classes"]
    if (classes~=nil) and (classes~=0) and (classes~={}) then
      assemblyIndex = i
      break
    end
  end
  local stopValue = classTable[assemblyNames[assemblyIndex]]["class_count"]
  local outputString = {}
  outputString[#outputString+1] = "{\"classes\" : {"
  local builtJSON = {}
  for k,v in pairs(classes) do
    --print(classes[i].fqname)
    -- Only continue if the class has a valid name note: short circuit eval works in LUA
    if k~=nil and k~='' and k~='<unnamed>' and not string.find(k, "<") then
      local classData = mono_findClass_ScriptHub(classTable, k, assemblyNames[assemblyIndex]) -- retrieve the class object reference (not a string)
      local fields = mono_class_enumFields_ScriptHub(classData.class) -- 2nd parameter is whether to include offsets from parent classes
      local parent = mono_class_getParent(classData.class)
      local currentJSON = BuildJsonFromFields(classData, fields, parent)
      if currentJSON~=nil then
        outputString[#outputString+1] = currentJSON
        outputString[#outputString+1] = ","
      end
    end
  end
  -- test in case the last classes read was nil/empty/unamed or <> and didn't add a new object as expected
  if(outputString[#outputString] == ',') then
    table.remove(outputString, #outputString)
  end
  outputString[#outputString+1] = "}}"
  local fullJSONOutput = table.concat(outputString)
  -- local current_dir=io.popen"cd":read'*l'.."\\"
  -- print("Export to "..current_dir..filename.." complete. Last: "..tostring(value)..". Stop value: ".. tostring(stopValue))
  print("[Class Details] - Stop value: ".. tostring(stopValue))
  return table.concat(outputString)
end

function mono_class_enumFields_ScriptHub(class)
  local classfield;
  local index=1;
  local fields={}

  if monopipe==nil then return fields end

  monopipe.lock()
  monopipe.writeByte(MONOCMD_ENUMFIELDSINCLASS)
  monopipe.writeQword(class)

  repeat
    classfield=monopipe.readQword()
    if (classfield~=nil) and (classfield~=0) then
      local namelength;
      fields[index]={}
      fields[index].field=classfield
      fields[index].type=monopipe.readQword()
      fields[index].monotype=monopipe.readDword()
      fields[index].parent=monopipe.readQword()
      fields[index].offset=monopipe.readDword()
      fields[index].flags=monopipe.readDword()
      fields[index].isConst=(bAnd(fields[index].flags, FIELD_ATTRIBUTE_LITERAL)) ~= 0
      fields[index].isStatic=(bAnd(fields[index].flags, bOr(FIELD_ATTRIBUTE_STATIC, FIELD_ATTRIBUTE_HAS_FIELD_RVA))) ~= 0 --check mono for other fields you'd like to test
      namelength=monopipe.readWord();
      fields[index].name=monopipe.readString(namelength);
      namelength=monopipe.readWord();
      fields[index].typename=monopipe.readString(namelength);
      index=index+1
    end
  until (classfield==nil) or (classfield==0)

  if monopipe then
    monopipe.unlock()
  end

  return fields
end

--searches all images for a specific class
function mono_findClass_ScriptHub(classTable, k, assemblyName)
  local currentItem = classTable[assemblyName]["classes"][k]
  local namespace = currentItem.namespace
  local classname = currentItem.classname
  local result = 0
  if classTable==nil then return nil end
  --local lookupName = namespace.."."..classname
  if currentItem ~= nil and currentItem ~= 0 then
    return currentItem
  end
  --for k,v in pairs(classTable) do
  result=mono_image_findClass(classTable[assemblyName]["image"], namespace, classname)
  if (result~=0) then
    local classData = {}
    classData.class = result
    classData.fqname = mono_class_getFullName(result)
    return result
  end
  return nil
end

function monoform_miSaveClickTargeted(sender)
  local saveDialog=createSaveDialog()
  saveDialog.Title=translate('Save as... (Export will take several minutes)')
  saveDialog.DefaultExt='json'
  saveDialog.Filter=translate('JSON files (*.json )|*.json')
  saveDialog.Options='['..string.sub(string.sub(saveDialog.Options,2),1,#saveDialog.Options-2)..',ofOverwritePrompt'..']'
  if saveDialog.Execute() then
    local clockA = os.clock()
    local outputString = ScriptHubExport()
    if (outputString == nil) or (outputString == '') then
      return
    end
    ScritpHubWriteToFile(saveDialog.Filename, outputString)
    print("Export to "..saveDialog.Filename.." complete.")
    print("Total Elapsed time: "..tostring(os.clock()-clockA))
  end
end

function ScriptHubReadStaticValue(field, classData)
  local staticAddr = mono_class_getStaticFieldAddress(classData.class, nil)
  if field.typename == 'System.Int32' then
    return readInteger(staticAddr + field.offset)
  elseif field.typename == 'System.String' then
    local lenLocOffset = 0x8
    local strLocOffset = 0xC
    if targetIs64Bit() then
      lenLocOffset = 0x10
      strLocOffset = 0x14
    end
    length=readInteger(readPointer(staticAddr + field.offset)+lenLocOffset)
    if length == nil then
       return nil
    else
       return readString(readPointer(staticAddr + field.offset)+strLocOffset,length*2,true)
    end
  else
    return nil
  end
end

-- Build JSON string from fields
function BuildJsonFromFields(classData, fields, parent)
  local variableValuesTable = {["CrusadersGame.GameSettings.MobileClientVersion"] = 1, ["CrusadersGame.GameSettings.VersionPostFix"] = 1, ["CrusadersGame.GameSettings.Platform"] = 1}
  if fields ~= nil and #fields > 0 then
    local outputString = {}
    local tempClass = classData
    tempClass.fields = fields
    outputString[#outputString+1] = "\""..tempClass.fqname.."\" : {\"ShortName\": \""..tempClass.classname.."\","
    if parent ~= nil then
      local parentName = mono_class_getFullName(parent)
      outputString[#outputString+1] = "\"Parent\": \""..parentName.."\","
    end
    outputString[#outputString+1] = " \"fields\" : {"
    for j=1, #tempClass.fields do
      outputString[#outputString+1] = "\""..tempClass.fields[j].name.."\":{".."\"offset\":\""..tempClass.fields[j].offset.."\",\"type\":\""..tempClass.fields[j].typename.."\",\"static\":"..tostring(tempClass.fields[j].isStatic)
      if variableValuesTable[tempClass.fqname .. "." .. tempClass.fields[j].name] == 1 then
        local fieldValue = ScriptHubReadStaticValue(tempClass.fields[j], classData)
        if tempClass.fields[j].typename == "System.Boolean" then
          outputString[#outputString+1] = ",\"value\":"..tostring(fieldValue).."}"
        else
          outputString[#outputString+1] = ",\"value\":\""..tostring(fieldValue).."\"}"
        end
      else
        outputString[#outputString+1] = "}"
      end
      if j < #tempClass.fields then
        outputString[#outputString+1] = ","
      else
        outputString[#outputString+1] = "}"
      end
    end
    outputString[#outputString+1] = "}"
    return table.concat(outputString)
  end
end

function ScritpHubWriteToFile(fileLoc, output)
  -- clear old file
  local file = io.open (fileLoc ,"w+")
  io.close(file)
  -- open for writing
  file = io.open (fileLoc ,"a+")
  io.output(file)
  io.write(output)
  io.close(file)
end

ScriptHubAddMenuItem()