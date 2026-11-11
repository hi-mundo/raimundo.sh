#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "open3"
require "time"
require "yaml"

ROOT = File.expand_path("..", __dir__)
OLD_REPO = File.expand_path("../../ODISSEIADOPUTO/odisseiadoputo", __dir__)
POST_OUT = File.join(ROOT, "posts", "legado")
ASSET_OUT = File.join(ROOT, "assets", "legado", "img")
SITE_HOST = "https://raimundo.sh"

def git_old(*args)
  out, err, status = Open3.capture3("git", "-C", OLD_REPO, *args)
  raise "git #{args.join(" ")} failed: #{err}" unless status.success?

  out
end

def slug_from_path(path)
  File.basename(path).sub(/\A\d{4}-\d{2}-\d{2}-/, "").sub(/\.(markdown|md|html)\z/, "")
end

def frontmatter_and_body(raw)
  return [{}, raw] unless raw.start_with?("---\n")

  _start, yaml, body = raw.split(/^---\s*$/, 3)
  [YAML.safe_load(yaml, permitted_classes: [Time, Date], aliases: true) || {}, body.to_s]
end

def html_escape(text)
  CGI.escapeHTML(text.to_s)
end

def inline_markdown(text)
  escaped = html_escape(text)
  escaped = escaped.gsub(/\*\*(.+?)\*\*/m, '<strong>\1</strong>')
  escaped = escaped.gsub(/\*(.+?)\*/m, '<em>\1</em>')
  escaped.gsub(%r{\[(.+?)\]\((https?://[^)]+)\)}, '<a href="\2">\1</a>')
end

def copy_legacy_image(src)
  clean = src.sub(/\A\{\{\s*site\.baseurl\s*\}\}\//, "").sub(%r{\A/}, "")
  return src unless clean.start_with?("img/")

  old_path = File.join(OLD_REPO, clean)
  return src unless File.file?(old_path)

  dest = File.join(ASSET_OUT, clean.sub(%r{\Aimg/}, ""))
  FileUtils.mkdir_p(File.dirname(dest))
  FileUtils.cp(old_path, dest)
  "/assets/legado/img/#{clean.sub(%r{\Aimg/}, "")}"
end

def markdown_to_html(markdown)
  lines = markdown.to_s.lines
  html = []
  paragraph = []
  list = []

  flush_paragraph = lambda do
    next if paragraph.empty?

    html << "<p>#{inline_markdown(paragraph.join(" ").strip)}</p>"
    paragraph.clear
  end

  flush_list = lambda do
    next if list.empty?

    html << "<ul>"
    list.each { |item| html << "  <li>#{inline_markdown(item)}</li>" }
    html << "</ul>"
    list.clear
  end

  lines.each do |line|
    text = line.rstrip

    if text.empty?
      flush_paragraph.call
      flush_list.call
      next
    end

    if (match = text.match(/\A!\[(.*?)\]\((.*?)\)\s*\z/))
      flush_paragraph.call
      flush_list.call
      alt = html_escape(match[1])
      src = html_escape(copy_legacy_image(match[2]))
      html << %(<figure><img src="#{src}" alt="#{alt}" loading="lazy"></figure>)
      next
    end

    if (match = text.match(/\A(\#{1,4})\s+(.+)\z/))
      flush_paragraph.call
      flush_list.call
      level = [match[1].length + 1, 4].min
      html << "<h#{level}>#{inline_markdown(match[2])}</h#{level}>"
      next
    end

    if (match = text.match(/\A[-*]\s+(.+)\z/))
      flush_paragraph.call
      list << match[1]
      next
    end

    paragraph << text
  end

  flush_paragraph.call
  flush_list.call
  html.join("\n")
end

def old_url_path(frontmatter, path)
  date = Time.parse(frontmatter.fetch("date").to_s)
  categories = Array(frontmatter["category"] || frontmatter["categories"]).flatten.compact.map(&:to_s)
  pieces = categories + [date.strftime("%Y"), date.strftime("%m"), date.strftime("%d"), slug_from_path(path)]
  "/#{pieces.join("/")}/"
rescue StandardError
  "/#{slug_from_path(path)}/"
end

def page_template(title:, subtitle:, date:, categories:, body:)
  <<~HTML
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{html_escape(title)} - raimundo.sh</title>
      <style>
        :root{color-scheme:light dark;--bg:#f6f1e8;--text:#1f1a14;--muted:#706659;--faint:#988d7e;--line:rgba(57,45,31,.16);--link:#684513}
        @media (prefers-color-scheme:dark){:root{--bg:#14110e;--text:#efe7db;--muted:#b8ab99;--faint:#8c806f;--line:rgba(239,231,219,.14);--link:#e3c07a}}
        *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:18px/1.72 Georgia,Cambria,"Times New Roman",serif}
        main{width:min(1020px,calc(100% - 42px));margin:0 auto;padding:52px 0 76px}
        article{max-width:880px}.back,.meta{font:14px/1.5 ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--faint)}
        .back{display:inline-block;margin-bottom:42px;color:var(--link);text-decoration:none}.back:hover{text-decoration:underline}
        h1{font:780 clamp(2.25rem,7vw,5.4rem)/1.06 ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;letter-spacing:0;margin:0 0 20px;max-width:980px}
        h2,h3,h4{font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.18;margin:42px 0 12px}
        .subtitle{max-width:780px;color:var(--muted);font-size:1.18rem;margin:0 0 20px}.meta{margin:0 0 34px}
        p,li{max-width:780px;color:var(--muted)}a{color:var(--link)}strong{color:var(--text)}ul{padding-left:1.1rem}
        figure{margin:30px 0}.line{height:1px;width:min(760px,calc(100% - 34px));margin:36px 0;background:linear-gradient(90deg,transparent,var(--line),rgba(57,45,31,.08),transparent);box-shadow:0 10px 16px rgba(67,49,25,.12)}
        img{max-width:min(780px,100%);height:auto;border-radius:4px;box-shadow:0 18px 46px rgba(0,0,0,.16)}
      </style>
    </head>
    <body>
      <main>
        <a class="back" href="../../">← raimundo.sh</a>
        <article>
          <p class="meta">legado do odisseiadoputo · #{html_escape(date)}#{categories.empty? ? "" : " · #{html_escape(categories.join(" · "))}"}</p>
          <h1>#{html_escape(title)}</h1>
          #{subtitle.to_s.empty? ? "" : %(<p class="subtitle">#{html_escape(subtitle)}</p>)}
          <div class="line"></div>
          #{body}
        </article>
      </main>
    </body>
    </html>
  HTML
end

FileUtils.mkdir_p(POST_OUT)
FileUtils.mkdir_p(ASSET_OUT)

paths = git_old("ls-tree", "-r", "HEAD", "--name-only")
        .lines
        .map(&:strip)
        .grep(%r{\A_posts/})
        .reject { |path| path.include?("melhor-cadeira") || path.include?("melhores-laptops") || path.include?("melhores-livros") }

manifest = []

paths.each do |path|
  raw = git_old("show", "HEAD:#{path}")
  frontmatter, body = frontmatter_and_body(raw)
  slug = slug_from_path(path)
  title = frontmatter["title"].to_s.strip
  subtitle = frontmatter["subtitle"].to_s.strip
  date = Time.parse(frontmatter["date"].to_s).strftime("%d/%m/%Y")
  categories = Array(frontmatter["category"] || frontmatter["categories"]).flatten.compact.map(&:to_s)
  html_body = markdown_to_html(body)
  out_path = File.join(POST_OUT, "#{slug}.html")

  File.write(out_path, page_template(title: title, subtitle: subtitle, date: date, categories: categories, body: html_body))
  manifest << {
    "source" => path,
    "old_path" => old_url_path(frontmatter, path),
    "new_path" => "/posts/legado/#{slug}.html",
    "title" => title,
    "date" => frontmatter["date"].to_s,
    "categories" => categories
  }
end

manifest_path = File.join(POST_OUT, "manifest.json")
File.write(manifest_path, "#{JSON.pretty_generate(manifest)}\n")

puts "Migrated #{manifest.length} posts"
puts manifest.map { |item| "#{item["old_path"]} -> #{item["new_path"]}" }
