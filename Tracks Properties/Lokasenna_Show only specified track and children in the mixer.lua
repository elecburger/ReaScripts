--[[
    Description: Show only specified track and children in the mixer
    Version: 1.0.0
    Author: Lokasenna
    Donation: https://paypal.me/Lokasenna
    Changelog:
        Initial Release
    Links:
        Lokasenna's Website http://forum.cockos.com/member.php?u=10417
    About:
        Prompts for a track name/number, finds the first matching track, and hides
        all tracks in the mixer aside from that and its children.

        Also provides an option to export specific names/numbers as a standalone action.
]]--

-- BEGIN FILE COPY HERE

local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
local script_filename = ({reaper.get_action_context()})[2]:match("([^/\\]+)$")

local track

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str) .. "\n")
end


local function sanitize_filename(name)
    return string.gsub(name, "[^%w%s_]", "-")
end


-- Returns true if the individual words of str_b all appear in str_a
local function fuzzy_match(str_a, str_b)
    
    str_a, str_b = string.lower(tostring(str_a)), string.lower(tostring(str_b))
    if not (str_a and str_b) then return end
    
    --Msg("fuzzy match, looking for:\n\t" .. str_b .. "\nin:\n\t" .. str_a .. "\n")
    
    for word in string.gmatch(str_b, "[%a%d]+") do
        --Msg( tostring(word) .. ": " .. tostring( string.match(str_a, word) ) )
        if not string.match(str_a, word) then return end
    end
    
    return true
    
end


-- Find a track by number or name (fuzzy-matched)
-- Will match the Master track if given "master"
-- Returns a MediaTrack
local function find_track(track)

    local tr
    if tonumber(track) then

        -- Force an integer until/unless I come up with some sort of multiple track syntax
        track = math.floor( tonumber(track) )
        
        tr = tonumber(track) > 0    and reaper.GetTrack(0, tonumber(track) - 1)
                                    or  reaper.GetMasterTrack(0)

    elseif tostring(track) then
    
        if string.lower( tostring(track) ) == "master" then
                
            tr = reaper.GetMasterTrack(0)
            
        else

            for i = 0, reaper.GetNumTracks() - 1 do
                
                local t = reaper.GetTrack(0, i)
                local ret, name = reaper.GetTrackName(t, "")
                if ret and fuzzy_match( sanitize_filename(name), tostring(track) ) then
                    tr = t
                    break
                end
                
            end
        
        end

    end

    return tr

end


local function set_visibility( track )

    if not track then return end

    reaper.SetOnlyTrackSelected(track)
    reaper.Main_OnCommand( reaper.NamedCommandLookup("_SWS_SELCHILDREN2"), 0)
    reaper.Main_OnCommand( reaper.NamedCommandLookup("_SWSTL_SHOWMCPEX"), 0)

end


if script_filename ~= "Lokasenna_Show only specified track and children in the mixer.lua" then
    
    -- Parse vals from filename
    track = string.match(script_filename, "only%strack%s(.+)%sand children in the mixer.lua")
    
    if track then
        set_visibility( find_track(track) )
    else
        reaper.MB("Error reading settings. Make sure the script's filename has *not* been changed.", "Whoops!", 0)
    end
    
    return
    
end



-- END FILE COPY HERE


local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v2 library path.lua' in the Lokasenna_GUI folder.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()



-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end







------------------------------------
-------- Button functions ----------
------------------------------------


local function btn_go()
    
    local track = GUI.Val("txt_track")
    set_visibility( find_track(track) )
    
end


local function btn_save()

    local track = GUI.Val("txt_track")
    if not track or track == "" then return end
    

    -- Copy everything from the file between the ReaPack header and GUI stuff
    local file_in, err = io.open(script_path .. script_filename, "r")
    if err then
        reaper.MB("Error opening source file:\n" .. tostring(err), "Whoops!", 0)
        return
    end
    
    local arr, copying = {}    
    --make sure to add a header tag, "generated by" etc.
    arr[1] = "-- This script was generated by " .. script_filename .. "\n"

    for line in file_in:lines() do
        
        if copying then
            if string.match(line, "-- END FILE COPY HERE") then break end
            arr[#arr + 1] = line
        elseif string.match(line, "-- BEGIN FILE COPY HERE") then 
            copying = true
        end 
        
    end
    


    -- Generate a coherent filename
    local name = "Lokasenna_Show only track " .. track .. " and children in the mixer"

    -- Write the file
    local name_out = sanitize_filename(name) .. ".lua"
    local file_out, err = io.open(script_path .. name_out, "w")
    if err then
        reaper.MB("Error opening output file:\n" .. script_path..name_out .. "\n\n".. tostring(err), "Whoops!", 0)
        return
    end    
    file_out:write(table.concat(arr, "\n"))
    file_out:close()
    
    -- Register it as an action
    local ret = reaper.AddRemoveReaScript( true, 0, script_path .. name_out, true )
    if ret == 0 then
        reaper.MB("Error registering the new script as an action.", "Whoops!", 0)
        return
    end
    
    -- Pop up an MB?
    reaper.MB(  "Saved current settings and added to the action list:\n" .. name_out .. ".lua" ..
                "\n\nImportant: Do NOT change the script's filename, or it will crash.",
                "Done!", 0)
    
end




------------------------------------
-------- GUI Elements --------------
------------------------------------


GUI.name = "Show only specified track..."
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 288, 164
GUI.anchor, GUI.corner = "mouse", "C"


GUI.New("txt_track", "Textbox", 1, 56, 16.0, 176, 20, "Track:")


GUI.New("btn_go", "Button", 1, 82, 56, 128, 24, "Go!", btn_go)
GUI.New("btn_save", "Button", 1, 82, 88, 128, 24, "Save as action", btn_save)

GUI.Init()
GUI.Main()