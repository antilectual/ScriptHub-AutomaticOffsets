function ScriptHubExport(fileLoc)
    if (monopipe==nil)  then
      LaunchMonoDataCollector()
    end
    local image=getImage()
    local classes=mono_image_enumClasses(image)
    local i,j
    local outputString = "{\"classes\" : {"
    if classes~=nil then
      local stopValue = #classes
      local value = 1
      -- Iterate from i to stopValue indexes of classses
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
          local classData = mono_findClass(classes[i].namespace, classes[i].classname) -- retrieve the class object reference (not a string)
          local fields = mono_class_enumFields_ScriptHub(classData, false) -- 2nd parameter is whether to include offsets from parent classes
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
            outputString = outputString.." \"fields\" : {"
            for j=1, #tempClass.fields do
                outputString = outputString.."\""..tempClass.fields[j].name.."\" : {".. "\"offset\" : \""..tempClass.fields[j].offset.."\", \"type\" :\""..tempClass.fields[j].typename.."\", \"static\" :\""..tostring(tempClass.fields[j].isStatic).."\"}"
                if j < #tempClass.fields then
                  outputString = outputString..","
                else
                  outputString = outputString.."}"
                end
            end
            outputString = outputString.."}"
            if i < stopValue then
                outputString = outputString..","
            end
          end
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

      -- recursively get parents
      --   if includeParents then
      --     local parent=mono_class_getParent(class)
      --     -- base case: break when no parent exists
      --     if (parent) and (parent~=0) then
      --       fields=mono_class_enumFields_ScriptHub(parent, includeParents);
      --       index=#fields+1;
      --     end
      --   end


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

      -- Do not sort fields, will be sorted elsewhere
      -- table.sort(fields, function(f1,f2)
      --   return f1.offset < f2.offset
      -- end)
      return fields

    end

    

    function monoform_miSaveClickTargeted(sender)
      if monoForm.SaveDialog.execute() then
        ScriptHubExport(monoForm.SaveDialog.Filename)
      end
    end