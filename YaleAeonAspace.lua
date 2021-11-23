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

function ConfigureForm()
   local form = Ctx.InterfaceManager:CreateForm("ArchivesSpace", "ArchivesSpace")
   local ribbon = form:CreateRibbonPage("Cool ArchivesSpace Stuff")

   ribbon:CreateButton("Kersplode", nil, "toot", "toot")

   local grid = form:CreateGrid("ArchivesSpaceGrid", "ArchivesSpace Results")
   local tableData = Ctx.DataTable()

   local dummyData = LoadSampleData()

   for colIdx, columnDef in ipairs(dummyData["columns"]) do
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
   hiddenRequest.Caption = "RawRequest"
   hiddenRequest.FieldName = "RawRequest"
   hiddenRequest.Name = "RawRequest"
   hiddenRequest.Width = 0
   hiddenRequest.Visible = false
   hiddenRequest.VisibleIndex = -1
   hiddenRequest.OptionsColumn.ReadOnly = true
   tableData.Columns:Add("RawRequest")

   LogInfo("Walking requests")

   for _, request in ipairs(dummyData["requests"]) do
      local row = tableData:NewRow();

      LogInfo("Adding new row")

      for field in pairs(request) do
	 row:set_Item(field, request[field])
      end

      row:set_Item("RawRequest", serializeKvs(request))

      tableData.Rows:Add(row)
   end

   LogInfo("DONE Walking requests")

   grid.GridControl.DataSource = tableData

   form:Show()
end
