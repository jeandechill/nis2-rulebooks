-- Internal filter: reserve sufficient space so that a title does not stay
-- isolated from the subsequent paragraph, table or list.

local minimum_level = 2
local reserved_lines = 6

local function metadata_number(meta, key, allowed, fallback)
  if meta[key] == nil then
    return fallback
  end
  local value = tonumber(pandoc.utils.stringify(meta[key]))
  if value == nil or not allowed[value] then
    return fallback
  end
  return value
end

local function configure(meta)
  minimum_level = metadata_number(meta, "keep-heading-min-level", {
    [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true
  }, 2)
  reserved_lines = metadata_number(meta, "keep-heading-lines", {
    [3] = true, [6] = true, [10] = true
  }, 6)

  local package = pandoc.MetaBlocks({
    pandoc.RawBlock("latex", "\\usepackage{needspace}")
  })
  local includes = meta["header-includes"]
  if includes == nil then
    meta["header-includes"] = pandoc.MetaList({package})
  elseif includes.t == "MetaList" then
    table.insert(includes, package)
    meta["header-includes"] = includes
  else
    meta["header-includes"] = pandoc.MetaList({includes, package})
  end
  return meta
end

local function text_length(value)
  local text = pandoc.utils.stringify(value)
  return utf8.len(text) or #text
end

local function wrapped_lines(value, width)
  return math.max(1, math.ceil(text_length(value) / math.max(8, width)))
end

local function content_lines(blocks, width)
  local total = 0
  for _, block in ipairs(blocks or {}) do
    if block.t == "BulletList" or block.t == "OrderedList" then
      for _, item in ipairs(block.content) do
        total = total + wrapped_lines(item, width - 2)
      end
    elseif block.t == "CodeBlock" then
      local _, breaks = block.text:gsub("\n", "\n")
      total = total + breaks + 1
    else
      total = total + wrapped_lines(block, width)
    end
  end
  return math.max(1, total)
end

local function column_widths(table_block)
  local widths = {}
  local count = math.max(1, #(table_block.colspecs or {}))
  for index, spec in ipairs(table_block.colspecs or {}) do
    local width = tonumber(spec[2]) or 0
    widths[index] = width > 0 and width or (1 / count)
  end
  return widths
end

local function row_lines(row, widths)
  if row == nil then
    return 1
  end
  local maximum = 1
  local column = 1
  for _, cell in ipairs(row.cells or {}) do
    local span = tonumber(cell.col_span) or 1
    local fraction = 0
    for offset = 0, span - 1 do
      fraction = fraction + (widths[column + offset] or 0)
    end
    if fraction <= 0 then
      fraction = span / math.max(1, #widths)
    end
    local characters = math.max(10, math.floor(76 * fraction) - 2)
    maximum = math.max(maximum, content_lines(cell.contents, characters))
    column = column + span
  end
  return maximum
end

local function table_space_lines(table_block)
  local widths = column_widths(table_block)
  local required = 3
  for _, row in ipairs((table_block.head and table_block.head.rows) or {}) do
    required = required + row_lines(row, widths)
  end
  for _, body in ipairs(table_block.bodies or {}) do
    if body.body and body.body[1] then
      required = required + math.ceil(row_lines(body.body[1], widths) * 1.5)
      break
    end
  end
  return math.min(42, math.max(reserved_lines, required))
end

local function protect_blocks(blocks)
  local result = {}
  for index, block in ipairs(blocks) do
    if block.t == "Header" and block.level >= minimum_level then
      local following = blocks[index + 1]
      local needed = following ~= nil and following.t == "Table" and table_space_lines(following) or reserved_lines
      local spacer = pandoc.RawBlock("latex", "\\Needspace{" .. needed .. "\\baselineskip}")
      result[#result + 1] = spacer
      result[#result + 1] = block
      result[#result + 1] = pandoc.RawBlock("latex", "\\nopagebreak[4]")
    else
      result[#result + 1] = block
    end
  end
  return result
end

return {
  {Meta = configure},
  {Blocks = protect_blocks}
}
