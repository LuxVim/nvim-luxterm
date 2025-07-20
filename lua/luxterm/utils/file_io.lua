local M = {}

function M.ensure_directory(path)
  local dir = vim.fn.fnamemodify(path, ':h')
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
end

function M.save_json_async(file_path, data, callback)
  M.ensure_directory(file_path)
  
  vim.schedule(function()
    local ok, json_data = pcall(vim.fn.json_encode, data)
    if not ok or not json_data then
      vim.notify('LuxTerm: Failed to encode data', vim.log.levels.WARN)
      if callback then callback(false) end
      return
    end
    
    vim.uv.fs_open(file_path, 'w', 438, function(err, fd)
      if err or not fd then
        vim.notify('LuxTerm: Failed to open file: ' .. (err or 'unknown'), vim.log.levels.WARN)
        if callback then callback(false) end
        return
      end
      
      vim.uv.fs_write(fd, json_data, -1, function(write_err)
        vim.uv.fs_close(fd, function() end)
        if write_err then
          vim.notify('LuxTerm: Failed to save: ' .. write_err, vim.log.levels.WARN)
          if callback then callback(false) end
        else
          if callback then callback(true) end
        end
      end)
    end)
  end)
end

function M.load_json_async(file_path, callback)
  if vim.fn.filereadable(file_path) == 0 then
    if callback then callback(nil) end
    return
  end
  
  vim.uv.fs_open(file_path, 'r', 438, function(err, fd)
    if err or not fd then
      vim.notify('LuxTerm: Failed to open file: ' .. (err or 'unknown'), vim.log.levels.WARN)
      if callback then callback(nil) end
      return
    end
    
    vim.uv.fs_fstat(fd, function(stat_err, stat)
      if stat_err or not stat then
        vim.uv.fs_close(fd, function() end)
        if callback then callback(nil) end
        return
      end
      
      vim.uv.fs_read(fd, stat.size, 0, function(read_err, data)
        vim.uv.fs_close(fd, function() end)
        if read_err or not data then
          vim.notify('LuxTerm: Failed to read file: ' .. (read_err or 'unknown'), vim.log.levels.WARN)
          if callback then callback(nil) end
          return
        end
        
        vim.schedule(function()
          local ok, decoded_data = pcall(vim.fn.json_decode, data)
          if ok and decoded_data then
            if callback then callback(decoded_data) end
          else
            if callback then callback(nil) end
          end
        end)
      end)
    end)
  end)
end

function M.get_data_file_path(filename)
  return vim.fn.expand('~/.local/share/nvim/' .. filename)
end

return M