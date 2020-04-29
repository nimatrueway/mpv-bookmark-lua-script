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
  function find_prefix(prefixes, path)
    path_lower = path:lower()
    for _, prefix in ipairs(prefixes) do
      prefix_lower = prefix:lower()
      if string.sub(path_lower, 1, string.len(prefix_lower)) == prefix_lower then
        return prefix_lower
      end
    end
    return nil
  end
  function try_suitable_prefix(prefixes, path)
    detected_prefix = find_prefix(prefixes, path)
    local new_prefix
    if detected_prefix ~= nil then
      if is_windows() then
        new_prefix = prefixes[1]
      elseif is_macos() then
        new_prefix = prefixes[2]
      else
        new_prefix = prefixes[3]
      end
    end
    if detected_prefix and detected_prefix ~= new_prefix then
      local new_path = new_prefix .. string.sub(path, string.len(prefix_lower) + 1, string.len(path))
      msg.debug("[os/detector]", "prefix '" .. detected_prefix .. "' will be replaced with '" .. new_prefix .. "'.")
      msg.debug("[os/detector]", "changed path '" .. path .. "' to '" .. new_path .. "'.")
      return new_path
    end
    return path
  end
  if filepath == nil or filepath == "" then
    return filepath
  end
  filepath = filepath:gsub("\\", "/")
  local original_filepath = filepath
  -- NOW INSTRUCT WHICH GROUP OF PREFIXES POINTING TO THE SAME PATH LIKE TWO LINES BELOW
  -- NOTE1: ADD LINES LIKE THIS
  --        filepath = try_suitable_prefix({ '{path-on-windows}', '{path-on-macos}', '{path-on-linux}' }, filepath)
  -- NOTE2: elements of every set should not share a prefix
  -- << ON MY SYSTEM IT'S LIKE THIS
  filepath = try_suitable_prefix({ 'd:/', '/Volumes/Archive/', '/d/' }, filepath)
  filepath = try_suitable_prefix({ 'e:/home/nima/', '/Volumes/Linux/home/nima/', '/home/nima/' }, filepath)
  --    ON MY SYSTEM IT'S LIKE THIS >>
  if original_filepath ~= filepath then
    msg.debug("[os/independant]", "changed path '" .. original_filepath .. "' eventually to '" .. filepath .. "'.")
  end
  return filepath
end
```
