## mpv-bookmarker 2.0 <img src="https://cloud.githubusercontent.com/assets/8236909/9288343/8b64fb36-434a-11e5-980c-bd2cf67cb0a2.jpg" width="30">
#### mpv-bookmarker is a lua script for mpv to to set bookmark on your favorite moments of certain media files 
* **Warning**: `loadTable/saveTable` mechanism has been changed since version 1.0, now we're using standard `json` format. Delete your previous `bookmarks.json` file or manually convert it to standard `json`.

###### Usage
* Copy `bookmarker.lua` script to (linux/macos) `~/.config/mpv/scripts/bookmarker.lua` (win) `%APPDATA%\mpv\scripts\bookmarker.lua`
* Open key configuration file at (linux/macos) `~/.config/mpv/input.conf` (win) `%APPDATA%\mpv\input.conf` and 
  map your desired keys to save/load/peek a specific bookmark. For example the lines below mean:
```    
Ctrl+1 script_message bookmark-set  1       #  `Ctrl+1` will "save current filePath and seekPos to bookmark #1 slot"
Alt+1  script_message bookmark-load 1       #  `Alt+2` will "restore current filePath and seekPos from bookmark #2 slot"
Alt+Ctrl+1  script_message bookmark-peek 1  #  `Alt+Ctrl+2` will give you a "peek of the filename, its immediate parent directory and seek-pos saved in the bookmark #2 slot"
Ctrl+2 script_message bookmark-set  2
Alt+2  script_message bookmark-load 2
Alt+Ctrl+2  script_message bookmark-peek 2
s script_message bookmark-update            # `s` will update last saved/restored bookmark
d script_message bookmark-peek-current      # `d` will peek last saved/restored bookmark (lastest saved/restored bookmark is only considered if current file is in the same directory as the bookmark file)
```
* There is no limit to slots. (the whole bookmark data will be kept in file (linux/macos) `~/.config/mpv/bookmarks.json` (win) `%APPDATA%\mpv\bookmarks.json`)

###### Notice
* All paths are saved with `/` path separator (even in Windows) to keep the same mechanism for all platforms.

###### Tested
* Has been tested on Linux, macOS and Windows

###### Shared bookmarks.json between different OSs
* Read [shared-bookmarks-different-os.md](shared-bookmarks-different-os.md)
