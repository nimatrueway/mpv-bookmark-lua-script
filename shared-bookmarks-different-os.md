If you have several operating-systems installed on your system and you go back and forth between them, you probably want to use a shared `bookmarks.json` and put this file on a partition that is mounted on all your operating-systems. Then you need to modify two functions in the script:

* Firstly change `getConfigFile()` such that it points to a static file.
```lua
function getConfigFile()
  return platform_independent("/d/mpv/bookmarks.json")
end
```

* Secondly implement `platform_independent()` function such that it takes care of platform specific path prefixes. Here is a simple mechanism that detects a prefix from a set, then replaces it with the appropriate prefix according to current platform:

```lua
function platform_independent(filepath)
  function find_and_remove_prefix(prefixes, path)
    path_lower = path:lower()
    for _,prefix in ipairs(prefixes) do
      prefix_lower = prefix:lower()
      if string.sub(path_lower,1,string.len(prefix_lower)) == prefix_lower then
        return string.sub(path,string.len(prefix_lower)+1,string.len(path))
      end
    end
    return path
  end
  function try_suitable_prefix(prefixes, path)
    tail = find_and_remove_prefix(prefixes, path)
    if tail ~= path then
      if is_windows() then
        return prefixes[1] .. tail        
    elseif is_macos() then
      return prefixes[2] .. tail
    else
      return prefixes[3] .. tail
    end
  end
  return path
  end  
  if filepath == nil or filepath == "" then
    return filepath
  end
  filepath = filepath:gsub("\\", "/")
  -- NOW INSTRUCT WHICH GROUP OF PREFIXES POINTING TO THE SAME PATH LIKE TWO LINES BELOW
  -- NOTE1: ADD LINES LIKE THIS
  --        filepath = try_suitable_prefix({ '{path-on-windows}', '{path-on-macos}', '{path-on-linux}' }, filepath)
  -- NOTE2: elements of every set should not share a prefix
  filepath = try_suitable_prefix({ 'd:/', '/Volumes/Archive/', '/d/' }, filepath)
  filepath = try_suitable_prefix({ 'e:/home/nima/', '/Volumes/Linux/home/nima/', '/home/nima/' }, filepath)
  return filepath
end
```
