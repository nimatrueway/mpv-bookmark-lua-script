## mpv-bookmarker <img src="https://cloud.githubusercontent.com/assets/8236909/9288343/8b64fb36-434a-11e5-980c-bd2cf67cb0a2.jpg" width="30">
#### mpv-bookmarker is a lua script for mpv to to set bookmark on your favorite moments of certain media files 

###### Usage
* Copy `bookmarker.lua` script to `~/.config/mpv/scripts/bookmarker.lua`
* Open key configuration file at `~/.config/mpv/input.conf` and 
  map your desired keys to save/load/peek a specific bookmark. For example the lines below mean `Ctrl+1` will "save current filePath and seekPos to bookmark #1 slot" and `Alt+2` will "restore current filePath and seekPos from bookmark #2 slot" and `Alt+Ctrl+2` will give you a "peek of the filename, its immediate parent directory and seek-pos saved in the bookmark #2 slot"
```    
Ctrl+1 script_message bookmark-set  1
Alt+1  script_message bookmark-load 1
Alt+Ctrl+1  script_message bookmark-peek 1
Ctrl+2 script_message bookmark-set  2
Alt+2  script_message bookmark-load 2
Alt+Ctrl+2  script_message bookmark-peek 2
```
* There is no limit to slots. (the whole bookmark data will be kept in file `~/.config/mpv/bookmarks.json`)

###### Tested
* Has been tested on Linux and macOS
