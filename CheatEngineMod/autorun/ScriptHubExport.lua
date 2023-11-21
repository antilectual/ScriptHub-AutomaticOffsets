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
    classTable[assemblyName]["class_set"] = classes
    for classIndex=1, #classes do
      local name = classes[classIndex].classname
      if name~=nil and name~='' and name~='<unnamed>' and not string.find(name, "<") then
        classTable[assemblyName]["classes"][name] = classes[classIndex].class
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

function ScriptHubExport(fileLoc)
  local classTable = PreComputeClasses()
  if (monopipe==nil)  then
    LaunchMonoDataCollector()
  end
  local assemblyNames = {}
  assemblyNames[1] = "Assembly-CSharp"
  assemblyNames[2] = "Assembly-CSharp.dll"
  local classes = nil
  for i = 1, #assemblyNames do
    classes = classTable[assemblyNames[i]]["class_set"]
    if classes and (classes~=0) then
      break
    end
  end
  if (classes == nil) or (classes==0) then
    return
  end
  local i,j
  local outputString = {}
  outputString[#outputString+1] = "{\"classes\" : {"
  if classes~=nil then
    local stopValue = #classes
    local value = 1
    -- Iterate from i to stopValue indexes of classses
    local builtJSON = {}
    for i=1, stopValue do --#classes do
      value = i
      -- Ensure class has a name for comparisons
      classes[i].fqname = mono_class_getFullName(classes[i].class)
      --classes[i].name = classes[i].classname-- mono_class_getName(node.Data)
      if classes[i].fqname==nil or classes[i].fqname=='' then
        classes[i].fqname=classes[i].classname
        if classes[i].fqname==nil or classes[i].fqname=='' then
          classes[i].fqname='<unnamed>'
        end
      end
      --print(classes[i].fqname)
      -- Only continue if the class has a valid name note: short circuit eval works in LUA
      if classes[i].fqname~=nil and classes[i].fqname~='' and classes[i].fqname~='<unnamed>' and not string.find(classes[i].fqname, "<") then
        local classData = mono_findClass_ScriptHub(classes[i].namespace, classes[i].classname, classTable) -- retrieve the class object reference (not a string)
        local fields = mono_class_enumFields_ScriptHub(classData, false) -- 2nd parameter is whether to include offsets from parent classes
        local parent = mono_class_getParent(classes[i].class)
        -- Build JSON string from fields
        local currentJSON = BuildJsonFromFields(classes[i], classData, fields, parent)
        if currentJSON~=nil then
          outputString[#outputString+1] = currentJSON
          if i < stopValue then
            outputString[#outputString+1] = ","
          end
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
    print("[Class Details] - Last: "..tostring(value)..". Stop value: ".. tostring(stopValue))
  else
    print("getClass failed to find classes")
  end
  return table.concat(outputString)
end

function mono_class_enumFields_ScriptHub(class, includeParents)
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
function mono_findClass_ScriptHub(namespace, classname, classTable)
  local ass=mono_enumAssemblies()
  local result
  if ass==nil then return nil end
  for i=1, #ass do
    result=mono_image_findClass(mono_getImageFromAssembly(ass[i]), namespace, classname)
    if (result~=0) then
      return result;
    end
  end
  for i=1, #ass do
    result=mono_image_findClass_for_ScriptHub(mono_getImageFromAssembly(ass[i]), namespace, classname, classTable)
    if (result~=0) then
      return result;
    end
  end  
  return nil
end

-- find a class in a specific image
function mono_image_findClass_for_ScriptHub(image, namespace, classname, classTable)
  local result=0
  if monopipe==nil then return 0 end 
  local assemblyName = mono_image_get_name(image)
  if classTable[assemblyName] ~= nil and classTable[assemblyName]["classes"] ~= nil and classTable[assemblyName]["classes"][classname] ~= nil then
    result = classTable[assemblyName]["classes"][classname]
  end
  return result
end

function monoform_miSaveClickTargeted(sender)
  local saveDialog=createSaveDialog()
  saveDialog.Title=translate('Save as... (Export will take several minutes)')
  saveDialog.DefaultExt='json'
  saveDialog.Filter=translate('JSON files (*.json )|*.json')
  saveDialog.Options='['..string.sub(string.sub(saveDialog.Options,2),1,#saveDialog.Options-2)..',ofOverwritePrompt'..']'
  if saveDialog.Execute() then
    local clockA = os.clock()
    local outputString = ScriptHubExport(saveDialog.Filename)
    if (outputString == nil) or (outputString == '') then
      return
    end
    ScritpHubWriteToFile(saveDialog.Filename, outputString)
    print("Export to "..saveDialog.Filename.." complete.")
    print("Total Elapsed time: "..tostring(os.clock()-clockA))
  end
end

function ScriptHubReadStaticValue(field, class)
  local staticAddr = mono_class_getStaticFieldAddress(class, nil)
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
function BuildJsonFromFields(class, classData, fields, parent)
  local variableValuesTable = {["CrusadersGame.GameSettings.MobileClientVersion"] = 1, ["CrusadersGame.GameSettings.VersionPostFix"] = 1}
  if fields ~= nil and #fields > 0 then
    local outputString = {}
    class.fields = fields
    local tempClass = class
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