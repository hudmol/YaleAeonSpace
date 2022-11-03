-- Pseudo-constants
LOG_DEBUG = "DEBUG"
LOG_INFO = "INFO"
LOG_WARN = "WARN"

--
--   YaleAeonSpace Aeon Client Addon -- Logging.lua
--
--   Simple routine to add a prefix for all log entries
--

function Log(msg, logLevel)
	logLevel = logLevel or LOG_DEBUG -- de facto default param value

	if (string.lower(logLevel) == "debug") then
		LogDebug(Ctx.LogLabel .. ": " .. msg);
	elseif (string.lower(logLevel) == "info") then
		LogInfo(Ctx.LogLabel .. ": " .. msg);
	elseif (string.lower(logLevel) == "warn") then
		LogWarn(Ctx.LogLabel .. ": " .. msg);
	else
		LogInfo(Ctx.LogLabel .. ": " .. msg);
	end
end
