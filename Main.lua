LogInfo("Loading YaleAeonSpace plugin")

luanet.load_assembly("System")
luanet.load_assembly("System.Data")
luanet.load_assembly("System.Net")

require("Atlas-Addons-Lua-ParseJson.JsonParser")

Ctx = {
   Encoding = luanet.import_type("System.Text.Encoding"),
   DataTable = luanet.import_type("System.Data.DataTable"),
   WebClient = luanet.import_type("System.Net.WebClient"),
   NameValueCollection = luanet.import_type("System.Collections.Specialized.NameValueCollection"),
   InterfaceManager = GetInterfaceManager(),
   BaseUrl = GetSetting("ArchivesSpaceAPIURL"),
   Username = GetSetting("ArchivesSpaceUser"),
   Password = GetSetting("ArchivesSpacePassword"),
   TabName = GetSetting("TabName"),
   LogLabel = GetSetting("LogLabel")
}

require("Logging");

-- Base URL requires a trailing slash
Ctx.BaseUrl = string.gsub(Ctx.BaseUrl .. "/", "/+$", "/")

function fileExists(path)
   local fh = io.open(path, "r")

   if fh == nil then
      return false
   else
      io.close(fh)
      return true
   end
end


function findInPath(name)
   local haystack = package.path .. ";"

   local start_idx = 0

   while true do
      end_idx = string.find(haystack, ";", start_idx)

      if end_idx == nil then
         break
      end

      local pattern = string.sub(haystack, start_idx, end_idx - 1)

      if (fileExists(string.gsub(pattern, "?", name))) then
         result, _ = string.gsub(pattern, "?", name)
         return result
      end

      start_idx = end_idx + 1
   end

   return nil
end


function Init()
   local mainProgram = findInPath("YaleAeonAspace")
   dofile(mainProgram)

   Ctx.PluginBaseDir = mainProgram:match("(.*\\)")

   ConfigureForm()
end
