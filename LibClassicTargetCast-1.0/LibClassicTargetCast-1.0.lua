local _, ns = ...

local MAJOR, MINOR = "LibClassicTargetCast-1.0", 1
local LibStub = LibStub
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local _G = getfenv(0)

local channeledSpells = ns.channeledSpells
local castTimeDecreases = ns.castTimeDecreases
local castTimeTalentDecreases = ns.castTimeTalentDecreases
local crowdControls = ns.crowdControls

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

lib.spellCache = {};

local logScanner = CreateFrame("Frame");

logScanner:RegisterEvent("PLAYER_LOGIN")

logScanner:SetScript("OnEvent", function(self, event, ...)
    -- this will basically trigger EVENT_NAME(arguments)
    return self[event](self, ...)
end)

function logScanner:CastPushback(unitGUID, percentageAmount, auraFaded)
    local cast = lib.spellCache[unitGUID]
    if not cast then return end

    -- if cast.prevCurrTimeModValue then print("stored total:", #cast.prevCurrTimeModValue) end

    -- Set cast time modifier (i.e Curse of Tongues)
    if not auraFaded and percentageAmount and percentageAmount > 0 then
        if not cast.currTimeModValue or cast.currTimeModValue < percentageAmount then -- run only once unless % changed to higher val
            if cast.currTimeModValue then -- already was reduced
                -- if existing modifer is e.g 50% and new is 60%, we only want to adjust cast by 10%
                percentageAmount = percentageAmount - cast.currTimeModValue

                -- Store previous lesser modifier that was active
                cast.prevCurrTimeModValue = cast.prevCurrTimeModValue or {}
                cast.prevCurrTimeModValue[#cast.prevCurrTimeModValue + 1] = cast.currTimeModValue
                -- print("stored lesser modifier")
            end

            -- print("refreshing timer", percentageAmount)
            cast.currTimeModValue = (cast.currTimeModValue or 0) + percentageAmount -- highest active modifier
            cast.maxValue = cast.maxValue + (cast.maxValue * percentageAmount) / 100
            cast.endTime = cast.endTime + (cast.maxValue * percentageAmount) / 100
        elseif cast.currTimeModValue == percentageAmount then
            -- new modifier has same percentage as current active one, just store it for later
            -- print("same percentage, storing")
            cast.prevCurrTimeModValue = cast.prevCurrTimeModValue or {}
            cast.prevCurrTimeModValue[#cast.prevCurrTimeModValue + 1] = percentageAmount
        end
    elseif auraFaded and percentageAmount then
        -- Reset cast time modifier
        if cast.currTimeModValue == percentageAmount then
            cast.maxValue = cast.maxValue - (cast.maxValue * percentageAmount) / 100
            cast.endTime = cast.endTime - (cast.maxValue * percentageAmount) / 100
            cast.currTimeModValue = nil

            -- Reset to lesser modifier if available
            if cast.prevCurrTimeModValue then
                local highest, index = 0
                for i = 1, #cast.prevCurrTimeModValue do
                    if cast.prevCurrTimeModValue[i] and cast.prevCurrTimeModValue[i] > highest then
                        highest, index = cast.prevCurrTimeModValue[i], i
                    end
                end

                if index then
                    cast.prevCurrTimeModValue[index] = nil
                    -- print("resetting to lesser modifier", highest)
                    return self:CastPushback(unitGUID, highest)
                end
            end
        end

        if cast.prevCurrTimeModValue then
            -- Delete 1 old modifier (doesn't matter which one aslong as its the same %)
            for i = 1, #cast.prevCurrTimeModValue do
                if cast.prevCurrTimeModValue[i] == percentageAmount then
                    -- print("deleted lesser modifier, new total:", #cast.prevCurrTimeModValue - 1)
                    cast.prevCurrTimeModValue[i] = nil
                    return
                end
            end
        end
    else -- normal pushback
        if not cast.isChanneled then
            cast.maxValue = cast.maxValue + 0.5
            cast.endTime = cast.endTime + 0.5
        else
            -- channels are reduced by 25%
            cast.maxValue = cast.maxValue - (cast.maxValue * 25) / 100
            cast.endTime = cast.endTime - (cast.maxValue * 25) / 100
        end
    end
end

function lib.UnitCastingInfo(unit)
    local unitGUID = UnitGUID(unit)
    if lib.spellCache[unitGUID] and not lib.spellCache[unitGUID].isChanneled then
        return lib.spellCache[unitGUID].spellName, lib.spellCache[unitGUID].rank, lib.spellCache[unitGUID].spellIcon, lib.spellCache[unitGUID].startTime, lib.spellCache[unitGUID].endTime, false, lib.spellCache[unitGUID].castID,false
    end
end

function lib.UnitChannelInfo(unit)
    local unitGUID = UnitGUID(unit)
    if lib.spellCache[unitGUID] and lib.spellCache[unitGUID].isChanneled then
        return lib.spellCache[unitGUID].spellName, lib.spellCache[unitGUID].rank, lib.spellCache[unitGUID].spellIcon, lib.spellCache[unitGUID].startTime, lib.spellCache[unitGUID].endTime, false, false
    end
end

function logScanner:PLAYER_LOGIN()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_LOGIN")
end

function logScanner.PLAYER_ENTERING_WORLD()
    -- Clear the Cache
    lib.spellCache = {};
    -- Fire in case consuming addon needs to initialise anything
    lib.callbacks:Fire("PLAYER_ENTERING_WORLD")
end

function logScanner.PLAYER_TARGET_CHANGED()
    local target = UnitGUID("target")
    if lib.spellCache[target] then
        lib.callbacks:Fire("PLAYER_TARGET_CHANGED", "target", lib.spellCache[target].castID, lib.spellCache[target].spellID)
    else
        lib.callbacks:Fire("PLAYER_TARGET_CHANGED", "target", nil, nil)
    end
end

local bit_band = _G.bit.band
local COMBATLOG_OBJECT_TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER

function logScanner:COMBAT_LOG_EVENT_UNFILTERED()
    local _, eventType, _, srcGUID, _, _, _, dstGUID,  _, dstFlags, _, spellID, spellName, _, _, _, _, resisted, blocked, absorbed = CombatLogGetCurrentEventInfo()

    local currTime = GetTime();
    local castID = ""..srcGUID.."_"..spellName..""..currTime; -- Fake a cast GUID

    if eventType == "SPELL_CAST_START" then
        local _, _, icon, castTime = GetSpellInfo(spellID)
        if not castTime or castTime == 0 then return end
        local rank = GetSpellSubtext(spellID) -- async so won't work on first try but thats okay

        --Reduce cast time for certain spells
        -- local reducedTime = castTimeTalentDecreases[spellName]
        -- if reducedTime then
        --     castTime = castTime - (reducedTime * 1000)
        -- end

        lib.spellCache[srcGUID] = {
            castID = castID,
            spellName = spellName,
            rank = rank,
            spellIcon = icon,
            startTime = currTime,
            endTime = currTime + castTime,
            maxValue = castTime,
            isChanneled = false,
            spellID = spellID,
        }

        if srcGUID == UnitGUID("target") then
            lib.callbacks:Fire("UNIT_SPELLCAST_START", "target", castID, spellID)
        end

    elseif eventType == "SPELL_CAST_SUCCESS" then
        -- Channeled spells are started on SPELL_CAST_SUCCESS instead of stopped
        -- Also there's no castTime returned from GetSpellInfo for channeled spells so we need to get it from our own list
        local castTime = channeledSpells[spellName]
        if castTime then
            if currTime + castTime > GetTime() then
                local rank = GetSpellSubtext(spellID) -- async so won't work on first try but thats okay
                local _, _, icon = GetSpellInfo(spellID)
                lib.spellCache[srcGUID] = {
                    castID = 0,
                    spellName = spellName,
                    rank = rank,
                    spellIcon = icon,
                    startTime = currTime,
                    endTime = currTime + castTime,
                    maxValue = castTime,
                    isChanneled = true,
                    spellID = spellID,
                }

                if srcGUID == UnitGUID("target") then
                    lib.callbacks:Fire("UNIT_SPELLCAST_CHANNEL_START", "target", 0, spellID)
                end
            else
                -- assume the channeled spell is ending
                if lib.spellCache[srcGUID] then
                    if srcGUID == UnitGUID("target") then
                        lib.callbacks:Fire("UNIT_SPELLCAST_CHANNEL_STOP", "target", 0, spellID)
                    end
                    lib.spellCache[srcGUID] = nil
                end
            end
        end
        lib.callbacks:Fire("UNIT_SPELLCAST_STOP", "target", castID, spellID)
        lib.spellCache[srcGUID] = nil
    elseif eventType == "SPELL_CAST_FAILED" then
        if lib.spellCache[srcGUID] then
            if srcGUID == UnitGUID("target") then
                lib.callbacks:Fire("UNIT_SPELLCAST_FAILED", "target", lib.spellCache[srcGUID].castID, lib.spellCache[srcGUID].spellID)
            end
            lib.spellCache[srcGUID] = nil
        end
    elseif eventType == "SPELL_AURA_APPLIED" then
        if castTimeDecreases[spellID] then
            -- Aura that slows casting speed was applied
            self:CastPushback(dstGUID, castTimeDecreases[spellID])
            if lib.spellCache[dstGUID] and dstGUID == UnitGUID("target") then
                lib.callbacks:Fire("UNIT_SPELLCAST_DELAYED", "target", castID, spellID)
            end
        elseif crowdControls[spellName] then
            if lib.spellCache[dstGUID] then
                if dstGUID == UnitGUID("target") then
                    lib.callbacks:Fire("UNIT_SPELLCAST_STOP", "target", castID, spellID)
                end
                lib.spellCache[dstGUID] = nil
            end
        end
    elseif eventType == "SPELL_AURA_REMOVED" then
        -- Channeled spells has no SPELL_CAST_* event for channel stop,
        -- so check if aura is gone instead since most (all?) channels has an aura effect
        if channeledSpells[spellName] then
            if lib.spellCache[srcGUID] then
                if srcGUID == UnitGUID("target") then
                    lib.callbacks:Fire("UNIT_SPELLCAST_STOP", "target", castID, spellID)
                end
                lib.spellCache[srcGUID] = nil
            end
        elseif castTimeDecreases[spellID] then
             -- Aura that slows casting speed was removed
            if lib.spellCache[dstGUID] then
                self:CastPushback(dstGUID, castTimeDecreases[spellID], true)
                if dstGUID == UnitGUID("target") then
                    lib.callbacks:Fire("UNIT_SPELLCAST_DELAYED", "target", castID,spellID)
                end
            end
        end
        elseif eventType == "PARTY_KILL" or eventType == "UNIT_DIED" or eventType == "SPELL_INTERRUPT" then
            if lib.spellCache[dstGUID] then
                if dstGUID == UnitGUID("target") then
                    lib.callbacks:Fire("UNIT_SPELLCAST_STOP", "target", castID, spellID)
                end
                lib.spellCache[dstGUID] = nil
            end
    elseif eventType == "SWING_DAMAGE" or eventType == "ENVIRONMENTAL_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SPELL_DAMAGE" then
        if resisted or blocked or absorbed then return end
        if bit_band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then -- is player
            if lib.spellCache[dstGUID] then
                self:CastPushback(dstGUID)
                if dstGUID == UnitGUID("target") then
                    lib.callbacks:Fire("UNIT_SPELLCAST_DELAYED", "target", castID, spellID)
                end
            end
        end
    end
end
