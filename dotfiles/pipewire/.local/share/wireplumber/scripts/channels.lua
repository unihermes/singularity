-- Singularity - new playback lands on Media, a game's on Game
--
-- Runs where wireplumber would fall back to the default output: a stream
-- with no target of its own (not moved, not remembered on another output)
-- plays on Game if it's a game, else on Media, when that channel is there.
-- A game is anything under Wine/Proton, Java (Minecraft, from Modrinth or
-- any launcher) or a stream that says it is one (SDL3's default role).
-- The channels' own streams (singularity.channel) still go to the default,
-- which is how they reach the real output.

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

    local binary = si_props ["application.process.binary"] or ""
    local isGame = binary:match ("^wine") or binary:match ("^proton")
        or binary == "java" or si_props ["media.role"] == "Game"
    local name = isGame and "game" or "media"
    local channel = om:lookup {
      type = "SiLinkable",
      Constraint { "node.name", "=", "channel." .. name },
    }
    if channel and lutils.canLink (si_props, channel) then
      log:info (si, "... channel picked: " .. name)
      event:set_data ("target", channel)
    end
  end
}:register ()
