--[[
        Sqlite.lua
        
        Initial motivation for this extended external-app class dedicated to exif-tool was
        the ability to support multiple simultaneous exif-tool sessions.
        
        Initial application was for preview-exporter which uses preview and image class objects.
        
        It is recommended to have one session per task / service, since if two async tasks
        shared the same session there would be interleaving of arguments...
        
        Examples:

            * local dc=Sqlite()
            * dc:convert{ photo=photo, ... }        
--]]


local Sqlite, dbg, dbgf = ExternalApp:newClass{ className = 'Sqlite', register = true }



--- Constructor for extending class.
--
function Sqlite:newClass( t )
    return ExternalApp.newClass( self, t )
end



--- Constructor for new instance.
--
--  @usage pass pref-name, win-exe-name, or mac-pathed-name, if desired, else rely on defaults (but know what they are - see code).
--
function Sqlite:new( t )
    t = t or {}
    t.name = t.name or "SQLite"
    t.prefName = t.prefName or 'sqliteApp' -- same pref-name for win & mac.
    t.winExeName = t.winExeName or "sqlite3.exe" -- if included with plugin - may not be.
    t.macAppName = t.macAppName or "sqlite3" -- if included with plugin, also: pre-requisite condition for mac-default-app-path to be used instead of mac-pathed-name, if present on system.
    t.winDefaultExePath = nil -- is there a default path? (doesn't matter - it's always built in).
    t.macDefaultAppPath = nil -- ditto
    t.winPathedName = nil -- pathed access to converter not supported on Windows.
    t.macPathedName = nil -- ditto
    local o = ExternalApp.new( self, t )
    return o
end



--- Executes SQL query.
--
function Sqlite:executeQuery( db, sql, cols, sep )
    local param
    if type( db ) == 'table' then
        cols = db.cols
        sql = db.sql
        param = db.param or '"' .. db.db .. '"'
        db = db.db -- not really needed once param is computed, but hey...
    else
        param = '"' .. db .. '"' -- param only supported as named parameter, otherwise pass db path instead.
    end
    local sts, cmdOrMsg, dat = sqlite:executeCommand( param, { sql }, nil, 'del' ) -- modify to return array. ###1
    if not str:is( dat ) then
        return nil, cmdOrMsg
    end
    if ( cols and cols == 0 ) then
        return dat
    end
    --Debug.pause( dat )
    local da = str:split( dat, sep or "\n" )
    --Debug.pause( da )
    if not cols then
        return da
    end
    -- parse columns
    local rslt = {}
    for i, v in ipairs( da ) do
        if str:is( v ) then
            local subs = str:split( v, "|" )
            if #subs == cols then
                rslt[#rslt + 1] = subs
            else
                return nil, str:fmtx( "expected ^1 columns, but there were ^2", cols, #subs )
            end
        -- else last row is usually always blank.
        end
    end
    return rslt
end
Sqlite.query = Sqlite.executeQuery -- function Sqlite:query( ... )



function Sqlite:executeUpdate( db, sql )
    local param
    if type( db ) == 'table' then
        sql = db.sql
        param = db.param or '"' .. db.db .. '"'
        db = db.db -- not really needed once param is computed, but hey...
    else
        param = '"' .. db .. '"' -- param only supported as named parameter, otherwise pass db path instead.
    end
    local sts, cmdOrMsg, dat = sqlite:executeCommand( param, { sql } ) -- , nil, 'del' )
    --if dat == nil then
    --    return nil, cmdOrMsg or "no response"
    --end
    if sts then
        app:logV( "'^1' updated by command: ^2", db, cmdOrMsg )
        return true
    else
        return sts, cmdOrMsg or "pgm fail"
    end
end
Sqlite.update = Sqlite.executeUpdate -- function Sqlite:update( ... )


return Sqlite
