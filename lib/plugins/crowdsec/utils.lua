local M = {}


function M.read_file(path)
   local file = io.open(path, "r") -- r read mode and b binary mode
   if not file then return nil end
   io.input(file)
   content = io.read("*a")
   io.close(file)
   return content
 end

function M.file_exist(path)
 if path == nil then
   return nil
 end
 local f = io.open(path, "r")
 if f ~= nil then 
   io.close(f)
   return true 
 else 
   return false
 end
end

function M.starts_with(str, start)
    return str:sub(1, #start) == start
 end
 
 function M.ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
 end

function M.table_len(table)
   local count = 0
   for k, v in pairs(table) do
      count = count + 1
   end
   return count
end

function M.accept_html(applet)
   if applet.headers["accept"] == nil then
      return true
   end
   for _, accept in pairs(applet.headers["accept"]) do
      for _, value in pairs({"*/*", "text", "html"}) do
         local found_min, found_max = string.find(accept, value)
         if found_min ~= nil then
             return true
         end
      end
   end
   return false
end


return M