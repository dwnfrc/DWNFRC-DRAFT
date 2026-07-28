#!/usr/bin/env ruby
# draft-plugin の skills を Cursor 用 Agent Skills 一式として生成する(派生)。
#
# Cursor 2.4+ は Claude Code と同じ SKILL.md 形式を .cursor/skills/ から読み込む。
# 差分は2点だけ: (1) フォルダ名=name を Cursor の必須要件に合わせる、
# (2) プラグイン名前空間 /draft:xxx は Cursor に無いのでフラットな /draft-xxx に変換する。
# 正は draft-plugin/skills/。ここで生成される dist/cursor/skills/ は派生(配布物)。
#
# 使い方:
#   ruby scripts/build-cursor-skills.rb          # dist/cursor/skills/ を生成
#   ruby scripts/build-cursor-skills.rb --check   # 生成物が最新か検証(乖離があれば exit 1)
require 'fileutils'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

ROOT   = File.expand_path('..', __dir__)
SRC    = File.join(ROOT, 'draft-plugin', 'skills')
DIST   = File.join(ROOT, 'dist', 'cursor', 'skills')
PREFIX = 'draft-'

# SKILL.md を Cursor 用に書き換える:
#   - フロントマターの name をフォルダ名(prefix付き)に一致させる(Cursorの必須要件)
#   - /draft:xxx → /draft-xxx (プラグイン名前空間 → フラット名前空間)
def rewrite_skill_md(text, name, cursor_name)
  m = text.match(/\A(---\n.*?\n---\n)(.*)\z/m)
  raise 'SKILL.md にフロントマターが無い' unless m

  front, body = m[1], m[2]
  front = front.sub(/^name:[ \t]*#{Regexp.escape(name)}[ \t]*$/, "name: #{cursor_name}")
  (front + body).gsub('/draft:', '/draft-')
end

# 1スキルディレクトリを Cursor 用に変換し、{ 出力絶対パス => [:text, 内容] | [:copy, 元パス] } を返す
def transform_skill(src_dir)
  name        = File.basename(src_dir)
  cursor_name = "#{PREFIX}#{name}"
  out = {}

  Dir.glob(File.join(src_dir, '**', '*')).sort.each do |path|
    next if File.directory?(path)
    next if File.basename(path) == '.DS_Store'

    rel      = path.sub("#{src_dir}/", '')
    out_path = File.join(DIST, cursor_name, rel)

    out[out_path] =
      if File.basename(path) == 'SKILL.md'
        [:text, rewrite_skill_md(File.read(path), name, cursor_name)]
      else
        [:copy, path]
      end
  end
  out
end

# 全スキルを変換したファイルマップを返す
def build_all
  files = {}
  Dir[File.join(SRC, '*')].select { |d| File.directory?(d) }.sort.each do |src_dir|
    files.merge!(transform_skill(src_dir))
  end
  files
end

def rel(path) = path.sub("#{ROOT}/", '')

def generate!
  files = build_all
  FileUtils.rm_rf(DIST)
  files.each do |out_path, (kind, data)|
    FileUtils.mkdir_p(File.dirname(out_path))
    kind == :text ? File.write(out_path, data) : FileUtils.cp(data, out_path)
  end
  puts "生成: #{rel(DIST)} に #{files.size} ファイル(#{files.keys.map { |p| p[%r{#{Regexp.escape(DIST)}/([^/]+)/}, 1] }.uniq.size} スキル)"
end

# 生成物が最新かを検証する。差分(未生成・内容が古い・余分なファイル)を返す
def check
  expected = build_all
  drift    = []

  expected.each do |out_path, (kind, data)|
    unless File.exist?(out_path)
      drift << "未生成: #{rel(out_path)}"
      next
    end
    same = kind == :text ? (File.read(out_path) == data) : (File.binread(out_path) == File.binread(data))
    drift << "内容が古い: #{rel(out_path)}" unless same
  end

  Dir.glob(File.join(DIST, '**', '*')).each do |f|
    next if File.directory?(f)
    drift << "余分なファイル: #{rel(f)}" unless expected.key?(f)
  end

  drift
end

if ARGV.include?('--check')
  drift = check
  if drift.empty?
    puts "OK: Cursor派生スキルは最新(#{rel(DIST)})"
  else
    warn "NG: Cursor派生スキルが古い。`ruby scripts/build-cursor-skills.rb` で再生成せよ"
    drift.each { |d| warn "  #{d}" }
    exit 1
  end
else
  generate!
end
