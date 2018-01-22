If you have several operating-systems installed on your system and you go back and forth between them, you probably want to use a shared `bookmarks.json` and put this file on a partition that is mounted on all your operating-systems. Then you need to modify two functions in the script:

* Firstly change `getConfigFile()` such that it points to a static file, and create an empty file there manually to avoid problems.
```lua
function getConfigFile()
  return platform_independent("/shared/mpv/bookmarks.json")
end
```

* Secondly implement `platform_independent()` function such that it takes care of platform specific path prefixes. Here is a simple mechanism that detects a prefix from a set, then tries all prefixes in the set to see which works:

```lua
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
  -- NOW INSTRUCT WHICH GROUP OF PREFIXES POINTING TO THE SAME PATH LIKE TWO LINES BELOW
  filepath = try_other_prefixes({ '/Volumes/Archive/', 'd:/', 'D:/', '/d/' }, filepath)
  filepath = try_other_prefixes({ 'E:/home/nima/', 'e:/home/nima/', '/home/nima/' }, filepath)  
  return filepath
end
```
