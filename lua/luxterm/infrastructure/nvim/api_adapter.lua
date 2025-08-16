local M = {
  batch_operations = {},
  batch_timer = nil,
  batch_delay_ms = 16
}

function M.setup(opts)
  opts = opts or {}
  M.batch_delay_ms = opts.batch_delay_ms or 16
end

function M.batch_buf_set_lines(bufnr, start, end_, strict_indexing, replacement)
  M._add_to_batch("buf_set_lines", {
    bufnr = bufnr,
    start = start,
    end_ = end_,
    strict_indexing = strict_indexing,
    replacement = replacement
  })
end

function M.batch_buf_set_option(bufnr, name, value)
  M._add_to_batch("buf_set_option", {
    bufnr = bufnr,
    name = name,
    value = value
  })
end

function M.batch_win_set_option(winid, name, value)
  M._add_to_batch("win_set_option", {
    winid = winid,
    name = name,
    value = value
  })
end

function M.batch_set_hl(ns_id, name, val)
  M._add_to_batch("set_hl", {
    ns_id = ns_id,
    name = name,
    val = val
  })
end

function M._add_to_batch(operation, args)
  table.insert(M.batch_operations, {
    operation = operation,
    args = args
  })
  
  M._schedule_batch_flush()
end

function M._schedule_batch_flush()
  if M.batch_timer then
    return
  end
  
  M.batch_timer = vim.loop.new_timer()
  M.batch_timer:start(M.batch_delay_ms, 0, vim.schedule_wrap(function()
    M._flush_batch()
  end))
end

function M._flush_batch()
  if M.batch_timer then
    M.batch_timer:stop()
    M.batch_timer:close()
    M.batch_timer = nil
  end
  
  local operations = M.batch_operations
  M.batch_operations = {}
  
  local grouped_operations = M._group_operations(operations)
  
  for _, group in ipairs(grouped_operations) do
    M._execute_operation_group(group)
  end
end

function M._group_operations(operations)
  local groups = {}
  local current_group = {}
  
  for _, op in ipairs(operations) do
    if op.operation == "buf_set_lines" then
      if #current_group > 0 then
        table.insert(groups, current_group)
        current_group = {}
      end
      table.insert(current_group, op)
    else
      table.insert(current_group, op)
    end
  end
  
  if #current_group > 0 then
    table.insert(groups, current_group)
  end
  
  return groups
end

function M._execute_operation_group(group)
  if #group == 0 then
    return
  end
  
  local buf_set_lines_ops = {}
  local other_ops = {}
  
  for _, op in ipairs(group) do
    if op.operation == "buf_set_lines" then
      table.insert(buf_set_lines_ops, op)
    else
      table.insert(other_ops, op)
    end
  end
  
  if #buf_set_lines_ops > 1 then
    M._merge_buf_set_lines(buf_set_lines_ops)
  elseif #buf_set_lines_ops == 1 then
    local op = buf_set_lines_ops[1]
    local args = op.args
    vim.api.nvim_buf_set_lines(args.bufnr, args.start, args.end_, args.strict_indexing, args.replacement)
  end
  
  for _, op in ipairs(other_ops) do
    M._execute_single_operation(op)
  end
end

function M._merge_buf_set_lines(operations)
  local buf_groups = {}
  
  for _, op in ipairs(operations) do
    local bufnr = op.args.bufnr
    if not buf_groups[bufnr] then
      buf_groups[bufnr] = {}
    end
    table.insert(buf_groups[bufnr], op)
  end
  
  for bufnr, ops in pairs(buf_groups) do
    if #ops == 1 then
      local args = ops[1].args
      vim.api.nvim_buf_set_lines(args.bufnr, args.start, args.end_, args.strict_indexing, args.replacement)
    else
      local all_lines = {}
      for _, op in ipairs(ops) do
        for _, line in ipairs(op.args.replacement) do
          table.insert(all_lines, line)
        end
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)
    end
  end
end

function M._execute_single_operation(op)
  local args = op.args
  
  if op.operation == "buf_set_option" then
    if vim.api.nvim_buf_is_valid(args.bufnr) then
      vim.api.nvim_buf_set_option(args.bufnr, args.name, args.value)
    end
  elseif op.operation == "win_set_option" then
    if vim.api.nvim_win_is_valid(args.winid) then
      vim.api.nvim_win_set_option(args.winid, args.name, args.value)
    end
  elseif op.operation == "set_hl" then
    vim.api.nvim_set_hl(args.ns_id, args.name, args.val)
  elseif op.operation == "buf_set_lines" then
    if vim.api.nvim_buf_is_valid(args.bufnr) then
      vim.api.nvim_buf_set_lines(args.bufnr, args.start, args.end_, args.strict_indexing, args.replacement)
    end
  end
end

function M.flush_now()
  if #M.batch_operations > 0 then
    M._flush_batch()
  end
end


return M