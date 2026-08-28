-- Internal filter: each Markdown title ## opens a new page and feeds
-- \rightmark, used by the header and footer of the page {{section}}.

local latex_special = {
  ["\\"] = "\\textbackslash{}",
  ["{"] = "\\{",
  ["}"] = "\\}",
  ["$"] = "\\$",
  ["&"] = "\\&",
  ["#"] = "\\#",
  ["_"] = "\\_",
  ["%"] = "\\%",
  ["~"] = "\\textasciitilde{}",
  ["^"] = "\\textasciicircum{}"
}

local function latex_escape(text)
  return (text:gsub(".", function(character)
    return latex_special[character] or character
  end))
end

function Header(header)
  if header.level ~= 2 then
    return nil
  end

  local title = latex_escape(pandoc.utils.stringify(header.content))
  return {pandoc.RawBlock("latex", "\\clearpage"), header,
    pandoc.RawBlock("latex", "\\markright{" .. title .. "}")}
end
