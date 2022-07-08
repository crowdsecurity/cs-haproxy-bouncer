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

return M