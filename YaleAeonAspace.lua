function GetSession(webclient, username, password)
   local params = Ctx.NameValueCollection()
   params:Add("password", password)

   local success, result = pcall(webclient.UploadValues,
                                 webclient,
                                 Ctx.BaseUrl .. "users/" .. username .. "/login",
                                 "POST",
                                 params)

   if (success) then
      local response = JsonParser:ParseJSON(Ctx.Encoding.UTF8:GetString(result))

      return response["session"]
   else
      Ctx.InterfaceManager:ShowMessage("Connection to ArchivesSpace failed.", "Network Error")
   end
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
   LogInfo("PerformSearch")

   local webclient = Ctx.WebClient()
   local sessionId = GetSession(webclient, Ctx.Username, Ctx.Password)

   webclient.Headers:Add("X-ArchivesSpace-Session", sessionId)

   webclient.QueryString = Ctx.NameValueCollection()
   webclient.QueryString:Add("q", query)

   local success, result = pcall(webclient.DownloadString,
                                 webclient,
                                 Ctx.BaseUrl .. "plugins/yale_as_requests/search")

   pcall(Logout, webclient, sessionId)

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

   local ribbon = form:CreateRibbonPage("ArchivesSpace")

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
            LogDebug("Field not present in Transaction form: " .. k)
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
