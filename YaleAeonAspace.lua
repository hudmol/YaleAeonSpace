-- FIXME: ditch serialize
-- FIXME: reuse session id?

require "hmserialize"

function LoadSampleData()
   local fh = io.open(Ctx.PluginBaseDir .. "sample.json", "r")
   if fh == nil then
      return nil
   end

   local s = fh:read("*all")
   io.close(fh)

   return JsonParser:ParseJSON(s)
end

-- FIXME: config
BaseUrl = "http://dishevelled.net:4567/"

function GetSession(webclient, username, password)
   local params = Ctx.NameValueCollection()
   params:Add("password", password)
   params:Add("expiring", "false")

   local success, result = pcall(webclient.UploadValues,
				 webclient,
				 BaseUrl .. "users/" .. username .. "/login",
				 "POST",
				 params)

   if (success) then
      local response = JsonParser:ParseJSON(Ctx.Encoding.UTF8:GetString(result))

      return response["session"]
   else
      Ctx.InterfaceManager:ShowMessage("Connection to ArchivesSpace failed.", "Network Error")
   end

end

function PerformSearch(query)
   LogInfo("PerformSearch")

   local webclient = Ctx.WebClient()
   local sessionId = GetSession(webclient, "admin", "admin")

   webclient.Headers:Add("X-ArchivesSpace-Session", sessionId)

   webclient.QueryString = Ctx.NameValueCollection()
   webclient.QueryString:Add("q", query)

   local success, result = pcall(webclient.DownloadString,
				 webclient,
				 BaseUrl .. "plugins/yale_as_requests/search")

   if (success) then
      local response = JsonParser:ParseJSON(result)
      return response
   else
      Ctx.InterfaceManager:ShowMessage("Connection to ArchivesSpace failed.", "Network Error")
   end
end

function ShowMessageInGrid(grid, message)
   grid.GridControl:BeginUpdate()

   grid.GridControl.MainView.Columns:Clear()

   local msg = grid.GridControl.MainView.Columns:Add()
   msg.Caption = "Message"
   msg.FieldName = "Message"
   msg.Name = "Message"
   msg.width = 10240
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
   local form = Ctx.InterfaceManager:CreateForm("ArchivesSpace", "ArchivesSpace")

   form:CreateRibbonPage("ArchivesSpace")

   local searchInput = form:CreateTextEdit("ArchivesSpaceSearch", "Search ArchivesSpace")
   local grid = form:CreateGrid("ArchivesSpaceGrid", "ArchivesSpace Results")

   function HandleSearchInput(sender, args)
      if tostring(args.KeyCode) == "Return: 13" then
	 ShowMessageInGrid(grid, "Searching...")

	 local results = PerformSearch(searchInput.Value)
	 ShowSearchResults(form, results, grid)
      end
   end

   searchInput.Editor.KeyDown:Add(HandleSearchInput)

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
	    LogDebug("Failed to set field: " .. field)
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
