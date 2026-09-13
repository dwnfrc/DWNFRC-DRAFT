#!/usr/bin/env ruby
# このリポジトリのスキルを、Agent Skills 対応クライアント(Codex・Cursor等)向けに生成する(派生)。
#
# それらのクライアントは Claude Code と同じ SKILL.md 形式を
# `.agents/skills/`(リポジトリ) と `~/.agents/skills/`(ユーザー) から読み込む。生成対象は2つ:
#
#   1. draft-plugin/skills/ → dist/agents/skills/  … 配布物(DRAFTを使う人が自分の環境に入れる)
#        差分は2点: (a) フォルダ名 = フロントマターの name を一致させる(prefix付きのフラット名)
#        (b) プラグイン名前空間 /draft:xxx はプラグイン外に無いので draft-xxx に変換する
#        (呼び出し記号はクライアントごとに違う — Codex は $draft-xxx、Cursor は /draft-xxx。
#         どちらでも読める素の名前で書き、記号の案内は draft-plugin/README.md が持つ)
#        例外: `claude -p '/draft:xxx'` の引数は変換しない(子プロセスは Claude Code 本体)
#
#   2. .claude/skills/ → .agents/skills/           … このリポジトリ用の改善スキル(evolve)を
#        Claude Code 以外のクライアントからも起動できるようにする。こちらは名前空間を変換しない
#        (evolve が編集する正の側は /draft: 名前空間のままであり、書き換えると指示が壊れる)
#
# 正は draft-plugin/skills/ と .claude/skills/。生成先はどちらも派生 — 手で編集しない。
#
# 使い方:
#   ruby scripts/build-agent-skills.rb           # 生成
#   ruby scripts/build-agent-skills.rb --check   # 生成物が最新か検証(乖離があれば exit 1)
require 'fileutils'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

ROOT   = File.expand_path('..', __dir__)
PREFIX = 'draft-'

# exclusive: 生成先ディレクトリを専有するか。dist/ は専有(丸ごと作り直す)だが、
# .agents/skills/ はクライアント共通の探索先で、インストーラで入れた draft-* が同居しうる。
# 専有しないターゲットは自分が生成したスキルのフォルダだけを作り直し、他には触らない。
TARGETS = [
  { src:  File.join(ROOT, 'draft-plugin', 'skills'),
    dist: File.join(ROOT, 'dist', 'agents', 'skills'),
    prefix: PREFIX, flatten: true, exclusive: true },
  { src:  File.join(ROOT, '.claude', 'skills'),
    dist: File.join(ROOT, '.agents', 'skills'),
    prefix: '', flatten: false, exclusive: false },
].freeze

# 名前空間を書き換える対象の拡張子(同梱テンプレートにも /draft:xxx 参照が現れる)
TEXT_EXT = %w[.md .mermaid .sh .json .txt].freeze

# `claude -p '/draft:xxx'` の引数は変換しない。子プロセスは Claude Code 本体であり、
# そこではプラグイン名前空間が生きている(フラット名に変えると解決しなくなる)。
# 無人ループの駆動スクリプトがこの形で自分自身を起動する。
CLAUDE_CLI_ARG = /claude\s+-p\s+(?:'[^']*'|"[^"]*")/

# 行末に draft-keep-namespace を書いた行も変換しない。子プロセスに渡すプロンプトを
# 変数へ切り出すと `claude -p '...'` の形が消えて上のガードから外れるので、その場で印を付ける。
KEEP_LINE = /^.*draft-keep-namespace.*$/
GUARD = "\u0000GUARD%d\u0000"

# プラグイン名前空間をフラット名に変換する:
#   /draft:concept → draft-concept
#   /draft:(スキル名を伴わない総称) → draft-*
def flatten_namespace(text)
  guarded = []
  masked  = text.gsub(KEEP_LINE) do |hit|
    guarded << hit
    format(GUARD, guarded.size - 1)
  end
  masked = masked.gsub(CLAUDE_CLI_ARG) do |hit|
    guarded << hit
    format(GUARD, guarded.size - 1)
  end
  flat = masked.gsub(%r{/draft:([a-z][a-z-]*)}, "#{PREFIX}\\1").gsub('/draft:', "#{PREFIX}*")
  flat.gsub(/\u0000GUARD(\d+)\u0000/) { guarded[Regexp.last_match(1).to_i] }
end

# SKILL.md を Agent Skills 用に書き換える:
#   - フロントマターの name をフォルダ名(prefix付き)に一致させる
#   - 本文・description の名前空間をフラット化する(flatten: true のときだけ)
def rewrite_skill_md(text, name, out_name, flatten)
  m = text.match(/\A(---\n.*?\n---\n)(.*)\z/m)
  raise 'SKILL.md にフロントマターが無い' unless m

  front, body = m[1], m[2]
  front = front.sub(/^name:[ \t]*#{Regexp.escape(name)}[ \t]*$/, "name: #{out_name}")
  out   = front + body
  flatten ? flatten_namespace(out) : out
end

# 1スキルディレクトリを変換し、{ 出力絶対パス => [:text, 内容] | [:copy, 元パス] } を返す
def transform_skill(src_dir, target)
  name     = File.basename(src_dir)
  out_name = "#{target[:prefix]}#{name}"
  out      = {}

  Dir.glob(File.join(src_dir, '**', '*')).sort.each do |path|
    next if File.directory?(path)
    next if File.basename(path) == '.DS_Store'

    rel      = path.sub("#{src_dir}/", '')
    out_path = File.join(target[:dist], out_name, rel)

    out[out_path] =
      if File.basename(path) == 'SKILL.md'
        [:text, rewrite_skill_md(File.read(path), name, out_name, target[:flatten])]
      elsif target[:flatten] && TEXT_EXT.include?(File.extname(path))
        [:text, flatten_namespace(File.read(path))]
      else
        [:copy, path]
      end
  end
  out
end

# 全ターゲットを変換したファイルマップを返す
def build_all
  files = {}
  TARGETS.each do |target|
    Dir[File.join(target[:src], '*')].select { |d| File.directory?(d) }.sort.each do |src_dir|
      files.merge!(transform_skill(src_dir, target))
    end
  end
  files
end

def rel(path) = path.sub("#{ROOT}/", '')

# ターゲットが生成するスキルフォルダの絶対パス一覧
def generated_dirs(target)
  Dir[File.join(target[:src], '*')].select { |d| File.directory?(d) }.sort
     .map { |d| File.join(target[:dist], "#{target[:prefix]}#{File.basename(d)}") }
end

def generate!
  files = build_all
  TARGETS.each do |t|
    t[:exclusive] ? FileUtils.rm_rf(t[:dist]) : generated_dirs(t).each { |d| FileUtils.rm_rf(d) }
  end
  files.each do |out_path, (kind, data)|
    FileUtils.mkdir_p(File.dirname(out_path))
    kind == :text ? File.write(out_path, data) : FileUtils.cp(data, out_path)
  end
  TARGETS.each do |t|
    count = files.keys.count { |p| p.start_with?("#{t[:dist]}/") }
    skills = files.keys.filter_map { |p| p[%r{#{Regexp.escape(t[:dist])}/([^/]+)/}, 1] }.uniq.size
    puts "生成: #{rel(t[:dist])} に #{count} ファイル(#{skills} スキル)"
  end
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

  TARGETS.each do |t|
    roots = t[:exclusive] ? [t[:dist]] : generated_dirs(t)
    roots.each do |root|
      Dir.glob(File.join(root, '**', '*')).each do |f|
        next if File.directory?(f)
        drift << "余分なファイル: #{rel(f)}" unless expected.key?(f)
      end
    end
  end

  drift
end

if ARGV.include?('--check')
  drift = check
  if drift.empty?
    puts "OK: Agent Skills派生は最新(#{TARGETS.map { |t| rel(t[:dist]) }.join(', ')})"
  else
    warn "NG: Agent Skills派生が古い。`ruby scripts/build-agent-skills.rb` で再生成せよ"
    drift.each { |d| warn "  #{d}" }
    exit 1
  end
else
  generate!
end
