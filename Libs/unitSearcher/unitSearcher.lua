local major, minor = "unitSearcher", 1
local unitSearcher, oldminor = LibStub:NewLibrary(major, minor)

if not oldminor or minor > oldminor then

  --we want this to be an upvalue so we never have to make it again. Just call CopyTable on Primitives
  local primitives = {
    'player', 'target', 'mouseover', 'focus', 'pet', 'npc', 'vehicle', 'party1', 'party2', 'party3', 'party4', 
    'partypet1', 'partypet2', 'partypet3', 'partypet4', 'boss1', 'boss2', 'boss3', 'boss4', 'boss5', 'arena1', 'arena2', 'arena3', 
    'arena5', 'arena5', 'raid1', 'raid2', 'raid3', 'raid4', 'raid5', 'raid6', 'raid7', 'raid8', 'raid9', 'raid10', 'raid11', 
    'raid12', 'raid13', 'raid14', 'raid15', 'raid16', 'raid17', 'raid18', 'raid19', 'raid20', 'raid21', 'raid22', 'raid23', 'raid24',
    'raid25', 'raid26', 'raid27', 'raid28', 'raid29', 'raid30', 'raid31', 'raid32', 'raid33', 'raid34', 'raid35', 'raid36', 'raid37', 
    'raid38', 'raid39', 'raid40','raidpet1', 'raidpet2', 'raidpet3', 'raidpet4', 'raidpet5', 'raidpet6', 'raidpet7', 'raidpet8', 
    'raidpet9', 'raidpet10', 'raidpet11', 'raidpet12', 'raidpet13', 'raidpet14', 'raidpet15', 'raidpet16', 'raidpet17', 'raidpet18', 
    'raidpet19', 'raidpet20', 'raidpet21', 'raidpet22', 'raidpet23', 'raidpet24', 'raidpet25', 'raidpet26', 'raidpet27', 'raidpet28', 
    'raidpet29', 'raidpet30', 'raidpet31', 'raidpet32', 'raidpet33', 'raidpet34', 'raidpet35', 'raidpet36', 'raidpet37', 'raidpet38', 
    'raidpet39', 'raidpet40', 'nameplate1', 'nameplate2', 'nameplate3', 'nameplate4', 'nameplate5', 'nameplate6', 'nameplate7', 
    'nameplate8', 'nameplate9', 'nameplate10', 'nameplate11', 'nameplate12', 'nameplate13', 'nameplate14', 'nameplate15', 'nameplate16', 
    'nameplate17', 'nameplate18', 'nameplate19', 'nameplate20', 'nameplate21', 'nameplate22', 'nameplate23', 'nameplate24', 
    'nameplate25', 'nameplate26', 'nameplate27', 'nameplate28', 'nameplate29', 'nameplate30', 'nameplate31', 'nameplate32', 
    'nameplate33', 'nameplate34', 'nameplate35', 'nameplate36', 'nameplate37', 'nameplate38', 'nameplate39', 'nameplate40', 
  }

  local candidates = {}
  local validUnits = {}
  local lastSearched = 0

  function unitSearcher:GetAllUnitIDs()
    if lastSearched ~= GetTime() then
      lastSearched = GetTime()
      validUnits = {}
    else
      -- there won't be any new information, no point in doing a search
      return validUnits
    end
    candidates = CopyTable(primitives)
    while #candidates > 0 do
      --we go backwards because it was easier for me
      for i = #candidates,1,-1 do
        local unit, GUID = candidates[i], UnitGUID(candidates[i])
        --can't just pop the final bit off, since we do insert other bits on
        tremove(candidates,i)
        if UnitExists(unit) then
          --keying by GUID allows us to quickly find duplicates
          if not validUnits[GUID] or #validUnits[GUID] > #unit then
            validUnits[GUID] = unit
            --needs to go on the end so as to not corrupt the traversal
            tinsert(candidates,unit..'target')
          end
        end
      end
    end
    return validUnits
  end

  function unitSearcher:GetUnitID(GUID)
    local unit = validUnits[GUID]
    if unit and UnitGUID(unit) == GUID then
      return unit
    end
    return unitSearcher:GetAllUnitIDs()[GUID]
  end
end