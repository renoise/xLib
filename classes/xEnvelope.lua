--[[===============================================================================================
xEnvelope
===============================================================================================]]--

--[[--

A virtual representation of an envelope (automation, LFO or otherwise)
.
#

Note: the class is modelled over the Renoise EnvelopeSelectionContent, 

]]

--==============================================================================

require(_clibroot.."cPersistence")

---------------------------------------------------------------------------------------------------

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

  -- number, the amount of lines covered if envelope was applied to a pattern
  self.number_of_lines = property(self._get_number_of_lines)

  cPersistence.__init(self)

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
-- amount of lines covered if envelope was applied to a pattern
-- @return number

function xEnvelope:_get_number_of_lines()
  TRACE("xEnvelope:_get_number_of_lines()")

  if table.is_empty(self.points) then 
    return 0
  end

  local last_time = self.points[#self.points].time 
  return cLib.round_value(last_time-1)

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

