#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"

ROOT = File.expand_path("..", __dir__)
OLD_REPO = File.expand_path("../../ODISSEIADOPUTO/odisseiadoputo", __dir__)
SITE_HOST = "https://raimundo.sh"
MANIFEST = File.join(ROOT, "posts", "legado", "manifest.json")

def redirect_html(target)
  <<~HTML
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <meta http-equiv="refresh" content="0; url=#{target}">
      <link rel="canonical" href="#{target}">
      <title>Redirecionando - odisseiadoputo.cc</title>
      <script>location.replace("#{target}");</script>
    </head>
    <body>
      <p>Este post foi migrado para <a href="#{target}">#{target}</a>.</p>
    </body>
    </html>
  HTML
end

manifest = JSON.parse(File.read(MANIFEST))

manifest.each do |item|
  target = "#{SITE_HOST}#{item.fetch("new_path")}"
  out_dir = File.join(OLD_REPO, item.fetch("old_path").sub(%r{\A/}, ""))
  FileUtils.mkdir_p(out_dir)
  File.write(File.join(out_dir, "index.html"), redirect_html(target))
end

puts "Wrote #{manifest.length} redirects into #{OLD_REPO}"
