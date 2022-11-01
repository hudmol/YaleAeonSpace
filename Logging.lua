--
--   YaleAeonSpace Aeon Client Addon -- Logging.lua
--
--   Simple routine to add a prefix for all log entries
--

function Log(msg)
	LogDebug(settings.LogLabel .. ": " .. msg);
end
