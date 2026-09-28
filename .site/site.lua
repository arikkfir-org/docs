-- Pandoc filter for the docs site.
--  * Relative links to Markdown files point at their rendered HTML pages instead.
--  * ```mermaid code blocks become <pre class="mermaid"> elements, rendered in the browser.
--  * The first level-1 heading becomes the page title.

local function is_relative(url)
  return not url:match('^%a[%w+.-]*:') and not url:match('^//') and not url:match('^#')
end

function Link(el)
  if is_relative(el.target) then
    el.target = el.target:gsub('%.md(#.*)$', '.html%1'):gsub('%.md$', '.html')
  end
  return el
end

function CodeBlock(el)
  if el.classes[1] == 'mermaid' then
    local text = el.text:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
    return pandoc.RawBlock('html', '<pre class="mermaid">' .. text .. '</pre>')
  end
end

function Pandoc(doc)
  if doc.meta.pagetitle == nil and doc.meta.title == nil then
    local title = PANDOC_STATE.input_files[1] or 'Document'
    for _, block in ipairs(doc.blocks) do
      if block.t == 'Header' and block.level == 1 then
        title = pandoc.utils.stringify(block.content)
        break
      end
    end
    doc.meta.pagetitle = title
  end
  return doc
end
