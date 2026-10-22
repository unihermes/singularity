-- Singularity - new playback lands on the Game channel
--
-- Runs where wireplumber would fall back to the default output: a stream
-- with no target of its own (not moved, not remembered on another output)
-- plays on Game instead, when Game is there. The channels' own streams
-- (singularity.channel) still go to the default, which is how they reach
-- the real output.

lutils = require ("linking-utils")
log = Log.open_topic ("s-linking")

SimpleEventHook {
  name = "linking/singularity-channels",
  after = { "linking/find-defined-target",
            "linking/find-filter-target",
            "linking/find-media-role-target",
            "linking/find-audio-group-target" },
  before = "linking/find-default-target",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-target" },
    },
  },
  execute = function (event)
    local _, om, si, si_props, _, target =
        lutils:unwrap_select_target_event (event)
    if target or si_props ["media.class"] ~= "Stream/Output/Audio"
        or si_props ["singularity.channel"] then
      return
    end

    local game = om:lookup {
      type = "SiLinkable",
      Constraint { "node.name", "=", "channel.game" },
    }
    if game and lutils.canLink (si_props, game) then
      log:info (si, "... channel picked: Game")
      event:set_data ("target", game)
    end
  end
}:register ()
