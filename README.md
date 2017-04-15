## mpv-bookmarker <img src="https://cloud.githubusercontent.com/assets/8236909/9288343/8b64fb36-434a-11e5-980c-bd2cf67cb0a2.jpg" width="30">
#### mpv-bookmarker is a lua script for mpv to to set bookmark on favorite parts of media files 

###### Using
* Copy `bookmarker.lua` script to `~/.config/mpv/scripts/bookmarker.lua`
* Open key configuration file at `~/.config/mpv/input.conf` and 
  map your desired keys to save/load a bookmark. For example these lines mean `Ctrl+1` will "save current filePath and seekPos to bookmark#1" or `Alt+2` will "set current filePath and seekPos according to bookmark#2"  
```    
Ctrl+1 script_message bookmark-set  1
Alt+1  script_message bookmark-load 1
Ctrl+2 script_message bookmark-set  2
Alt+2  script_message bookmark-load 2
```
* There is no limit to available slots. (all bookmark data will be keep in file `~/.config/mpv/bookmarks.json`)

###### Test
* Has been tested on Linux and macOS