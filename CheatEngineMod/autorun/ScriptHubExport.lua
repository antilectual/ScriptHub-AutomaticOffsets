
elapsed1 = 0.0
elapsed2 = 0.0
elapsed3 = 0.0
elapsed4 = 0.0
elapsed5 = 0.0

classTable = nil

function PreComputeClasses()
  if (monopipe==nil)  then
    LaunchMonoDataCollector()
  end
  classTable = {}
  local clockA = os.clock()
  local assemblies=mono_enumAssemblies()
  for i=1, #assemblies do
    local assembly = mono_getImageFromAssembly(assemblies[i])
    local assemblyName = mono_image_get_name(assembly)
    classTable[assemblyName] = {}
    classTable[assemblyName]["image"] = assembly
    classTable[assemblyName]["classes"] = {}
    if assemblyName == "System.Xml" then
      print("System.Xml found!")
      print(tostring(classTable[assemblyName]))
    end
    local classes = mono_image_enumClasses(assembly)
    for classIndex=1, #classes do
      local name = classes[classIndex].classname
      if name~=nil and name~='' and name~='<unnamed>' and not string.find(name, "<") then
        classTable[assemblyName]["classes"][name] = classes[classIndex].class
      end
    end
  end
  local clockB = os.clock()
  print("PreComputeClasses Elapsed Time: " .. tostring(clockB - clockA))
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
  local clockA = os.clock()
  local clockB 
  local clockC 
  local clockD
  local clockE
  local clockF
  local clockG
  local clockH
  local clockZ
  local clockW
  local clockX
  local clockY
  local elapsedB = 0.0
  local elapsedC = 0.0
  local elapsedD = 0.0
  local elapsedE = 0.0
  local elapsedF = 0.0
  local elapsedG = 0.0
  local elapsedH = 0.0
  local elapsedZ = 0.0
  if classTable==nil then
    PreComputeClasses()
  end
  if (monopipe==nil)  then
    LaunchMonoDataCollector()
  end
  clockY = os.clock()
  local image=getImage()
  clockX = os.clock()
  local classes=mono_image_enumClasses(image)
  clockW = os.clock()
  local i,j
  local outputString = "{\"classes\" : {"
  if classes~=nil then
    local stopValue = #classes
    local value = 1
    -- Iterate from i to stopValue indexes of classses
    for i=1, stopValue do --#classes do
      value = i
      -- Ensure class has a name for comparisons
      clockB = os.clock()
      classes[i].fqname = mono_class_getFullName(classes[i].class)
      clockZ = os.clock()
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
        clockC = os.clock()
        local classData = mono_findClass_ScriptHub(classes[i].namespace, classes[i].classname) -- retrieve the class object reference (not a string)
        clockD = os.clock()
        local fields = mono_class_enumFields_ScriptHub(classData, false) -- 2nd parameter is whether to include offsets from parent classes
        clockE = os.clock()
        local parent = mono_class_getParent(classes[i].class)
        -- Build JSON string from fields
        if fields ~= nil and #fields > 0 then
          classes[i].fields = fields
          local tempClass = classes[i]
          outputString = outputString.."\""..tempClass.fqname.."\" : {\"ShortName\": \""..tempClass.classname.."\","
          if parent ~= nil then
              local parentName = mono_class_getFullName(parent)
              outputString = outputString.."\"Parent\": \""..parentName.."\","
          end
          clockF = os.clock()
          outputString = outputString.." \"fields\" : {"
          for j=1, #tempClass.fields do
              outputString = outputString.."\""..tempClass.fields[j].name.."\" : {".. "\"offset\" : \""..tempClass.fields[j].offset.."\", \"type\" :\""..tempClass.fields[j].typename.."\", \"static\" :\""..tostring(tempClass.fields[j].isStatic).."\"}"
              if j < #tempClass.fields then
                outputString = outputString..","
              else
                outputString = outputString.."}"
              end
          end
          clockG = os.clock()
          outputString = outputString.."}"
          if i < stopValue then
              outputString = outputString..","
          end


          if(clockF ~= nil and clockE ~= nil) then
            elapsedE = clockF-clockE + elapsedE
          end
          if(clockG ~= nil and clockF ~= nil) then
            elapsedF = clockG-clockF + elapsedF
        end
        
        if(clockD ~= nil and clockC ~= nil) then
          elapsedC = clockD-clockC + elapsedC
        end
        if(clockE ~= nil and clockD ~= nil) then
          elapsedD = clockE-clockD + elapsedD
        end

      end
      
      if(clockC ~= nil and clockB ~= nil) then
        elapsedB = clockC-clockB + elapsedB
      end

      end
      if(clockB ~= nil and clockZ ~= nil) then
        elapsedF = clockZ-clockB + elapsedF
      end
    end
    -- test in case the last classes read was nil/empty/unamed or <> and didn't add a new object as expected
    if string.sub(outputString, -1) == ',' then
      outputString = outputString:sub(1, -2)
    end
    outputString = outputString.."}}"
    -- local filename = "ScriptHubExport.json"
    -- clear old file
    local file = io.open (fileLoc ,"w+")
    io.close(file)
    -- open for writing
    file = io.open (fileLoc ,"a+")
    io.output(file)
    io.write(outputString)
    io.close(file)
    local current_dir=io.popen"cd":read'*l'.."\\"
    -- print("Export to "..current_dir..filename.." complete. Last: "..tostring(value)..". Stop value: ".. tostring(stopValue))
    print("Export to "..fileLoc.." complete. Last: "..tostring(value)..". Stop value: ".. tostring(stopValue))
    clockH = os.clock()
    
    print("Total Elapsed time: "..tostring(os.clock()-clockA))
    print("B Elapsed time: "..tostring(elapsedB))
    print("C Elapsed time: "..tostring(elapsedC))
    print("D Elapsed time: "..tostring(elapsedD))
    print("E Elapsed time: "..tostring(elapsedE))
    print("F Elapsed time: "..tostring(elapsedF))
    print("G Elapsed time: "..tostring(elapsedG))
    
    print("Y Elapsed time: "..tostring(clockY-clockA))
    print("X Elapsed time: "..tostring(clockX-clockY))
    print("W Elapsed time: "..tostring(clockW-clockX))
    
    print("mono_enumAssemblies Elapsed time: "..tostring(elapsed1))
    print("mono_image_findClass Elapsed time: "..tostring(elapsed2))
    print("mono_image_findClassSlow Elapsed time: "..tostring(elapsed3))

  else
    print("getClass failed to find classes")
  end
end

function getImage()
  local smap = monoform_getStructMap()
  local i, j
  local fqclass, caddr
  local assemblies=mono_enumAssemblies()
  if assemblies then
    for i=1, #assemblies do
      local image=mono_getImageFromAssembly(assemblies[i])
      local name=mono_image_get_name(image)
      if name == "Assembly-CSharp" or name == "Assembly-CSharp.dll" then
        if image and (image~=0) then
          return image
        end
      end
    end
    print("getImage func: failed to find C Sharp in image")
  else
    print("getImage func: failed to define assemblies")
  end
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
function mono_findClass_ScriptHub(namespace, classname)
  local clockA = os.clock()

  local clockB 
  local clockC 
  local clockD

  local ass=mono_enumAssemblies()

  clockB = os.clock()
  elapsed1 = clockB - clockA + elapsed1

  local result
    if ass==nil then return nil end
  for i=1, #ass do
    result=mono_image_findClass(mono_getImageFromAssembly(ass[i]), namespace, classname)
    if (result~=0) then
      clockC = os.clock()
      elapsed2 = clockC - clockB + elapsed2
      return result;
    end
  end

  clockC = os.clock()
  elapsed2 = clockC - clockB + elapsed2
  -- print("mono_image_findClass Elapsed time: "..tostring(elapsed2))

  --still here:
  for i=1, #ass do
    result=mono_image_findClassSlow_ScriptHub(mono_getImageFromAssembly(ass[i]), namespace, classname)
    if (result~=0) then
      clockD = os.clock()
      elapsed3 = clockD - clockC + elapsed3
      return result;
    end
  end  
  -- no clock, results here were 0 with normal functioning reads so never reaches here.
  return nil
end

-- find a class in a specific image
function mono_image_findClassSlow_ScriptHub(image, namespace, classname)
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
    ScriptHubExport(saveDialog.Filename)
  end
end

ScriptHubAddMenuItem()