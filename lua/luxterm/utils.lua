local M = {}

--- Calculate size in columns/lines from percentage
-- @param percentage number
-- @param total number
-- @return number
function M.percent_size(percentage, total)
  return math.floor(total * percentage)
end

return M
