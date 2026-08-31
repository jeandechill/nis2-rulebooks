-- Internal filter: follow the Markdown width, optimize them depending on
-- the content, or applies ratio on table with two columns.

local mode = "auto"
local manual_first = 0.65

local function configure(meta)
  local requested = pandoc.utils.stringify(meta["table-width-mode"] or "")
  if requested == "markdown" or requested == "auto" or requested == "manual" then
    mode = requested
  end
  local ratio = pandoc.utils.stringify(meta["table-width-ratio"] or "")
  local first, second = ratio:match("^(%d+)%/(%d+)$")
  first, second = tonumber(first), tonumber(second)
  if first and second and first + second == 100 and first >= 25 and first <= 75 then
    manual_first = first / 100
  end
  return meta
end

local function text_length(value)
  local text = pandoc.utils.stringify(value)
  return utf8.len(text) or #text
end

local function content_score(blocks)
  local score = math.max(1, text_length(blocks))
  for _, block in ipairs(blocks or {}) do
    if block.t == "BulletList" or block.t == "OrderedList" then
      score = score + (#block.content * 18)
    elseif block.t == "CodeBlock" then
      local _, lines = block.text:gsub("\n", "\n")
      score = score + (lines * 12)
    end
  end
  return score
end

local function score_row(row, scores)
  local column = 1
  for _, cell in ipairs((row and row.cells) or {}) do
    local span = tonumber(cell.col_span) or 1
    local score = content_score(cell.contents)
    if span == 1 then
      scores[column] = math.max(scores[column] or 1, score)
    else
      local share = score / span
      for offset = 0, span - 1 do
        scores[column + offset] = math.max(scores[column + offset] or 1, share)
      end
    end
    column = column + span
  end
end

local function table_rows(table_block)
  local rows = {}
  for _, row in ipairs((table_block.head and table_block.head.rows) or {}) do
    rows[#rows + 1] = row
  end
  for _, body in ipairs(table_block.bodies or {}) do
    for _, row in ipairs(body.head or {}) do
      rows[#rows + 1] = row
    end
    for _, row in ipairs(body.body or {}) do
      rows[#rows + 1] = row
    end
  end
  for _, row in ipairs((table_block.foot and table_block.foot.rows) or {}) do
    rows[#rows + 1] = row
  end
  return rows
end

local function resize_table(table_block)
  if mode == "markdown" then
    return nil
  end
  local count = #(table_block.colspecs or {})
  if count < 2 then
    return nil
  end

  local widths = {}
  if mode == "manual" then
    if count ~= 2 then
      return nil
    end
    widths = {manual_first, 1 - manual_first}
  else
    local scores = {}
    for index = 1, count do
      scores[index] = 1
    end
    for _, row in ipairs(table_rows(table_block)) do
      score_row(row, scores)
    end
    local weights, total = {}, 0
    for index = 1, count do
      weights[index] = scores[index]
      total = total + weights[index]
    end
    local floor = math.min(0.12, 0.75 / count)
    local flexible = 1 - (floor * count)
    for index = 1, count do
      widths[index] = floor + flexible * (weights[index] / total)
    end
    if count == 2 then
      widths[1] = math.max(0.25, math.min(0.75, widths[1]))
      widths[2] = 1 - widths[1]
    end
  end

  for index, spec in ipairs(table_block.colspecs) do
    table_block.colspecs[index] = {spec[1], widths[index]}
  end
  return table_block
end

return {
  {Meta = configure},
  {Table = resize_table}
}
