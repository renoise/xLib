--[[===============================================================================================
xEnvelope
===============================================================================================]]--

--[[--

A virtual representation of an envelope (automation, LFO or otherwise)
.
#

Note: the class is modelled over the Renoise EnvelopeSelectionContent, 

]]

--=================================================================================================

class 'xEnvelope' (cPersistence)

xEnvelope.__PERSISTENCE = {
  "points"
}

---------------------------------------------------------------------------------------------------

function xEnvelope:__init()
  TRACE("xEnvelope:__init()")

  -- the point values - array of {
  --  time,     -- point time 
  --  value,    -- point value
  --  playmode, -- interpolation type (renoise.PatternTrackAutomation.PLAYMODE_XX)
  --  } 
  self.points = {}

  -- number, the total length of the envelope (RangeLength in EnvelopeSelectionContent)
  --self.length = nil

  cPersistence.__init(self)

  oprint(self)

end  

---------------------------------------------------------------------------------------------------
-- check if the automation specifies any points 
-- (shared interface with xEnvelope)
-- @return boolean

function xEnvelope:has_points()
  TRACE("xEnvelope:has_points()")
  
  return (#self.points > 0) 

end 

---------------------------------------------------------------------------------------------------

function xEnvelope:__tostring()
  return type(self)
    .. ",#points=" .. tostring(#self.points)
end

--=================================================================================================
-- Static methods
--=================================================================================================

--[[

TODO: common methods such as shift, mirror, etc. 

]]

