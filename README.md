# LibClassicCast

NOTE: This is a library for Addon authors to use in their addons. It won't do anything as an addon itself.

Library for handling target casts (using CLEU parsing based on ClassicCastbars)

This library is designed to mimic the builtin functions and events relating to spellcasting for your target. Not all events are possible in classic so this addon publishes a reduced set of events (using LibCallbackHandler) -

The "events" that LibClassicCast fires are:

```Lua
"PLAYER_ENTERING_WORLD"
"PLAYER_TARGET_CHANGED"
"UNIT_SPELLCAST_START"
"UNIT_SPELLCAST_STOP"
"UNIT_SPELLCAST_FAILED"
"UNIT_SPELLCAST_DELAYED"
"UNIT_SPELLCAST_CHANNEL_START"
"UNIT_SPELLCAST_CHANNEL_STOP"
```

In addition LibClassicCast provides implementations for UnitCastingInfo and UnitChannelInfo which mimic the equivalent Blizzard responses but may not be 100% accurate due to the difference in approach required

## Usage

1. Make sure LibStub and LibCallbackHandler are available and loaded in your .TOC (or wherever)

2. Obtain a reference to LibClassicCast

    ```Lua
    local LibCC = LibStub("LibClassicCast")
    ```

3. To register for callback simply register using RegisterCallback in the same way as you would register for events:

    e.g.

    ```Lua
    LibCC.RegisterCallback(self,"UNIT_SPELLCAST_STOP");
    ```

    Then handle the callback as you would any of the same events in Retail - e.g.

    ```Lua
    -- Cast Stop
    function myaddon:UNIT_SPELLCAST_STOP(event,unit,castID,spellID)
        if (self.isCast) and (self.castID == castID) and not (self.fadeTime) and not (self.tradeCount) then
            self.status:SetValue(self.castTime);
            self:StartFadeOut();
        end
    end
    ```

4. To inquire about the spell being cast by a unit call the info functions with the same returns as Retail (note: there's some faking - e.g. currently isTrade and isNoninterruptible are returning false always - working on a fix)

    ```Lua
    spellName, rank, texture, startTime, endTime, isTrade, castID, nonInterruptible = LibCTC:UnitCastingInfo(unit);
    ```

    or for a channeled spell its:

    ```Lua
    spellName, rank, texture, startTime, endTime, isTrade, nonInterruptible = LibCTC:UnitChannelInfo(unit);
    ```

## Known Issues

There are some (rare) occasions when, for whatever reason, the CLEU doesn't catch a fail/interrupt on a spell and therefore the ..FAIL and/or ..STOP events don't fire. Really not much can be done about this... sorry. Allow your castbar to just complete out I guess.
