--// seconds to hh:mm:ss
function displayTime(time)
  local hours = math.floor(time/3600)
  local minutes = math.floor((time % 3600)/60)
  local seconds = math.floor((time % 60))
  return string.format("%02d:%02d:%02d",hours,minutes,seconds)
end

--// Extract filename/immediate-dir from url
function GetFileName(url)
  return url:match("^.+/(.+)$")
end
function GetImmediateDirectoryName(url)
  return url:match("^.*/([^/]+)/[^/]+$")
end

--// Save/Load string serializer function
function exportstring( s )
  return string.format("%q", s)
end

--// The Save Function [copied from http://lua-users.org/wiki/SaveTableToFile]
function saveTable(  tbl,filename )
  local charS,charE = "   ","\n"
  local file,err = io.open( filename, "wb" )
  if err then return err end

  -- initiate variables for save procedure
  local tables,lookup = { tbl },{ [tbl] = 1 }
  file:write( "return {"..charE )

  for idx,t in ipairs( tables ) do
    file:write( "-- Table: {"..idx.."}"..charE )
    file:write( "{"..charE )
    local thandled = {}

    for i,v in ipairs( t ) do
      thandled[i] = true
      local stype = type( v )
      -- only handle value
      if stype == "table" then
        if not lookup[v] then
          table.insert( tables, v )
          lookup[v] = #tables
        end
        file:write( charS.."{"..lookup[v].."},"..charE )
      elseif stype == "string" then
        file:write(  charS..exportstring( v )..","..charE )
      elseif stype == "number" then
        file:write(  charS..tostring( v )..","..charE )
      end
    end

    for i,v in pairs( t ) do
      -- escape handled values
      if (not thandled[i]) then

        local str = ""
        local stype = type( i )
        -- handle index
        if stype == "table" then
          if not lookup[i] then
            table.insert( tables,i )
            lookup[i] = #tables
          end
          str = charS.."[{"..lookup[i].."}]="
        elseif stype == "string" then
          str = charS.."["..exportstring( i ).."]="
        elseif stype == "number" then
          str = charS.."["..tostring( i ).."]="
        end

        if str ~= "" then
          stype = type( v )
          -- handle value
          if stype == "table" then
            if not lookup[v] then
              table.insert( tables,v )
              lookup[v] = #tables
            end
            file:write( str.."{"..lookup[v].."},"..charE )
          elseif stype == "string" then
            file:write( str..exportstring( v )..","..charE )
          elseif stype == "number" then
            file:write( str..tostring( v )..","..charE )
          end
        end
      end
    end
    file:write( "},"..charE )
  end
  file:write( "}" )
  file:close()
end

--// The Load Function [copied from http://lua-users.org/wiki/SaveTableToFile]
function loadTable( sfile )
  local ftables,err = loadfile( sfile )
  if err then return _,err end
  local tables = ftables()
  for idx = 1,#tables do
    local tolinki = {}
    for i,v in pairs( tables[idx] ) do
      if type( v ) == "table" then
        tables[idx][i] = tables[v[1]]
      end
      if type( i ) == "table" and tables[i[1]] then
        table.insert( tolinki,{ i,tables[i[1]] } )
      end
    end
    -- link indices
    for _,v in ipairs( tolinki ) do
      tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
    end
  end
  return tables[1]
end

--// check whether a file exists or not
function file_exists(path)
  local f = io.open(path,"r")
  if f~=nil then
    io.close(f)
    return true
  else
    return false
  end
end

--// check if macos
function is_macos()
  local homedir = os.getenv("HOME")
  if homedir ~= nil and homedir.sub(1, 6) == "/Users" then
    return true
  else
    return false
  end
end

--// check if windows
function is_windows()
  local windir = os.getenv("windir")
  if windir~=nil then
    return true
  else
    return false
  end
end

--// if you are using the same bookmarks js for different platforms, implement a mechanism here to fix path prefixes
function platform_independent(filepath)  
  return filepath
end

--// default file to save/load bookmarks to/from
function getConfigFile()
  if is_windows() then
  	return os.getenv("APPDATA"):gsub("\\", "/") .. "/mpv/bookmarks.json"
  else	
	return os.getenv("HOME") .. "/.config/mpv/bookmarks.json"
end

--// print current bookmark object
function printBookmarkInfo(bookmark)
  if bookmark ~= nil then
  	local fp = bookmark["filepath"]    
  	local pos = bookmark["pos"]
  	local toprint = ""
  	local dirname = GetImmediateDirectoryName(fp)
  	local name = GetFileName(fp):gsub("_", " ")
  	local existance = (file_exists(bookmark["filepath"]) and "") or "[!!] "
  	return existance .. dirname .. "\n" .. existance .. name .. "\n" .. displayTime(tonumber(pos))
  else
  	return "Undefined"
  end	
end

--// save current file/pos to a bookmark object
function currentPositionAsBookmark()
  local bookmark = {}
  bookmark["pos"] = mp.get_property_number("time-pos")
  bookmark["filepath"] = mp.get_property("path"):gsub("\\", "/")
  bookmark["filename"] = mp.get_property("filename")
  return bookmark
end

--// play to a bookmark
function bookmarkToCurrentPosition(bookmark, tryToLoadFile)  
  if mp.get_property("path") == bookmark["filepath"] then -- if current media is the same as bookmark media
    mp.set_property_number("time-pos", bookmark["pos"])
    return
  elseif tryToLoadFile == true then    
    mp.commandv("loadfile", bookmark["filepath"], "replace")
    local seekerFunc = {}
    seekerFunc.fn = function()
      mp.unregister_event(seekerFunc.fn);
      bookmarkToCurrentPosition(bookmark, false)
    end
    mp.register_event("playback-restart", seekerFunc.fn)
  end
end


--// handle "bookmark-set" function triggered by a key in "input.conf"
mp.register_script_message("bookmark-set", function(slot)
  local bookmarks, error = loadTable(getConfigFile())
  if error ~= nil then
    bookmarks = {}
  end
  bookmarks[slot] = currentPositionAsBookmark()
  local result = saveTable( bookmarks, getConfigFile())
  if result ~= nil then
    mp.osd_message("Error saving: " .. result)
  end
  mp.osd_message("Bookmark#" .. slot .. " saved.")
end)

--// handle "bookmark-load" function triggered by a key in "input.conf"
mp.register_script_message("bookmark-load", function(slot)
  local bookmarks, error = loadTable(getConfigFile())
  if error ~= nil then
    mp.osd_message("Error: " .. error)
    return
  end
  local bookmark = bookmarks[slot]
  bookmark["filepath"] = platform_independent(bookmark["filepath"]) -- NIMA
  if bookmark == nil then
    mp.osd_message("Bookmark#" .. slot .. " is not set.")
    return
  end
  if file_exists(bookmark["filepath"]) == false then
    mp.osd_message("File " .. bookmark["filepath"] .. " not found!")
    return
  end
  bookmarkToCurrentPosition(bookmark, true)
  mp.osd_message("Bookmark#" .. slot .. " loaded\n" .. printBookmarkInfo(bookmark))
end)

--// handle "bookmark-peek" function triggered by a key in "input.conf"
mp.register_script_message("bookmark-peek", function(slot)
  local bookmarks, error = loadTable(getConfigFile())
  if error ~= nil then
    mp.osd_message("Error: " .. error)
    return
  end
  local bookmark = bookmarks[slot]
  bookmark["filepath"] = platform_independent(bookmark["filepath"]) -- NIMA
  if bookmark == nil then
    mp.osd_message("Bookmark#" .. slot .. " is not set.")
    return
  end
  mp.osd_message("Bookmark#" .. slot .. " :\n" .. printBookmarkInfo(bookmark))
end)
