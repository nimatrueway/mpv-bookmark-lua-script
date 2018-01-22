## mpv-bookmarker <img src="https://cloud.githubusercontent.com/assets/8236909/9288343/8b64fb36-434a-11e5-980c-bd2cf67cb0a2.jpg" width="30">
#### mpv-bookmarker is a lua script for mpv to to set bookmark on your favorite moments of certain media files 

###### Usage
* Copy `bookmarker.lua` script to (linux/macos) `~/.config/mpv/scripts/bookmarker.lua` (win) `%APPDATA%\mpv\scripts\bookmarker.lua`
* Open key configuration file at (linux/macos) `~/.config/mpv/input.conf` (win) `%APPDATA%\mpv\input.conf` and 
  map your desired keys to save/load/peek a specific bookmark. For example the lines below mean `Ctrl+1` will "save current filePath and seekPos to bookmark #1 slot" and `Alt+2` will "restore current filePath and seekPos from bookmark #2 slot" and `Alt+Ctrl+2` will give you a "peek of the filename, its immediate parent directory and seek-pos saved in the bookmark #2 slot"
```    
Ctrl+1 script_message bookmark-set  1
Alt+1  script_message bookmark-load 1
Alt+Ctrl+1  script_message bookmark-peek 1
Ctrl+2 script_message bookmark-set  2
Alt+2  script_message bookmark-load 2
Alt+Ctrl+2  script_message bookmark-peek 2
```
* There is no limit to slots. (the whole bookmark data will be kept in file (linux/macos) `~/.config/mpv/bookmarks.json` (win) `%APPDATA%\mpv\bookmarks.json`)

###### Notice
* All paths are saved with `/` path separator (even in Windows) to keep the same mechanism for all platforms.

###### Tested
* Has been tested on Linux, macOS and Windows

###### Shared bookmarks.json between different OSs
* If you have several OS installed on your system and you go back and forth between them; you probably want to use a shared `bookmarks.json` and put this file on a partition that is mounted on all your OSs. Then you need to modify two functions in the script:

** Firstly `getConfigFile()` and change it such that it points to a static file like this:
```
function getConfigFile()
  return platform_independent("/shared/mpv/bookmarks.json")
end
```

** Secondly implement `platform_independent()` function such that it takes care of platform-specific path-prefix; here's a simple mechanism that removes a prefix from the set, then tries all prefixes to see which works:

```
function platform_independent(filepath)
  function map(func, array)
    local new_array = {}
    for i,v in ipairs(array) do
      new_array[i] = func(v)
    end
    return new_array
  end
  function remove_prefixes(prefixes, path)
    new_path = path
    for _,p in ipairs(prefixes) do
      new_path = new_path:gsub("^(" .. p .. ")", "")
    end
    return new_path
  end
  function try_other_prefixes(prefixes, path)
    tail = remove_prefixes(prefixes, path)  
    for _, p in ipairs(prefixes) do
      if file_exists(p .. tail) then
        return p .. tail
      end
    end
    return path
  end
  if filepath == nil or filepath == "" then
    return filepath
  end
  -- NOW INSTRUCT WHICH GROUP OF PREFIXES POINTING TO THE SAME PATH
  filepath = try_other_prefixes({ '/Volumes/Archive/', 'd:/', 'D:/', '/d/' }, filepath)
  filepath = try_other_prefixes({ 'E:/home/nima/', 'e:/home/nima/', '/home/nima/' }, filepath)  
  return filepath
end
```
