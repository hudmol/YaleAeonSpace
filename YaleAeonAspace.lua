function GetAuthenticationToken(username, password)
    Log("Username = " .. username);
    local apiPath = 'users/' .. username .. '/login'
    Log('apiPath = ' .. apiPath, LOG_INFO);

    local authenticationToken = JsonParser:ParseJSON(SendApiRequest(apiPath, 'POST', "password=".. UrlEncode(password)));

    if (authenticationToken == nil or authenticationToken == JsonParser.NIL or authenticationToken == '') then
        ReportError("Unable to get valid authentication token.");
        return;
    end

    return authenticationToken
end

function GetSession(webclient, username, password)
    local authentication = GetAuthenticationToken(username, password);
    local sessionId = ExtractProperty(authentication, "session");

    if (sessionId == nil or sessionId == JsonParser.NIL or sessionId == '') then
        ReportError("Unable to get valid session ID token.");
        return;
    end

    return sessionId;
end

function SendApiRequest(apiPath, method, parameters, authToken)
    Log('[SendApiRequest] ' .. method);
    Log('apiPath: ' .. apiPath);

    local webClient = Ctx.WebClient()

    webClient.Headers:Clear();
    if (authToken ~= nil and authToken ~= "") then
        webClient.Headers:Add("X-ArchivesSpace-Session", authToken);
    end

    local success, result;

    success, result = pcall(WebClientPost, webClient, apiPath, method, parameters);

    if (success) then
        Log("API call successful");
        Log("Response: " .. result);
        return result;
    else
        Log("API call error");
        OnError(result);
        return "";
    end
end

function WebClientPost(webClient, apiPath, method, postParameters)
    return webClient:UploadString(PathCombine(Ctx.BaseUrl, apiPath), method, postParameters);
end

function Logout(webclient, sessionId)
   webclient.QueryString = Ctx.NameValueCollection()
   webclient.Headers:Add("X-ArchivesSpace-Session", sessionId)

   pcall(webclient.UploadValues,
         webclient,
         Ctx.BaseUrl .. "users/logout",
         "POST",
         Ctx.NameValueCollection())
end

function PerformSearch(query)
   Log("PerformSearch", LOG_INFO)

   local webclient = Ctx.WebClient()
   local sessionId = GetSession(webclient, Ctx.Username, Ctx.Password)
   Log("ASpace sessionId = " .. sessionId)

   webclient.Headers:Add("X-ArchivesSpace-Session", sessionId)

   webclient.QueryString = Ctx.NameValueCollection()
   webclient.QueryString:Add("q", query)
   Log("ASpace query = " .. query)

   local success, result = pcall(webclient.DownloadString,
                                 webclient,
                                 Ctx.BaseUrl .. "plugins/yale_as_requests/search")

   pcall(Logout, webclient, sessionId)

   if (success) then
      local response = JsonParser:ParseJSON(result)
      return response
   else
      Log("API call error")
      OnError(result)
      Ctx.InterfaceManager:ShowMessage("ArchivesSpace search failed", "Network Error")
      error("Connection failure")
   end
end

function ShowMessageInGrid(grid, message)
   grid.GridControl:BeginUpdate()

   grid.GridControl.MainView.Columns:Clear()

   local msg = grid.GridControl.MainView.Columns:Add()
   msg.Caption = "Message"
   msg.FieldName = "Message"
   msg.Name = "Message"
   msg.Width = 10240
   msg.Visible = true
   msg.VisibleIndex = 0
   msg.OptionsColumn.ReadOnly = true

   local data = Ctx.DataTable()
   data.Columns:Add("Message")

   local row = data:NewRow();
   row:set_Item("Message", message)
   data.Rows:Add(row)

   grid.GridControl.DataSource = data

   grid.GridControl:EndUpdate()
   grid.GridControl:Refresh()
end


function ConfigureForm()
   local form = Ctx.InterfaceManager:CreateForm(Ctx.TabName, "ArchivesSpace Search")

   local ribbon = form:CreateRibbonPage("ArchivesSpace Search")

   local searchInput = form:CreateTextEdit("ArchivesSpaceSearch", "Search ArchivesSpace")
   local grid = form:CreateGrid("ArchivesSpaceGrid", "ArchivesSpace Results")

   local seenFields = {}

   function HandleSearchInput(sender, args)
      if tostring(args.KeyCode) == "Return: 13" then
         ShowMessageInGrid(grid, "Searching...")

         local results = PerformSearch(searchInput.Value)
         ShowSearchResults(form, results, grid)
      end
   end

   function HandleImport()
      local selection = grid.GridControl.MainView:GetFocusedRow()

      if selection == nil then
         Ctx.InterfaceManager:ShowMessage("No record selected", "Import Failed")
         return
      end

      -- Clear any previous fields
      for k in pairs(seenFields) do
         local success, _ = pcall(SetFieldValue, "Transaction", k, "")
      end

      seenFields = {}

      local success, requestJson = pcall(selection.get_Item, selection, "request_json")

      if not success then
         Ctx.InterfaceManager:ShowMessage("No record selected", "Import Failed")
         return
      end

      local mapped = JsonParser:ParseJSON(requestJson)
      for k in pairs(mapped) do
         local v = tostring(mapped[k]):sub(0, 255)
         local success, _ = pcall(SetFieldValue, "Transaction", k, v)

         if success then
            seenFields[k] = true
         else
            Log("Field not present in Transaction form: " .. k)
         end
      end

      ExecuteCommand("SwitchTab", {"Detail"})
   end

   searchInput.Editor.KeyDown:Add(HandleSearchInput)

   ribbon:CreateButton("Import Selected", GetClientImage("impt_32x32"), "HandleImport", "")

   form:Show()
end

function ShowSearchResults(form, results, grid)
   local tableData = Ctx.DataTable()

   grid.GridControl.MainView.Columns:Clear()

   for colIdx, columnDef in ipairs(results["columns"]) do
      local col = grid.GridControl.MainView.Columns:Add()
      col.Caption = columnDef["title"]
      col.FieldName = columnDef["request_field"]
      col.Name = columnDef["title"]
      col.Width = columnDef["width"]
      col.Visible = true
      col.VisibleIndex = colIdx
      col.OptionsColumn.ReadOnly = true

      tableData.Columns:Add(columnDef["request_field"])
   end

   local hiddenRequest = grid.GridControl.MainView.Columns:Add()
   hiddenRequest.Caption = "request_json"
   hiddenRequest.FieldName = "request_json"
   hiddenRequest.Name = "request_json"
   hiddenRequest.Width = 0
   hiddenRequest.Visible = false
   hiddenRequest.VisibleIndex = -1
   hiddenRequest.OptionsColumn.ReadOnly = true
   tableData.Columns:Add("request_json")

   for _, request in ipairs(results["requests"]) do
      local row = tableData:NewRow();

      for field in pairs(request) do
         local success, _ = pcall(row.set_Item, row, field, request[field])
         if not success then
            Log("Failed to set field: " .. field)
         end
      end

      tableData.Rows:Add(row)
   end

   if (tableData.Rows.Count == 0) then
      ShowMessageInGrid(grid, "No matching records were found")
   else
      grid.GridControl.DataSource = tableData
   end
end

--[[
ERROR HANDLING HELPERS
]]--
-- Internal intentional improved error handler
function ReportError(message)
    if (message == nil) then
        message = "Unspecific error";
    end

    Log("An error occurred: " .. message);
    interfaceMngr:ShowMessage("An error occurred:\r\n" .. message, "HM ArchivesSpace Addon");
end;

-- Primary Lua error handler
function OnError(e)
    Log("[OnError]");
    if e == nil then
        Log("OnError supplied a nil error");
        return;
    end

    if not e.GetType then
        -- Not a .NET type
        -- Attempt to log value
        pcall(function ()
            Log(e);
        end);
        return;
    else
        if not e.Message then
            Log(e:ToString());
            return;
        end
    end

    local message = TraverseError(e);

    if message == nil then
        message = "Unspecified Error";
    end

    ReportError(message);
end

-- Recursively logs exception messages and returns the innermost message to caller
function TraverseError(e)
    if not e.GetType then
        -- Not a .NET type
        return nil;
    else
        if not e.Message then
            -- Not a .NET exception
            Log(e:ToString());
            return nil;
        end
    end

    Log(e.Message);

    if e.InnerException then
        return TraverseError(e.InnerException);
    else
        return e.Message;
    end
end

--[[
GENERAL HELPERS
]]--
-- Makes a string appropriate for use in a URL
function UrlEncode(str)
	if (str) then
		str = string.gsub (str, "\n", "\r\n");

		str = string.gsub (str, "([^%w ])",
			function (c) return string.format ("%%%02X", string.byte(c)) end);

		str = string.gsub (str, " ", "+");
	end

	return str;
end

-- Safely gets a property from an object
function ExtractProperty(object, property)
    if object then
        return EmptyStringIfNil(object[property]);
    end
end

-- Ensures use of empty string rather than `nil` when you want
function EmptyStringIfNil(value)
    if (value == nil or value == JsonParser.NIL) then
        return "";
    else
        return value;
    end
end

-- Combines two parts of a path, ensuring they're separated by a / character
function PathCombine(path1, path2)
    local trailingSlashPattern = '/$';
    local leadingSlashPattern = '^/';

    if(path1 and path2) then
        local result = path1:gsub(trailingSlashPattern, '') .. '/' .. path2:gsub(leadingSlashPattern, '');
        return result;
    else
        return "";
    end
end
