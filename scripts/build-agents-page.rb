require "cgi"
require "date"
require "pathname"

ROOT = Pathname.new(__dir__).parent
SOURCE_PATH = ROOT.join("AGENTS.md")
OUTPUT_PATH = ROOT.join("agents.html")

def inline_markdown(value)
  CGI.escapeHTML(value)
     .gsub(/`([^`]+)`/, '<code>\1</code>')
     .gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
end

def render_markdown(markdown)
  html = []
  paragraph = []
  list_open = false

  flush_paragraph = lambda do
    next if paragraph.empty?

    html << "<p>#{inline_markdown(paragraph.join(" "))}</p>"
    paragraph.clear
  end

  close_list = lambda do
    next unless list_open

    html << "</ul>"
    list_open = false
  end

  markdown.each_line do |raw_line|
    line = raw_line.chomp

    if line.start_with?("# ")
      flush_paragraph.call
      close_list.call
      html << "<h1>#{inline_markdown(line.sub(/^# /, ""))}</h1>"
    elsif line.start_with?("## ")
      flush_paragraph.call
      close_list.call
      html << "<h2>#{inline_markdown(line.sub(/^## /, ""))}</h2>"
    elsif line.start_with?("### ")
      flush_paragraph.call
      close_list.call
      html << "<h3>#{inline_markdown(line.sub(/^### /, ""))}</h3>"
    elsif line.start_with?("- ")
      flush_paragraph.call
      unless list_open
        html << "<ul>"
        list_open = true
      end
      html << "<li>#{inline_markdown(line.sub(/^- /, ""))}</li>"
    elsif line.match?(/^\d+\. /)
      flush_paragraph.call
      close_list.call
      html << "<p class=\"numbered\">#{inline_markdown(line)}</p>"
    elsif line.strip.empty?
      flush_paragraph.call
      close_list.call
    else
      paragraph << line.strip
    end
  end

  flush_paragraph.call
  close_list.call
  html.join("\n")
end

markdown = SOURCE_PATH.read
rendered = render_markdown(markdown)
generated_at = Date.today.iso8601

page = <<~HTML
  <!DOCTYPE html>
  <html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AGENTS.md - raimundo.sh</title>
    <meta name="description" content="Contrato editorial publico de raimundo.sh para orientar linguagem, visual e manutencao por agentes de IA." />
    <style>
      :root {
        color-scheme: light dark;
        --bg: #f7f3ea;
        --text: #191714;
        --muted: #676057;
        --rule: #d8d0c3;
        --link: #533f24;
        --panel: #fffaf0;
      }

      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #171513;
          --text: #eee7dc;
          --muted: #b7aa9a;
          --rule: #3b342c;
          --link: #e2c58f;
          --panel: #201d19;
        }
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        background: var(--bg);
        color: var(--text);
        font-family: ui-serif, Georgia, Cambria, "Times New Roman", Times, serif;
        font-size: 18px;
        line-height: 1.7;
      }

      header,
      main,
      footer {
        width: min(760px, calc(100% - 40px));
        margin: 0 auto;
      }

      header {
        padding: 40px 0 24px;
        border-bottom: 1px solid var(--rule);
      }

      .brand {
        display: flex;
        flex-wrap: wrap;
        gap: 8px 14px;
        align-items: baseline;
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }

      .brand a {
        color: var(--text);
        font-weight: 700;
        text-decoration: none;
      }

      .tagline {
        color: var(--muted);
        font-size: 0.9rem;
      }

      main {
        padding: 32px 0 56px;
      }

      .source-note {
        margin: 0 0 28px;
        padding: 16px 18px;
        border: 1px solid var(--rule);
        background: var(--panel);
        color: var(--muted);
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        font-size: 0.9rem;
        line-height: 1.5;
      }

      h1,
      h2,
      h3 {
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        line-height: 1.2;
        letter-spacing: 0;
      }

      h1 {
        margin: 0 0 24px;
        font-size: 2.4rem;
      }

      h2 {
        margin: 42px 0 14px;
        padding-top: 10px;
        border-top: 1px solid var(--rule);
        font-size: 1.45rem;
      }

      h3 {
        margin: 28px 0 12px;
        font-size: 1.1rem;
      }

      p,
      ul {
        margin: 0 0 18px;
      }

      ul {
        padding-left: 1.3rem;
      }

      li {
        margin: 0 0 8px;
      }

      a {
        color: var(--link);
        text-underline-offset: 0.16em;
      }

      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
        font-size: 0.9em;
      }

      .numbered {
        margin-left: 1rem;
      }

      footer {
        padding: 24px 0 44px;
        border-top: 1px solid var(--rule);
        color: var(--muted);
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        font-size: 0.85rem;
      }
    </style>
  </head>
  <body>
    <header>
      <div class="brand">
        <a href="./">raimundo.sh</a>
        <span class="tagline">o burro curioso</span>
      </div>
    </header>
    <main>
      <div class="source-note">
        Esta pagina e gerada a partir de <code>AGENTS.md</code>. Edite o Markdown e rode <code>ruby scripts/build-agents-page.rb</code> para sincronizar.
        Ultima geracao: #{generated_at}.
      </div>
  #{rendered}
    </main>
    <footer>
      Fonte canonica: AGENTS.md.
    </footer>
  </body>
  </html>
HTML

OUTPUT_PATH.write(page)
puts "Generated #{OUTPUT_PATH.relative_path_from(ROOT)} from #{SOURCE_PATH.relative_path_from(ROOT)}"
