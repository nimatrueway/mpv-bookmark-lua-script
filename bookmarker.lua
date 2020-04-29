local utils = require 'mp.utils'

local latest_loaded_bookmark = -1
local latest_saved_bookmark = -1
local latest_saved_bookmark_data_before = nil

--// seconds to hh:mm:ss
function displayTime(time)
  local hours = math.floor(time / 3600)
  local minutes = math.floor((time % 3600) / 60)
  local seconds = math.floor((time % 60))
  return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

--// Extract filename/immediate-dir from url
function GetFileName(url)
  return url:match("^.+/(.+)$")
end
function GetImmediateDirectoryName(url)
  return url:match("^.*/([^/]+)/[^/]+$")
end
function GetDirectory(url)
  return url:match("^(.*)/[^/]+$")
end


--// Save/Load string serializer function
function exportstring(s)
  return string.format("%q", s)
end

--// Save a table as json to a file
function saveTable(t, path)
  -- a simple machanism to make it transactional
  local contents = utils.format_json(t)
  local file = io.open(path .. ".tmp", "wb")
  file:write(contents)
  io.close(file)
  os.remove(path)
  os.rename(path .. ".tmp", path)
  return true
end

--// Load a table from a json-file
function loadTable(path)
  local contents = ""
  local myTable = {}
  local file = io.open(path, "r")
  if file then
    local contents = file:read("*a")
    myTable = utils.parse_json(contents);
    io.close(file)
    return myTable
  end
  return nil
end

function platform_independent(filepath)
  return filepath
end

--// check whether a file exists or not
function file_exists(path)
  if path:sub(1, 4) == "http" then
    return true
  else
    local f = io.open(path, "r")
    if f ~= nil then
      io.close(f)
      return true
    else
      return false
    end
  end
end

--// check if macos
function is_macos()
  local homedir = os.getenv("HOME")
  if homedir ~= nil and string.sub(homedir, 1, 6) == "/Users" then
    return true
  else
    return false
  end
end

--// check if windows
function is_windows()
  local windir = os.getenv("windir")
  if windir ~= nil then
    return true
  else
    return false
  end
end

--// default file to save/load bookmarks to/from
function getConfigFile()
  if is_windows() then
    return os.getenv("APPDATA"):gsub("\\", "/") .. "/mpv/bookmarks.json"
  else
    return os.getenv("HOME") .. "/.config/mpv/bookmarks.json"
  end
end

--// print current bookmark object
function printBookmarkInfo(bookmark)
  if bookmark ~= nil then
    local fp = bookmark["filepath"] or "NO PATH HAS BEEN SET"
    local dirname = GetImmediateDirectoryName(fp) or "NO DIRECTORY HAS BEEN SET"
    local name = GetFileName(fp) or "NO FILENAME HAS BEEN SET"
    name = name:gsub("_", " ")
    local pos = bookmark["pos"] or "0"
    local toprint = ""
    local existance = (file_exists(fp) and "") or "[!!] "
    return existance .. dirname .. "\n" .. existance .. name .. "\n" .. displayTime(tonumber(pos))
  else
    return "Undefined"
  end
end

function fetchBookmark(slot)
  local bookmarks = loadTable(getConfigFile())
  if bookmarks == nil then
    mp.osd_message("Error loading bookmarks.json")
    return
  end
  local bookmark = bookmarks[slot]
  if bookmark == nil then
    return
  end
  bookmark["pos"] = math.max(bookmark["pos"] or 0, 0)
  bookmark["filepath"] = platform_independent(bookmark["filepath"])
  return bookmark
end

--// save current file/pos to a bookmark object
function currentPositionAsBookmark()
  local bookmark = {}
  local isLiveStream = mp.get_property("duration") == 0
  if isLiveStream then
    bookmark["pos"] = nil
  else
    bookmark["pos"] = mp.get_property_number("time-pos")
  end
  bookmark["filepath"] = mp.get_property("path")
  bookmark["filename"] = mp.get_property("filename")
  return bookmark
end

--// play to a bookmark
function bookmarkToCurrentPosition(bookmark, tryToLoadFile)
  if mp.get_property("path") == bookmark["filepath"] then
    -- if current media is the same as bookmark media
    mp.set_property_number("time-pos", bookmark["pos"])
    return
  elseif tryToLoadFile == true then
    mp.commandv("loadfile", bookmark["filepath"], "replace")
    if bookmark["pos"] ~= nil then
      local seekerFunc = {}
      seekerFunc.fn = function()
        mp.unregister_event(seekerFunc.fn);
        bookmarkToCurrentPosition(bookmark, false)
      end
      mp.register_event("playback-restart", seekerFunc.fn)
    end
  end
end

--// get latest bookmark if it relates to current file (if they point to files that are in the same directory)
function find_current_bookmark_slot()
  if latest_loaded_bookmark ~= -1 then
    local bookmark = fetchBookmark(latest_loaded_bookmark)
    current_file = mp.get_property("path")
    if bookmark ~= nil and current_file ~= nil then
      if GetDirectory(platform_independent(bookmark["filepath"])) == GetDirectory(platform_independent(current_file)) then
        return latest_loaded_bookmark
      end
    end
  end
  return nil
end

--// handle "bookmark-set" function triggered by a key in "input.conf"
function bookmark_save(slot)
  local bookmarks = loadTable(getConfigFile())
  if bookmarks == nil then
    bookmarks = {}
  end
  latest_saved_bookmark_data_before = bookmarks[slot]
  bookmarks[slot] = currentPositionAsBookmark()
  local result = saveTable(bookmarks, getConfigFile())
  if result ~= true then
    mp.osd_message("Error saving: " .. result)
  end
  latest_loaded_bookmark = slot
  mp.osd_message("Bookmark#" .. slot .. " saved.")
end
mp.register_script_message("bookmark-set", bookmark_save)

--// Save a table as json to a file
function bookmark_save_undo()
  msg.debug("[interface]", "received 'bookmark-set-undo' script message.")
  if latest_saved_bookmark ~= -1 and latest_saved_bookmark_data_before ~= nil then
    local bookmarks = loadTable(getConfigFile())
    bookmarks[latest_saved_bookmark] = latest_saved_bookmark_data_before
    local result = saveTable(bookmarks, getConfigFile())
    if result ~= true then
      mp.osd_message("Error undoing: " .. result)
    end
    mp.osd_message("Bookmark#" .. latest_saved_bookmark .. " set back to: \n" .. printBookmarkInfo(latest_saved_bookmark_data_before))
    latest_saved_bookmark = -1
    latest_saved_bookmark_data_before = nil
  end
end
mp.register_script_message("bookmark-set-undo", bookmark_save_undo)

--// handle "bookmark-update" function triggered by a key in "input.conf" | basically updates latest saved/loaded bookmark if current file is with in the same directory
function last_bookmark_update()
  slot_to_be_saved = find_current_bookmark_slot()
  if slot_to_be_saved ~= nil then
    bookmark_save(slot_to_be_saved)
  end
end
mp.register_script_message("bookmark-update", last_bookmark_update)

--// handle "bookmark-load" function triggered by a key in "input.conf"
mp.register_script_message("bookmark-load", function(slot)
  local bookmark = fetchBookmark(slot)
  if bookmark == nil then
    mp.osd_message("Bookmark#" .. slot .. " is not set.")
    return
  end
  if file_exists(bookmark["filepath"]) == false then
    mp.osd_message("File " .. bookmark["filepath"] .. " not found!")
    return
  end
  bookmarkToCurrentPosition(bookmark, true)
  latest_loaded_bookmark = slot
  mp.osd_message("Bookmark#" .. slot .. " loaded\n" .. printBookmarkInfo(bookmark))
end)

--// handle "bookmark-peek" function triggered by a key in "input.conf"
function bookmark_peek(slot)
  local bookmark = fetchBookmark(slot)
  if bookmark == nil then
    mp.osd_message("Bookmark#" .. slot .. " is not set.")
    return
  end
  mp.osd_message("Bookmark#" .. slot .. " :\n" .. printBookmarkInfo(bookmark))

end
mp.register_script_message("bookmark-peek", bookmark_peek)

--// handle "bookmark-peek-current" function triggered by a key in "input.conf" | basically peeks at latest saved/loaded bookmark if current file is with in the same directory
function current_bookmark_peek()
  slot_to_be_saved = find_current_bookmark_slot()
  if slot_to_be_saved ~= nil then
    bookmark_peek(slot_to_be_saved)
  end
end
mp.register_script_message("bookmark-peek-current", current_bookmark_peek)
