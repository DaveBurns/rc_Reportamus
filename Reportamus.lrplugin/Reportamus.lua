--[[
        Reportamus.lua
--]]


local Reportamus, dbg, dbgf = Object:newClass{ className = "Reportamus", register = true }



--- Constructor for extending class.
--
function Reportamus:newClass( t )
    return Object.newClass( self, t )
end


--- Constructor for new instance.
--
function Reportamus:new( t )
    local o = Object.new( self, t )
    return o
end



function Reportamus:one()
    app:show( self:toString() .. " one" )
end



function Reportamus:_getKeywordPath( keyword )
    if self.lookup[keyword] then return self.lookup[keyword] end
    local comp = { keyword:getName() }
    local parent = keyword:getParent()
    while parent do
        comp[#comp + 1] = parent:getName()
        parent = parent:getParent()
    end
    tab:reverseInPlace( comp )
    local kwPath = "/" .. table.concat( comp, "/" )
    self.lookup[keyword] = kwPath
    return kwPath
end

local _asdf

function Reportamus:keywordReport( title )
    app:call( Service:new{ name=title, async=true, progress=true, guard=App.guardVocal, main=function( call )
        call:initStats{ 'nil', '0', '1', '2', '3', '4', '5', 'bad' }
        self.lookup = {}
        call:setCaption( "Dialog box needs your attention..." )
        local targetPhotos = catalog:getMultipleSelectedOrAllPhotos()
        if #targetPhotos == 0 then
            app:show{ warning="No photos." }
            call:cancel()
            return
        end
        local allPhotos = catalog:getAllPhotos()
        local button = app:show{ confirm="Create Keyword Report? (report will be available for copy to clipboard via dialog box).",
            buttons = { dia:btn( str:fmtx( "Within Filmstrip (^1)", str:nItems( #targetPhotos, "photos" ) ), 'ok' ), dia:btn( str:fmtx( "Whole Catalog (^1)", str:nItems( #allPhotos, "photos" ) ), 'other' ) },
            actionPrefKey = "Create keyword report",
        }
        if button == 'cancel' then
            call:cancel()
            return
        end
        local limited
        if button == 'ok' then
            -- target-photos already set.
            limited = tab:createSet( targetPhotos )
        elseif button == 'other' then
            targetPhotos = allPhotos
            -- not limited.
        else
            error( "bad button" )
        end
        local inclPhotos = app:getPref( 'includePhotos' )
        local inclEmpties = not limited and app:getPref( 'includeEmptyKeywords' )
        local cachePhotos
        if not limited or inclEmpties then
            cachePhotos = allPhotos
        else -- limited and not including empties.
            cachePhotos = targetPhotos
        end
        call:setCaption( "Acquiring a batch of keyword metadata..." )
        local cache = lrMeta:createCache{ photos=cachePhotos, rawIds={ 'path', 'keywords', 'rating', 'isVirtualCopy' }, fmtIds={ 'copyName' } }
        call:setCaption( "Creating report..." )
        local keywordTable = {}
        -- note: incl-photos is not considered until 2nd phase.
        --[[ obs: save for a while...
        if limited and not inclEmpties then -- performance boost in case only considering photo keywords.
            for i, photo in ipairs( targetPhotos ) do
                local keywords = cache:getRawMetadata( photo, 'keywords' )
                for j, keyword in ipairs( keywords ) do
                    local keywordPath = self:_getKeywordPath( keyword )
                    local photos = keywordTable[keywordPath]
                    if photos == nil then
                        keywordTable[keywordPath] = {}
                        photos = keywordTable[keywordPath]
                    end
                    photos[#photos + 1] = photo
                end
            end
        else -- gotta go through all of 'em.
        --]]
        local addKids -- forward reference
        local function addKid( parentPath, kid )
            local photos = kid:getPhotos()
            local keywordPath = parentPath.."/"..kid:getName() -- self:_getKeywordPath( kid )
            if #photos > 0 or inclEmpties then
                if limited then
                    local include = {}
                    for i, photo in ipairs( photos ) do
                        if limited[photo] then
                            include[#include + 1] = photo
                        end
                    end
                    if #include > 0 or inclEmpties then
                        keywordTable[keywordPath] = include
                    else
                        app:logv( "Keyword has no photos in the target set - ignoring '^1'", keywordPath )
                    end
                else
                    keywordTable[keywordPath] = photos
                end
            else
                app:logv( "Keyword has no photos - ignoring '^1'", keywordPath )
            end
            addKids( parentPath.."/"..kid:getName(), kid:getChildren() )
        end
        function addKids( parentPath, kids ) -- local
            for i, kid in ipairs( kids ) do
                addKid( parentPath, kid )
            end
        end
        addKids( "", catalog:getKeywords() )
        --end
        -- 2nd phase:
        local b = {} -- line buffer.

        local sortFunc
        local sort
        local function customSort( one, two )
            --Debug.logn( LrPathUtils.leafName( one ), LrPathUtils.leafName( two ) )
            return sortFunc {
                keywordTable = keywordTable,
                keywordPathOne = one,
                keywordPathTwo = two
            }
        end
        sortFunc = app:getPref{ name='sortFunc', expectedType='function', default=nil  }
        if not sortFunc then
            app:log( "Using default keyword sort order." )
            sort = function( one, two )
                if LrPathUtils.leafName( two ) > LrPathUtils.leafName( one ) then return true end
            end
        else
            app:log( "Using custom keyword sort order." )
            sort = customSort
        end
            
        local inclBlanks = app:getPref( 'includeBlankLines' )
        local kwCount = tab:countItems( keywordTable )
        local index = 0
        local photoSeen = {}
        local sep = app:getPref( 'separator' )
        for keywordPath, photos in tab:sortedPairs( keywordTable, sort ) do
            call:setPortionComplete( index, kwCount )
            index = index + 1
            repeat
                assert( #photos > 0 or inclEmpties, "?" )
                local stats = Call:newStats{ 'nil', '0', '1', '2', '3', '4', '5', 'bad' } -- per-keyword stats.
                local maxRating = 0
                b[#b + 1] = "" -- reserve slot for hdr.
                local hdrIndex = #b
                for i, photo in ipairs( photos ) do
                    if inclPhotos then
                        b[#b + 1] = cat:getPhotoNameDisp( photo, true, cache )
                    end
                    local rating = cache:getRawMetadata( photo, 'rating' )
                    if rating ~= nil then
                        local sRating = str:to( rating )
                        if rating ~= 0 then
                            if rating <= 5 then
                                local stars = string.rep( '*', rating )
                                stats:incrStat( sRating )
                                call:incrStat( sRating )
                                b[#b] = b[#b].." "..stars
                                if rating > maxRating then
                                    maxRating = rating
                                end
                            else
                                stats:incrStat( 'bad' )
                                if not photoSeen[photo] then
                                    call:incrStat( 'bad' )
                                end
                            end
                        else
                            stats:incrStat( '0' )
                            if not photoSeen[photo] then
                                call:incrStat( '0' )
                            end
                        end
                    else
                        stats:incrStat( 'nil' )
                        if not photoSeen[photo] then
                            call:incrStat( 'nil' )
                        end
                    end
                    photoSeen[photo] = true
                end
                local rb = {}
                if stats:getStat( 'nil' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "unrated: ^1", stats:getStat( 'nil' ) )
                end
                if stats:getStat( '0' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "0: ^1", stats:getStat( '0' ) )
                end
                if stats:getStat( '1' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "* ^1", stats:getStat( '1' ) )
                end
                if stats:getStat( '2' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "** ^1", stats:getStat( '2' ) )
                end
                if stats:getStat( '3' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "*** ^1", stats:getStat( '3' ) )
                end
                if stats:getStat( '4' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "**** ^1", stats:getStat( '4' ) )
                end
                if stats:getStat( '5' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "***** ^1", stats:getStat( '5' ) )
                end
                if stats:getStat( 'bad' ) > 0 then
                    rb[#rb + 1] = str:fmtx( "bad rating: ^1", stats:getStat( 'bad' ) )
                end
                local ratings = table.concat( rb, " | " )
                b[hdrIndex] = str:fmtx( "^1 - ^2, max rating: ^3 (^4)", keywordPath, str:nItems( #photos, "photos" ), maxRating, ratings )
                if inclPhotos and inclBlanks then
                    b[#b + 1] = sep
                end
            until true
            if call:isQuit() then
                return
            end
        end
        call:setPortionComplete( 1 )
        local contents = table.concat( b, sep )
        call:setCaption( "Large reports take time to settle into dialog box..." )
        local ok = dialog:putTextOnClipboard{ title="Copy Keyword Report To Clipboard", contents=contents, dataName = "Report Info" }
        if ok then
            app:logv( "You promised text was copied to clipboard." )
        else
            app:logv( "You may have copied text to clipboard, but wouldn't swear to it." )
        end
                    
    end, finale=function( call )
        if call.status and not call:isCanceled() then
            app:log()
            app:log( "Totals:" )
            app:logStat( "^1 unrated", call:getStat( 'nil' ), "photos" )
            for i = 0, 5 do
                if call:getStat( str:to( i ) ) > 0 then
                    app:log( "Rating ^1: ^2", i, str:nItems( call:getStat( str:to( i ) ), "photos" ) )
                end
            end
            app:logStat( "^1 with bad rating value.", call:getStat( 'bad' ), "photos" )
            --app:log()
        end
        --Debug.showLogFile()
    end } )
end



return Reportamus