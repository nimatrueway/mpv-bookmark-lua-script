-- DEBUGGING
--
-- Debug messages will be printed to stdout with mpv command line option
-- `--msg-level='bookmarker=debug'`

local utils = require('mp.utils')
local msg = require('mp.msg')

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
function GetHostName(url)
  return url:match("^http[s]?://([^/]+).*$")
end
function GetUrlPath(url)
  return url:match("^http[s]?://[^/]+[/]?(.*)$")
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
  msg.debug("[persistence]", "bookmark file successfully saved.")
  return true
end

--// Load a table from a json-file
function loadTable(path)
  function tableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
  end
  local myTable = {}
  local file = io.open(path, "r")
  if file then
    local contents = file:read("*a")
    io.close(file)
    local length = string.len(contents)
    msg.debug("[persistence]", "bookmark file successfully loaded. length: " .. length)
    if length == 0 then
      contents = "{}"
    end
    myTable = utils.parse_json(contents);
    if not myTable then
      error("Corrupt bookmark file '" .. path .. "', please remove it! bookmarker will automatically create a new file.")
    end
    msg.debug("[persistence]", tableLength(myTable) .. " slots found.")
    return myTable
  end
  msg.warn("[persistence]", "could not load bookmark file!")
  return nil
end

--// check if it's a url/stream
function is_url(path)
  if path ~= nil and string.sub(path, 1, 4) == "http" then
    msg.debug("[path/url]", "detected as stream: '" .. path .. "'")
    return true
  else
    return false
  end
end

--// check whether a file exists or not
function file_exists(path)
  if is_url(path) then
    return true
  else
    local f = io.open(path, "r")
    if f ~= nil then
      io.close(f)
      return true
    else
      msg.debug("[path/url]", "'" .. path .. "' did not exist.")
      return false
    end
  end
end

--// check if macos
function is_macos()
  local homedir = os.getenv("HOME")
  if homedir ~= nil and string.sub(homedir, 1, 6) == "/Users" then
    msg.debug("[os/detector]", "macOS detected.")
    return true
  else
    return false
  end
end

--// check if windows
function is_windows()
  local windir = os.getenv("windir")
  if windir ~= nil then
    msg.debug("[os/detector]", "windows detected.")
    return true
  else
    return false
  end
end

function platform_independent(filepath)
  return filepath -- // see "shared-bookmarks-different-os.md" to see utility of this function
end

--// default file to save/load bookmarks to/from
function getConfigFile()
  local path = ''
  if is_windows() then
    path = os.getenv("APPDATA"):gsub("\\", "/") .. "/mpv/bookmarks.json"
  else
    path = os.getenv("HOME") .. "/.config/mpv/bookmarks.json"
  end
  msg.debug("[persistence]", "config file is set to '" .. path .. "'.")
  return path
end

--// print current bookmark object
function printBookmarkInfo(bookmark)
  if bookmark ~= nil then
    local path = bookmark["filepath"] or "UNDEFINED PATH"
    local dirname = "UNDEFINED DIRECTORY"
    local name = "UNDEFINED FILENAME"
    if is_url(path) then
      dirname = GetHostName(path) or "INVALID URL"
      name = GetUrlPath(path) or "INVALID URL"
    else
      dirname = GetImmediateDirectoryName(path) or "INVALID DIRECTORY"
      name = GetFileName(path) or "INVALID FILENAME"
      name = name:gsub("_", " ")
    end
    local existance = (file_exists(path) and "") or "[!!] "
    local pos = bookmark["pos"] or "0"
    local title = bookmark["title"]
    if title ~= nil and title ~= "" and title ~= name then
      title = "\n" .. title
    else
      title = ""
    end
    return existance .. dirname .. "\n" .. existance .. name .. title .. "\n" .. displayTime(tonumber(pos))
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
    msg.debug("[persistence]", "slot[" .. slot .. "] is empty!")
    return
  end
  bookmark["pos"] = math.max(bookmark["pos"] or 0, 0)
  bookmark["filepath"] = platform_independent(bookmark["filepath"])
  msg.debug("[persistence]", "slot[" .. slot .. "] loaded: " .. utils.format_json(bookmark))
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
  bookmark["title"] = mp.get_property("media-title")
  msg.debug("[interface]", "bookmark to be saved: { " .. utils.format_json(bookmark) .. " }")
  return bookmark
end

--// play to a bookmark
function bookmarkToCurrentPosition(bookmark, firstStep)
  if firstStep then
    msg.debug("[interface]", "bookmark to be loaded: { " .. utils.format_json(bookmark) .. " }")
  end
  if mp.get_property("path") == bookmark["filepath"] then
    if firstStep then
      msg.debug("[interface]", "file is already loaded.")
    end
    msg.debug("[interface]", "setting position to: " .. bookmark["pos"])
    -- if current media is the same as bookmark media
    mp.set_property_number("time-pos", bookmark["pos"])
    return
  elseif firstStep == true then
    msg.debug("[interface]", "setting path to: '" .. bookmark["filepath"] .. "'")
    mp.commandv("loadfile", bookmark["filepath"], "replace")
    if bookmark["pos"] ~= nil then
      local seekerFunc = {}
      seekerFunc.fn = function()
        mp.unregister_event(seekerFunc.fn);
        bookmarkToCurrentPosition(bookmark, false)
      end
      mp.register_event("playback-restart", seekerFunc.fn)
      msg.debug("[interface]", "waiting for file/url to load.")
    end
  else
    msg.debug("[interface]", "setting the position is cancelled as the path is not loaded.")
  end
end

--// get latest bookmark if it relates to current file (if they point to files that are in the same directory)
function find_current_bookmark_slot()
  if latest_loaded_bookmark ~= -1 then
    local bookmark = fetchBookmark(latest_loaded_bookmark)
    current_file = mp.get_property("path")
    if bookmark ~= nil and current_file ~= nil then
      if GetDirectory(platform_independent(bookmark["filepath"])) == GetDirectory(platform_independent(current_file)) then
        msg.debug("[interface]", "Current bookmark slot detected as: " .. latest_loaded_bookmark)
        return latest_loaded_bookmark
      end
      msg.debug("[interface]", "Lastest loaded bookmark slot was " .. latest_loaded_bookmark .. " but the path has been changed.")
    end
  end
  msg.debug("[interface]", "No bookmark has been loaded yet.")
  return nil
end

--// handle "bookmark-set" function triggered by a key in "input.conf"
function bookmark_save(slot)
  msg.debug("[interface]", "received 'bookmark-set(" .. slot .. ")' script message.")
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
  msg.debug("[interface]", "received 'bookmark-update' script message.")
  slot_to_be_saved = find_current_bookmark_slot()
  if slot_to_be_saved ~= nil then
    bookmark_save(slot_to_be_saved)
  end
end
mp.register_script_message("bookmark-update", last_bookmark_update)

--// handle "bookmark-load" function triggered by a key in "input.conf"
function bookmark_load(slot)
  msg.debug("[interface]", "received bookmark-load(" .. slot .. ") script message.")
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
end
mp.register_script_message("bookmark-load", bookmark_load)

--// handle "bookmark-peek" function triggered by a key in "input.conf"
function bookmark_peek(slot)
  msg.debug("[interface]", "received 'bookmark-peek(" .. slot .. ")' script message.")
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
  msg.debug("[interface]", "received 'bookmark-peek-current' script message.")
  slot_to_be_saved = find_current_bookmark_slot()
  if slot_to_be_saved ~= nil then
    bookmark_peek(slot_to_be_saved)
  end
end
mp.register_script_message("bookmark-peek-current", current_bookmark_peek)